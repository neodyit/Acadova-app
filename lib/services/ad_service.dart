import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  /// Global toggle for enabling/disabling ads in the app
  bool areAdsEnabled = true;

  /// Counter to throttle full-screen interstitial ads (e.g. show every N attempts)
  int _quizCompletedCount = 0;
  final int interstitialFrequency = 2; // Show interstitial every 2 quiz completions

  InterstitialAd? _interstitialAd;
  bool _isInterstitialAdLoading = false;

  RewardedAd? _rewardedAd;
  bool _isRewardedAdLoading = false;

  /// Initialize Google Mobile Ads SDK safely
  Future<void> init() async {
    if (_isInitialized) return;
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      debugPrint('AdService: Mobile Ads SDK not supported on this platform.');
      return;
    }

    try {
      await MobileAds.instance.initialize();
      _isInitialized = true;
      debugPrint('AdService: Mobile Ads SDK initialized successfully.');

      // Preload initial interstitial & rewarded ads
      preloadInterstitialAd();
      preloadRewardedAd();
    } catch (e) {
      debugPrint('AdService initialization failed: $e');
    }
  }

  /// Global toggle for using Test Ads during development or while AdMob app is "Requires Review".
  /// Set to false when ready to serve live production ads after AdMob approval.
  bool useTestAds = kDebugMode;

  /// Whether current platform supports Mobile Ads
  bool get isPlatformSupported {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  /// Banner Ad Unit ID
  String get bannerAdUnitId {
    if (kIsWeb) return '';
    if (useTestAds) {
      return Platform.isAndroid
          ? 'ca-app-pub-3940256099942544/6300978111' // Google Test Banner (Android)
          : 'ca-app-pub-3940256099942544/2934735716'; // Google Test Banner (iOS)
    }
    if (Platform.isAndroid || Platform.isIOS) {
      return 'ca-app-pub-2117456188378823/5763506647';
    }
    return '';
  }

  /// Native Ad Unit ID
  String get nativeAdUnitId {
    if (kIsWeb) return '';
    if (useTestAds) {
      return Platform.isAndroid
          ? 'ca-app-pub-3940256099942544/2247696110' // Google Test Native (Android)
          : 'ca-app-pub-3940256099942544/3986624511'; // Google Test Native (iOS)
    }
    if (Platform.isAndroid || Platform.isIOS) {
      return 'ca-app-pub-2117456188378823/3845499329';
    }
    return '';
  }

  /// Interstitial Ad Unit ID
  String get interstitialAdUnitId {
    if (kIsWeb) return '';
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/1033173712';
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/4411468910';
    }
    return '';
  }

  /// Rewarded Ad Unit ID
  String get rewardedAdUnitId {
    if (kIsWeb) return '';
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/5224354917';
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/1712484513';
    }
    return '';
  }

  // ==================== INTERSTITIAL ADS ====================

  /// Preload an Interstitial Ad
  void preloadInterstitialAd() {
    if (!areAdsEnabled || !isPlatformSupported || _isInterstitialAdLoading || _interstitialAd != null) {
      return;
    }

    _isInterstitialAdLoading = true;
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialAdLoading = false;
          debugPrint('AdService: Interstitial ad loaded.');
        },
        onAdFailedToLoad: (error) {
          _interstitialAd = null;
          _isInterstitialAdLoading = false;
          debugPrint('AdService: Interstitial ad failed to load: ${error.message}');
        },
      ),
    );
  }

  /// Show Interstitial Ad if available and frequency condition met
  void showInterstitialAdIfReady({VoidCallback? onDismissed, bool forceShow = false}) {
    if (!areAdsEnabled || !isPlatformSupported) {
      onDismissed?.call();
      return;
    }

    _quizCompletedCount++;

    if (!forceShow && (_quizCompletedCount % interstitialFrequency != 0)) {
      onDismissed?.call();
      return;
    }

    if (_interstitialAd != null) {
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _interstitialAd = null;
          preloadInterstitialAd();
          onDismissed?.call();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          _interstitialAd = null;
          preloadInterstitialAd();
          onDismissed?.call();
        },
      );

      _interstitialAd!.show();
    } else {
      preloadInterstitialAd();
      onDismissed?.call();
    }
  }

  // ==================== REWARDED ADS ====================

  /// Preload a Rewarded Ad
  void preloadRewardedAd() {
    if (!areAdsEnabled || !isPlatformSupported || _isRewardedAdLoading || _rewardedAd != null) {
      return;
    }

    _isRewardedAdLoading = true;
    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isRewardedAdLoading = false;
          debugPrint('AdService: Rewarded ad loaded.');
        },
        onAdFailedToLoad: (error) {
          _rewardedAd = null;
          _isRewardedAdLoading = false;
          debugPrint('AdService: Rewarded ad failed to load: ${error.message}');
        },
      ),
    );
  }

  /// Show Rewarded Ad with custom reward callback
  void showRewardedAd({
    required Function(RewardItem reward) onUserEarnedReward,
    VoidCallback? onDismissed,
  }) {
    if (!areAdsEnabled || !isPlatformSupported) {
      onDismissed?.call();
      return;
    }

    if (_rewardedAd != null) {
      _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _rewardedAd = null;
          preloadRewardedAd();
          onDismissed?.call();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          _rewardedAd = null;
          preloadRewardedAd();
          onDismissed?.call();
        },
      );

      _rewardedAd!.show(onUserEarnedReward: (ad, reward) {
        onUserEarnedReward(reward);
      });
    } else {
      preloadRewardedAd();
      onDismissed?.call();
    }
  }
}
