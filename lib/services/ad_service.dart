import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../constants/app_constants.dart';
import 'network_service.dart';
import 'purchase_service.dart';

// ── AdMob Error Codes ─────────────────────────────────────────────────────────
// 0 = Internal / Server error (suspicious if persistent)
// 1 = Invalid request (bad ad unit ID — our fault, not a block)
// 2 = Network error (temporary, NOT a block — filter this out)
// 3 = No fill (no inventory, completely normal — NOT a block — filter this out)
// 9 = Mediation no fill (normal — filter out)
//
// A real ad blocker (DNS filter, VPN, Private DNS) will show up as:
//   - Code 0 (can't reach AdMob server) or an unrecognised non-fill error
//   - Consistent across BOTH interstitial AND rewarded
//   - Persists even when network is confirmed online
//   - Does NOT appear within the first few minutes (SDK warmup)

class AdService extends ChangeNotifier {
  AdService._();
  static final AdService instance = AdService._();

  // ── Ad Blocker Detection ──────────────────────────────────────────────────
  // Rules to avoid false positives:
  //   1. NEVER count error code 2 (network) or 3 (no fill) — these are normal
  //   2. BOTH interstitial AND rewarded must have suspicious failures
  //   3. Each format needs 5+ suspicious failures before it counts
  //   4. 3-minute grace period after app launch (SDK warmup, no false flags)
  //   5. 3-hour cooldown — once dismissed/retried, won't re-trigger for 3h
  //   6. Instantly cleared by any successful ad load on any format

  static const int    _suspiciousThreshold  = 5;   // per format
  static const int    _gracePeriodMinutes   = 3;   // after launch
  static const int    _cooldownHours        = 3;   // after user dismisses

  final DateTime _launchTime = DateTime.now();
  DateTime?      _lastDismissedAt;

  int  _interstitialSuspicious = 0;
  int  _rewardedSuspicious     = 0;
  bool _adsBlocked             = false;

  bool get adsBlocked => _adsBlocked && !PurchaseService.instance.adsRemoved;

  /// Returns true only for error codes that could indicate ad blocking.
  /// Filters out all normal, expected failures.
  bool _isSuspiciousError(LoadAdError error) {
    final code = error.code;

    // Code 2 = Network error → temporary, not a block
    if (code == 2) return false;

    // Code 3 = No fill → completely normal, especially for new accounts
    if (code == 3) return false;

    // Code 9 = Mediation no fill → normal
    if (code == 9) return false;

    // Code 1 = Invalid request → our config issue, not a block
    if (code == 1) return false;

    // Only suspicious if we're confirmed online
    if (!NetworkService.instance.isOnline) return false;

    // Code 0 or unknown = could be DNS block intercepting the request
    return true;
  }

  bool _isInGracePeriod() {
    final elapsed = DateTime.now().difference(_launchTime).inMinutes;
    return elapsed < _gracePeriodMinutes;
  }

  bool _isInCooldown() {
    if (_lastDismissedAt == null) return false;
    final elapsed = DateTime.now().difference(_lastDismissedAt!).inHours;
    return elapsed < _cooldownHours;
  }

  void _onSuspiciousInterstitialFailure() {
    if (_isInGracePeriod() || _isInCooldown()) return;
    _interstitialSuspicious++;
    _evaluateBlockStatus();
  }

  void _onSuspiciousRewardedFailure() {
    if (_isInGracePeriod() || _isInCooldown()) return;
    _rewardedSuspicious++;
    _evaluateBlockStatus();
  }

  void _evaluateBlockStatus() {
    // Both formats must independently hit the threshold
    // This filters out single-format issues (e.g. one ad unit misconfigured)
    final shouldFlag = _interstitialSuspicious >= _suspiciousThreshold &&
        _rewardedSuspicious >= _suspiciousThreshold;

    if (shouldFlag && !_adsBlocked) {
      _adsBlocked = true;
      notifyListeners();
    }
  }

  /// Called on ANY successful ad load — instantly clears all counters.
  void _onAnyAdLoadSuccess() {
    if (_interstitialSuspicious == 0 &&
        _rewardedSuspicious == 0 &&
        !_adsBlocked) return;

    _interstitialSuspicious = 0;
    _rewardedSuspicious     = 0;
    if (_adsBlocked) {
      _adsBlocked = false;
      notifyListeners();
    }
  }

  /// Called from "Enable Ads & Retry" button on the blocker overlay.
  Future<void> retryAds() async {
    _lastDismissedAt        = DateTime.now(); // start cooldown
    _interstitialSuspicious = 0;
    _rewardedSuspicious     = 0;
    _adsBlocked             = false;
    notifyListeners();

    // Reload all ad formats
    loadInterstitial();
    loadRewarded();
    loadBanner();
  }

  // ── Banner ────────────────────────────────────────────────────────────────
  BannerAd? _bannerAd;
  bool _bannerLoaded = false;

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
          _onAnyAdLoadSuccess(); // successful load → clear block flags
          onLoaded?.call();
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          _bannerLoaded = false;
          // Banner failures don't count toward block detection alone —
          // only interstitial + rewarded failures are used.
          // This prevents banner fill-rate issues causing false positives.
          Future.delayed(
            const Duration(seconds: 20),
            () => loadBanner(onLoaded: onLoaded),
          );
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

    _interstitialReady   = false;
    _interstitialLoading = true;

    InterstitialAd.load(
      adUnitId: AdIds.interstitial,
      request:  const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd      = ad;
          _interstitialReady   = true;
          _interstitialLoading = false;
          _onAnyAdLoadSuccess();

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
          _interstitialReady   = false;
          _interstitialLoading = false;

          // Only track suspicious failures — ignore no-fill and network errors
          if (_isSuspiciousError(error)) {
            _onSuspiciousInterstitialFailure();
          }

          Future.delayed(const Duration(seconds: 15), loadInterstitial);
        },
      ),
    );
  }

  /// Shows interstitial. Waits up to 3s if still loading.
  /// Skipped silently if user purchased Remove Ads.
  Future<void> showInterstitial({VoidCallback? onComplete}) async {
    if (PurchaseService.instance.adsRemoved) {
      onComplete?.call();
      return;
    }

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
    _rewardedReady   = false;
    _rewardedLoading = true;

    RewardedAd.load(
      adUnitId: AdIds.rewarded,
      request:  const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd     = ad;
          _rewardedReady  = true;
          _rewardedLoading = false;
          _onAnyAdLoadSuccess();
        },
        onAdFailedToLoad: (error) {
          _rewardedReady   = false;
          _rewardedLoading = false;

          if (_isSuspiciousError(error)) {
            _onSuspiciousRewardedFailure();
          }

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
        _rewardedAd     = null;
        _rewardedReady  = false;
        loadRewarded();
        if (!rewarded) onSkipped?.call();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _rewardedAd     = null;
        _rewardedReady  = false;
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
