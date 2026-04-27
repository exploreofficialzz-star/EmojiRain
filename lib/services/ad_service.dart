import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../constants/app_constants.dart';

class AdService {
  AdService._();
  static final AdService instance = AdService._();

  // ── Banner ─────────────────────────────────────────────────────────────────
  BannerAd? _bannerAd;
  bool _bannerLoaded = false;

  BannerAd? get bannerAd => _bannerLoaded ? _bannerAd : null;

  void loadBanner({AdSize size = AdSize.banner, VoidCallback? onLoaded}) {
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
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
          _bannerLoaded = false;
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
  bool _interstitialReady = false;

  bool get interstitialReady => _interstitialReady;

  void loadInterstitial() {
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
          Future.delayed(const Duration(seconds: 15), loadInterstitial);
        },
      ),
    );
  }

  // Fix: parameter renamed to onComplete to match call sites
  Future<void> showInterstitial({VoidCallback? onComplete}) async {
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
  bool _rewardedReady = false;

  bool get rewardedReady => _rewardedReady;

  void loadRewarded() {
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
