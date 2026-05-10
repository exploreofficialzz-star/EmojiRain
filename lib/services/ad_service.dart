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
    // Skip loading if ads are removed or device is offline
    if (PurchaseService.instance.adsRemoved) return;
    if (NetworkService.instance.isOffline)   return;

    _bannerAd?.dispose();
    _bannerLoaded = false;

    _bannerAd = BannerAd(
      adUnitId: AdIds.banner,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          _bannerLoaded = true;
          onLoaded?.call();
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          _bannerLoaded = false;
          // Retry after 20s only if still online and ads not removed
          Future.delayed(const Duration(seconds: 20), () {
            if (!PurchaseService.instance.adsRemoved &&
                NetworkService.instance.isOnline) {
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
  bool            _interstitialReady = false;

  bool get interstitialReady => _interstitialReady;

  void loadInterstitial() {
    if (PurchaseService.instance.adsRemoved) return;
    if (NetworkService.instance.isOffline)   return;

    _interstitialReady = false;

    InterstitialAd.load(
      adUnitId: AdIds.interstitial,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd    = ad;
          _interstitialReady = true;
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
        onAdFailedToLoad: (_) {
          _interstitialReady = false;
          Future.delayed(const Duration(seconds: 15), () {
            if (!PurchaseService.instance.adsRemoved &&
                NetworkService.instance.isOnline) {
              loadInterstitial();
            }
          });
        },
      ),
    );
  }

  Future<void> showInterstitial({VoidCallback? onComplete}) async {
    // Skip entirely if ads are removed — call completion immediately
    if (PurchaseService.instance.adsRemoved) {
      onComplete?.call();
      return;
    }

    // Skip if offline — don't block the user
    if (NetworkService.instance.isOffline) {
      onComplete?.call();
      return;
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
  // NOTE: Rewarded ads are ALWAYS available regardless of Remove Ads purchase.
  // They are gameplay mechanics (wrong tap continues, slow mo) — not just ads.
  // The Remove Ads purchase only removes passive ads (banner + interstitial).
  RewardedAd? _rewardedAd;
  bool        _rewardedReady = false;

  bool get rewardedReady => _rewardedReady;

  void loadRewarded() {
    // Always attempt to load rewarded — it's a gameplay feature
    if (NetworkService.instance.isOffline) return;

    _rewardedReady = false;

    RewardedAd.load(
      adUnitId: AdIds.rewarded,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd    = ad;
          _rewardedReady = true;
        },
        onAdFailedToLoad: (_) {
          _rewardedReady = false;
          Future.delayed(const Duration(seconds: 15), () {
            if (NetworkService.instance.isOnline) loadRewarded();
          });
        },
      ),
    );
  }

  /// Shows a rewarded ad.
  /// Returns true  → ad was shown.
  /// Returns false → ad unavailable (offline or not loaded).
  Future<bool> showRewarded({
    required VoidCallback onRewarded,
    VoidCallback? onSkipped,
    VoidCallback? onUnavailable,
  }) async {
    // Rewarded is always shown regardless of adsRemoved status
    if (NetworkService.instance.isOffline) {
      onUnavailable?.call();
      return false;
    }

    if (!_rewardedReady || _rewardedAd == null) {
      onUnavailable?.call();
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
