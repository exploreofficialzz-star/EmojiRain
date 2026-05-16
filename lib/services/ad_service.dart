import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../constants/app_constants.dart';
import 'network_service.dart';
import 'purchase_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AD BLOCKER DETECTION — HOW IT WORKS
//
// The core insight: ad blockers (DNS filters, Private DNS, VPN blockers like
// AdGuard) block at the network level. The ad request NEVER reaches AdMob's
// server — the DNS lookup is refused instantly.
//
// This means:
//   BLOCKED  → ad load fails in < 400ms  (DNS refused or connection dropped)
//   NORMAL   → ad load fails in 500ms+   (AdMob server responds: no fill, etc.)
//
// We ONLY flag a failure as suspicious if:
//   1. It fails in under 400ms       ← speed threshold
//   2. Network is confirmed online   ← not a genuine connectivity issue
//   3. Error is NOT code 3 (no fill) ← AdMob server responded = not blocked
//   4. Error is NOT code 2 (network) ← handled by NetworkService already
//   5. Past the 3-minute grace period ← SDK warmup time, don't flag early
//
// BOTH interstitial AND rewarded must each hit 3 fast failures independently.
// A single format never triggers the overlay alone.
//
// ANY successful ad load on any format resets everything instantly.
// ─────────────────────────────────────────────────────────────────────────────

class AdService extends ChangeNotifier {
  AdService._();
  static final AdService instance = AdService._();

  // ── Detection config ──────────────────────────────────────────────────────
  static const Duration _fastFailThreshold   = Duration(milliseconds: 400);
  static const int      _fastFailsRequired   = 3;    // per format
  static const int      _gracePeriodMinutes  = 3;    // after app launch
  static const int      _cooldownMinutes     = 120;  // 2h after dismiss/retry

  final DateTime _appStartTime    = DateTime.now();
  DateTime?      _lastRetriedAt;

  // Fast failure counters — only incremented for near-instant failures
  int  _fastInterstitialFails = 0;
  int  _fastRewardedFails     = 0;
  bool _adsBlocked            = false;

  // Load-start timestamps — set just before each ad request
  DateTime? _interstitialLoadStart;
  DateTime? _rewardedLoadStart;

  // ── Public getters ────────────────────────────────────────────────────────
  bool get adsBlocked => _adsBlocked && !PurchaseService.instance.adsRemoved;

  // ── Guard checks ─────────────────────────────────────────────────────────
  bool _inGracePeriod() =>
      DateTime.now().difference(_appStartTime).inMinutes < _gracePeriodMinutes;

  bool _inCooldown() {
    if (_lastRetriedAt == null) return false;
    return DateTime.now().difference(_lastRetriedAt!).inMinutes < _cooldownMinutes;
  }

  /// Returns true only if this failure looks like a DNS/VPN block.
  bool _isFastBlock({required DateTime? loadStart, required LoadAdError error}) {
    // Ignore if SDK/network is known offline
    if (!NetworkService.instance.isOnline) return false;

    // Ignore during grace period (SDK warmup)
    if (_inGracePeriod()) return false;

    // Ignore during cooldown (user already retried)
    if (_inCooldown()) return false;

    // Code 3 = No fill — AdMob SERVER responded, so DNS was NOT blocked
    if (error.code == 3) return false;

    // Code 2 = Network error — genuine connectivity issue, not a blocker
    if (error.code == 2) return false;

    // Code 1 = Invalid request — our config problem
    if (error.code == 1) return false;

    // Code 9 = Mediation no fill — server responded
    if (error.code == 9) return false;

    // Speed check — only count if it failed FAST (< 400ms)
    if (loadStart == null) return false;
    final elapsed = DateTime.now().difference(loadStart);
    return elapsed < _fastFailThreshold;
  }

  void _onFastInterstitialBlock() {
    _fastInterstitialFails++;
    _evaluate();
  }

  void _onFastRewardedBlock() {
    _fastRewardedFails++;
    _evaluate();
  }

  void _evaluate() {
    // BOTH formats must independently reach the threshold.
    // If only one format is failing fast, it's likely a config issue, not a blocker.
    if (_fastInterstitialFails >= _fastFailsRequired &&
        _fastRewardedFails    >= _fastFailsRequired &&
        !_adsBlocked) {
      _adsBlocked = true;
      notifyListeners();
    }
  }

  /// Any successful ad load resets everything — user is not blocked.
  void _onAnySuccess() {
    final wasBlocked = _adsBlocked;
    _fastInterstitialFails = 0;
    _fastRewardedFails     = 0;
    _adsBlocked            = false;
    if (wasBlocked) notifyListeners();
  }

  /// Called from "Enable Ads & Retry" button.
  Future<void> retryAds() async {
    _lastRetriedAt         = DateTime.now();
    _fastInterstitialFails = 0;
    _fastRewardedFails     = 0;
    _adsBlocked            = false;
    notifyListeners();
    loadInterstitial();
    loadRewarded();
    loadBanner();
  }

  // ── Banner ────────────────────────────────────────────────────────────────
  BannerAd? _bannerAd;
  bool      _bannerLoaded = false;

  BannerAd? get bannerAd     => _bannerLoaded ? _bannerAd : null;
  bool      get bannerLoaded => _bannerLoaded;

