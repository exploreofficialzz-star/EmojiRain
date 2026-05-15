import 'dart:async';
import 'package:adblock_detector/adblock_detector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../constants/app_constants.dart';
import 'network_service.dart';
import 'purchase_service.dart';

class AdService extends ChangeNotifier {
  AdService._();
  static final AdService instance = AdService._();

  // ── Ad Blocker Detection ──────────────────────────────────────────────────
  // Two-layer detection:
  // 1. adblock_detector — tests actual reachability of AdMob ad servers
  //    (catches DNS blocking, Private DNS like AdGuard/NextDNS, hosts file)
  // 2. Consecutive failure tracking — catches VPN-level blocking (AdGuard app,
  //    Total Adblock) where ad loads fail but DNS resolves

  bool _adsBlocked          = false;
  int  _consecutiveFailures = 0;
  bool _adBlockCheckDone    = false;

  bool get adsBlocked => _adsBlocked && !PurchaseService.instance.adsRemoved;

  /// Layer 1: DNS-level check using adblock_detector
  /// Runs once on init and re-runs on retryAds()
  Future<void> _checkAdBlocker() async {
    if (!NetworkService.instance.isOnline) return;

    try {
      final detector = AdBlockDetector();
      final blocked  = await detector.isAdBlockEnabled(
        testAdNetworks: [AdNetworks.googleAdMob],
      );
      _adBlockCheckDone = true;
      if (blocked && !_adsBlocked) {
        _adsBlocked = true;
        notifyListeners();
      } else if (!blocked && _adsBlocked && _consecutiveFailures == 0) {
        _adsBlocked = false;
        notifyListeners();
      }
    } catch (_) {
      // adblock_detector threw — fall back to failure tracking only
      _adBlockCheckDone = true;
    }
  }

  /// Layer 2: Consecutive ad-load failure tracking
  /// Catches VPN-based blockers that pass DNS but intercept HTTP ad requests
  void _onAdLoadSuccess() {
    if (_consecutiveFailures == 0 && !_adsBlocked) return;
    _consecutiveFailures = 0;
    // Only clear blocked flag if the DNS check also passed
    if (_adBlockCheckDone && _adsBlocked) {
      _adsBlocked = false;
      notifyListeners();
    }
  }

  void _onAdLoadFailed() {
    if (!NetworkService.instance.isOnline) return; // genuine offline, not blocking
    _consecutiveFailures++;
    if (_consecutiveFailures >= 3 && !_adsBlocked) {
      _adsBlocked = true;
      notifyListeners();
    }
  }

  /// Called from "Enable Ads & Retry" button on the blocker overlay
  Future<void> retryAds() async {
    _consecutiveFailures = 0;
    _adsBlocked          = false;
    _adBlockCheckDone    = false;
    notifyListeners();

    // Re-run DNS check and reload all ads
    await _checkAdBlocker();
    loadInterstitial();
    loadRewarded();
    loadBanner();
  }

  // ── Banner ────────────────────────────────────────────────────────────────
  BannerAd? _bannerAd;
  bool _bannerLoaded = false;

  BannerAd? get bannerAd => _bannerLoaded ? _bannerAd : null;

  void loadBanner({AdSize size = AdSize.banner, VoidCallback? onLoaded}) {
    if (PurchaseService.instance.adsRemoved) return;

    _bannerAd?.dispose();
    _bannerLoaded = false;

    _bannerAd = BannerAd(
      adUnitId: AdIds.banner,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          _bannerLoaded = true;
          _onAdLoadSuccess();
          onLoaded?.call();
        },
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
          _bannerLoaded = false;
          _onAdLoadFailed();
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
    if (PurchaseService.instance.adsRemoved) return;
    _interstitialReady = false;
    InterstitialAd.load(
      adUnitId: AdIds.interstitial,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd    = ad;
          _interstitialReady = true;
          _onAdLoadSuccess();
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
          _onAdLoadFailed();
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
          _onAdLoadSuccess();
        },
        onAdFailedToLoad: (_) {
          _rewardedReady = false;
          _onAdLoadFailed();
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
    // Run DNS-level ad blocker check in background
    _checkAdBlocker();
  }

  void disposeAds() {
    _bannerAd?.dispose();
    _interstitialAd?.dispose();
    _rewardedAd?.dispose();
  }
}
