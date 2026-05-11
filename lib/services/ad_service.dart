import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../constants/app_constants.dart';
import 'network_service.dart';
import 'purchase_service.dart';

class AdService {
  AdService._();
  static final AdService instance = AdService._();

  // ── Banner ────────────────────────────────────────────────────────────────
  BannerAd? _bannerAd;
  bool      _bannerLoaded = false;

  BannerAd? get bannerAd => _bannerLoaded ? _bannerAd : null;

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
          onLoaded?.call();
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          _bannerLoaded = false;
          Future.delayed(const Duration(seconds: 20), () {
            if (!PurchaseService.instance.adsRemoved) {
              loadBanner(onLoaded: onLoaded);
            }
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
  bool            _interstitialReady  = false;
  bool            _interstitialLoading = false;

  bool get interstitialReady => _interstitialReady;

  /// Always pre-load the next interstitial. No network gate — AdMob handles
  /// connection failures internally and calls onAdFailedToLoad.
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

          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (a) {
              a.dispose();
              _interstitialAd    = null;
              _interstitialReady = false;
              loadInterstitial(); // pre-load next one immediately
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
          // Retry after 15s
          Future.delayed(const Duration(seconds: 15), loadInterstitial);
        },
      ),
    );
  }

  /// Shows the interstitial. If the ad isn't ready yet, waits up to 3 seconds
  /// for it to finish loading before giving up — fixing the "not showing" issue.
  Future<void> showInterstitial({VoidCallback? onComplete}) async {
    // Skip if user purchased Remove Ads
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

    // Still not ready — don't block the user, continue
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
  // Rewarded ads are ALWAYS active regardless of Remove Ads purchase.
  // They are gameplay mechanics (slow mo) — not passive interruptions.
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
        },
        onAdFailedToLoad: (_) {
          _rewardedReady   = false;
          _rewardedLoading = false;
          Future.delayed(const Duration(seconds: 15), loadRewarded);
        },
      ),
    );
  }

  /// Returns true if ad was shown, false if unavailable.
  Future<bool> showRewarded({
    required VoidCallback onRewarded,
    VoidCallback? onSkipped,
    VoidCallback? onUnavailable,
  }) async {
    // Wait up to 3 seconds if still loading
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
  }

  void dispose() {
    _bannerAd?.dispose();
    _interstitialAd?.dispose();
    _rewardedAd?.dispose();
  }
}