  void loadBanner({AdSize size = AdSize.banner, VoidCallback? onLoaded}) {
    if (PurchaseService.instance.adsRemoved) return;

    _bannerAd?.dispose();
    _bannerLoaded = false;

    _bannerAd = BannerAd(
      adUnitId: AdIds.banner,
      size:     size,
      request:  const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          _bannerLoaded = true;
          _onAnySuccess();
          onLoaded?.call();
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          _bannerLoaded = false;
          // Banner is not used for block detection — fill rate varies too much
          Future.delayed(const Duration(seconds: 20),
              () => loadBanner(onLoaded: onLoaded));
        },
      ),
    )..load();
  }

  void disposeBanner() {
    _bannerAd?.dispose();
    _bannerAd     = null;
    _bannerLoaded = false;
  }

  // ── Interstitial ──────────────────────────────────────────────────────────
  InterstitialAd? _interstitialAd;
  bool _interstitialReady   = false;
  bool _interstitialLoading = false;

  bool get interstitialReady => _interstitialReady;

  void loadInterstitial() {
    if (PurchaseService.instance.adsRemoved) return;
    if (_interstitialLoading) return;

    _interstitialReady    = false;
    _interstitialLoading  = true;
    _interstitialLoadStart = DateTime.now(); // ← record start time

    InterstitialAd.load(
      adUnitId: AdIds.interstitial,
      request:  const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd      = ad;
          _interstitialReady   = true;
          _interstitialLoading = false;
          _interstitialLoadStart = null;
          _onAnySuccess(); // success = not blocked

          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (a) {
              a.dispose();
              _interstitialAd    = null;
              _interstitialReady = false;
              loadInterstitial();
            },
            onAdFailedToShowFullScreenContent: (a, _) {
              a.dispose();
              _interstitialAd    = null;
              _interstitialReady = false;
              loadInterstitial();
            },
          );
        },
        onAdFailedToLoad: (error) {
          _interstitialLoading = false;
          _interstitialReady   = false;

          // Speed-based block detection
          if (_isFastBlock(loadStart: _interstitialLoadStart, error: error)) {
            _onFastInterstitialBlock();
          }
          _interstitialLoadStart = null;

          Future.delayed(const Duration(seconds: 15), loadInterstitial);
        },
      ),
    );
  }

  /// Shows interstitial. Waits up to 3s if still loading.
  /// Silently skipped if user purchased Remove Ads.
  Future<void> showInterstitial({VoidCallback? onComplete}) async {
    if (PurchaseService.instance.adsRemoved) {
      onComplete?.call();
      return;
    }

    // Wait up to 3 seconds if still loading
    if (!_interstitialReady) {
      for (int i = 0; i < 6; i++) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (_interstitialReady) break;
      }
    }

    if (!_interstitialReady || _interstitialAd == null) {
      onComplete?.call();
      return;
    }

    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitialAd    = null;
        _interstitialReady = false;
        loadInterstitial();
        onComplete?.call();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _interstitialAd    = null;
        _interstitialReady = false;
        loadInterstitial();
        onComplete?.call();
      },
    );
    await _interstitialAd!.show();
  }

  // ── Rewarded ──────────────────────────────────────────────────────────────
  RewardedAd? _rewardedAd;
  bool _rewardedReady   = false;
  bool _rewardedLoading = false;

  bool get rewardedReady => _rewardedReady;

  void loadRewarded() {
    if (_rewardedLoading) return;

    _rewardedReady    = false;
    _rewardedLoading  = true;
    _rewardedLoadStart = DateTime.now(); // ← record start time

    RewardedAd.load(
      adUnitId: AdIds.rewarded,
      request:  const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd     = ad;
          _rewardedReady  = true;
          _rewardedLoading = false;
          _rewardedLoadStart = null;
          _onAnySuccess();
        },
        onAdFailedToLoad: (error) {
          _rewardedLoading = false;
          _rewardedReady   = false;

          if (_isFastBlock(loadStart: _rewardedLoadStart, error: error)) {
            _onFastRewardedBlock();
          }
          _rewardedLoadStart = null;

          Future.delayed(const Duration(seconds: 15), loadRewarded);
        },
      ),
    );
  }

  Future<bool> showRewarded({
    required VoidCallback onRewarded,
    VoidCallback? onSkipped,
  }) async {
    if (!_rewardedReady || _rewardedAd == null) {
      onSkipped?.call();
      return false;
    }

    bool rewarded = false;
    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd    = null;
        _rewardedReady = false;
        loadRewarded();
        if (!rewarded) onSkipped?.call();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _rewardedAd    = null;
        _rewardedReady = false;
        loadRewarded();
        onSkipped?.call();
      },
    );

    await _rewardedAd!.show(
      onUserEarnedReward: (_, __) {
        rewarded = true;
        onRewarded();
      },
    );
    return true;
  }

  // ── Init / Dispose ────────────────────────────────────────────────────────
  Future<void> init() async {
    loadInterstitial();
    loadRewarded();
    loadBanner();
  }

  void disposeAds() {
    _bannerAd?.dispose();
    _interstitialAd?.dispose();
    _rewardedAd?.dispose();
  }
}
