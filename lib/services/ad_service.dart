import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../constants/app_constants.dart';
import 'network_service.dart';
import 'purchase_service.dart';

class AdService extends ChangeNotifier {
  AdService._();
  static final AdService instance = AdService._();

  // ── Ad Blocker Detection ──────────────────────────────────────────────────
  // If ads fail to load 3+ times consecutively while network is online,
  // we flag it as likely blocked. The overlay prompts user to enable ads
  // or purchase Remove Ads.
  int  _consecutiveFailures = 0;
  bool _adsBlocked          = false;

  bool get adsBlocked => _adsBlocked && !PurchaseService.instance.adsRemoved;

  void _onAdLoadSuccess() {
    if (_consecutiveFailures > 0 || _adsBlocked) {
      _consecutiveFailures = 0;
      _adsBlocked          = false;
      notifyListeners();
    }
  }

  void _onAdLoadFailed() {
    // Only flag as blocked when network is confirmed online
    if (!NetworkService.instance.isOnline) return;
    _consecutiveFailures++;
    if (_consecutiveFailures >= 3 && !_adsBlocked) {
      _adsBlocked = true;
      notifyListeners();
    }
  }

  /// Called when user taps "Enable Ads & Retry" on the blocker overlay.
  void retryAds() {
    _consecutiveFailures = 0;
    _adsBlocked          = false;
    notifyListeners();
    // Re-attempt loading all ad formats
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
          _onAdLoadSuccess();
          onLoaded?.call();
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          _bannerLoaded = false;
          _onAdLoadFailed();
          Future.delayed(const Duration(seconds: 20), () {
            if (!PurchaseService.instance.adsRemoved) loadBanner(onLoaded: onLoaded);
          });
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
  bool            _interstitialReady   = false;
  bool            _interstitialLoading = false;

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
          _onAdLoadSuccess();

          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (a) {
              a.dispose();
              _interstitialAd    = null;
              _interstitialReady = false;
              loadInterstitial(); // preload next immediately
            },
            onAdFailedToShowFullScreenContent: (a, _) {
              a.dispose();
              _interstitialAd    = null;
              _interstitialReady = false;
              loadInterstitial();
            },
          );
        },
        onAdFailedToLoad: (_) {
          _interstitialReady   = false;
          _interstitialLoading = false;
          _onAdLoadFailed();
          Future.delayed(const Duration(seconds: 15), loadInterstitial);
        },
      ),
    );
  }

  /// Shows the interstitial. Waits up to 3s if still loading.
  /// Skips silently if user purchased Remove Ads.
  Future<void> showInterstitial({VoidCallback? onComplete}) async {
    if (PurchaseService.instance.adsRemoved) {
      onComplete?.call();
      return;
    }

    // Wait up to 3 seconds if the ad is still loading
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
  // Rewarded ads are gameplay mechanics — they show regardless of Remove Ads.
  // (Remove Ads only removes passive ads: banner + interstitial.)
  RewardedAd? _rewardedAd;
  bool        _rewardedReady   = false;
  bool        _rewardedLoading = false;

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
          _onAdLoadSuccess();
        },
        onAdFailedToLoad: (_) {
          _rewardedReady   = false;
          _rewardedLoading = false;
          _onAdLoadFailed();
          Future.delayed(const Duration(seconds: 15), loadRewarded);
        },
      ),
    );
  }

  /// Shows a rewarded ad. Waits up to 3s if still loading.
  /// Returns true if ad was shown and reward earned.
  Future<bool> showRewarded({
    required VoidCallback onRewarded,
    VoidCallback? onSkipped,
    VoidCallback? onUnavailable,
  }) async {
    // Wait up to 3s if loading
    if (!_rewardedReady) {
      for (int i = 0; i < 6; i++) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (_rewardedReady) break;
      }
    }

    if (!_rewardedReady || _rewardedAd == null) {
      onUnavailable?.call();
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
        onUnavailable?.call();
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
  void init() {
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
