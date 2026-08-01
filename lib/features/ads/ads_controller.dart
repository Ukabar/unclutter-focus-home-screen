import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'remote_ads_config.dart';
import 'remote_ads_config_service.dart';

class AdsController extends ChangeNotifier with WidgetsBindingObserver {
  AdsController({
    required this.configService,
    required this.preferences,
    this.gateway = const GoogleMobileAdsGateway(),
    TargetPlatform? platform,
    this.debugMode = kDebugMode,
  }) : _platform = platform ?? defaultTargetPlatform;

  static const String _completedActionsKey = 'ads_completed_actions_v1';
  static const String _lastInterstitialShownKey =
      'ads_last_interstitial_shown_epoch_ms_v1';
  static const String _lastAppOpenShownKey =
      'ads_last_app_open_shown_epoch_ms_v1';

  final RemoteAdsConfigService configService;
  final SharedPreferences preferences;
  final AdsGateway gateway;
  final TargetPlatform _platform;
  final bool debugMode;

  RemoteAdsConfig _config = RemoteAdsConfig.disabled();
  InterstitialAd? _interstitialAd;
  AppOpenAd? _appOpenAd;
  DateTime? _backgroundedAt;
  bool _initialized = false;
  bool _isFullscreenAdVisible = false;
  bool _pastOnboarding = false;
  bool _primaryOperationActive = false;

  RemoteAdsConfig get config => _config;
  bool get isSupportedPlatform => !kIsWeb && _platform == TargetPlatform.iOS;
  bool get canShowBanner => isSupportedPlatform && _config.banner.enabled;
  bool get canRequestNative => isSupportedPlatform && _config.native.enabled;
  bool get rewardedParsedOnly => _config.rewarded.enabled;

  Future<void> initialize({required bool pastOnboarding}) async {
    _pastOnboarding = pastOnboarding;
    _config = configService.loadCachedOrFallback();
    notifyListeners();

    unawaited(_refreshConfigAndPrepareAds());
    WidgetsBinding.instance.addObserver(this);
  }

  Future<void> _refreshConfigAndPrepareAds() async {
    final RemoteAdsConfig refreshed = await configService.refreshIfExpired(
      _config,
    );
    _config = refreshed;
    notifyListeners();

    if (!isSupportedPlatform || !_config.enabled) {
      disposeLoadedAds();
      return;
    }

    if (!_initialized) {
      _initialized = true;
      await gateway.initialize();
    }

    _preloadInterstitial();
    _preloadAppOpen();
  }

  void updateSessionState({
    required bool pastOnboarding,
    bool primaryOperationActive = false,
  }) {
    _pastOnboarding = pastOnboarding;
    _primaryOperationActive = primaryOperationActive;
  }

  Future<void> recordMeaningfulActionCompleted({
    required bool resultVisible,
    bool modalVisible = false,
  }) async {
    if (!resultVisible) {
      return;
    }

    final int nextCount = preferences.getInt(_completedActionsKey) ?? 0;
    await preferences.setInt(_completedActionsKey, nextCount + 1);
    await tryShowInterstitial(modalVisible: modalVisible);
  }

  Future<bool> tryShowInterstitial({bool modalVisible = false}) async {
    if (!_canShowInterstitial(modalVisible: modalVisible)) {
      return false;
    }

    final InterstitialAd? ad = _interstitialAd;
    if (ad == null) {
      return false;
    }

    _interstitialAd = null;
    _isFullscreenAdVisible = true;
    ad.fullScreenContentCallback = FullScreenContentCallback<InterstitialAd>(
      onAdDismissedFullScreenContent: (InterstitialAd ad) {
        ad.dispose();
        _isFullscreenAdVisible = false;
        _markInterstitialShown();
        _preloadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
        ad.dispose();
        _isFullscreenAdVisible = false;
        _preloadInterstitial();
      },
    );
    await ad.show();
    return true;
  }

  bool _canShowInterstitial({required bool modalVisible}) {
    if (!isSupportedPlatform ||
        !_pastOnboarding ||
        !_config.enabled ||
        !_config.interstitial.enabled ||
        modalVisible ||
        _isFullscreenAdVisible ||
        _primaryOperationActive) {
      return false;
    }
    final int actions = preferences.getInt(_completedActionsKey) ?? 0;
    final InterstitialAdsConfig interstitial = _config.interstitial;
    if (actions < interstitial.minimumActionsBeforeFirst) {
      return false;
    }
    if ((actions - interstitial.minimumActionsBeforeFirst) %
            interstitial.everyActions !=
        0) {
      return false;
    }
    return _cooldownElapsed(
      _lastInterstitialShownKey,
      Duration(seconds: interstitial.cooldownSeconds),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _backgroundedAt = DateTime.now();
      return;
    }
    if (state == AppLifecycleState.resumed) {
      unawaited(tryShowAppOpen());
    }
  }

  Future<bool> tryShowAppOpen({bool modalVisible = false}) async {
    if (!_canShowAppOpen(modalVisible: modalVisible)) {
      return false;
    }

    final AppOpenAd? ad = _appOpenAd;
    if (ad == null) {
      return false;
    }

    _appOpenAd = null;
    _isFullscreenAdVisible = true;
    ad.fullScreenContentCallback = FullScreenContentCallback<AppOpenAd>(
      onAdDismissedFullScreenContent: (AppOpenAd ad) {
        ad.dispose();
        _isFullscreenAdVisible = false;
        _markAppOpenShown();
        _preloadAppOpen();
      },
      onAdFailedToShowFullScreenContent: (AppOpenAd ad, AdError error) {
        ad.dispose();
        _isFullscreenAdVisible = false;
        _preloadAppOpen();
      },
    );
    await ad.show();
    return true;
  }

  bool _canShowAppOpen({required bool modalVisible}) {
    final DateTime? backgroundedAt = _backgroundedAt;
    if (!isSupportedPlatform ||
        !_pastOnboarding ||
        !_config.enabled ||
        !_config.appOpen.enabled ||
        !_config.appOpen.showOnFirstLaunch && backgroundedAt == null ||
        modalVisible ||
        _isFullscreenAdVisible ||
        _primaryOperationActive) {
      return false;
    }
    if (backgroundedAt != null &&
        DateTime.now().difference(backgroundedAt) <
            Duration(seconds: _config.appOpen.minimumBackgroundSeconds)) {
      return false;
    }
    return _cooldownElapsed(
      _lastAppOpenShownKey,
      Duration(seconds: _config.appOpen.cooldownSeconds),
    );
  }

  void _preloadInterstitial() {
    if (!isSupportedPlatform || !_config.interstitial.enabled) {
      _interstitialAd?.dispose();
      _interstitialAd = null;
      return;
    }
    final String? id = _adUnitId(
      _config.interstitial.ids,
      AdFormat.interstitial,
    );
    if (id == null || _interstitialAd != null) {
      return;
    }
    gateway.loadInterstitial(
      adUnitId: id,
      onLoaded: (InterstitialAd ad) => _interstitialAd = ad,
    );
  }

  void _preloadAppOpen() {
    if (!isSupportedPlatform || !_config.appOpen.enabled) {
      _appOpenAd?.dispose();
      _appOpenAd = null;
      return;
    }
    final String? id = _adUnitId(_config.appOpen.ids, AdFormat.appOpen);
    if (id == null || _appOpenAd != null) {
      return;
    }
    gateway.loadAppOpen(
      adUnitId: id,
      onLoaded: (AppOpenAd ad) => _appOpenAd = ad,
    );
  }

  String? bannerAdUnitId() => _adUnitId(_config.banner.ids, AdFormat.banner);

  String? nativeAdUnitId() => _adUnitId(_config.native.ids, AdFormat.native);

  String? _adUnitId(List<String> remoteIds, AdFormat format) {
    if (debugMode) {
      return switch (format) {
        AdFormat.banner => 'ca-app-pub-3940256099942544/2934735716',
        AdFormat.interstitial => 'ca-app-pub-3940256099942544/4411468910',
        AdFormat.appOpen => 'ca-app-pub-3940256099942544/5662855259',
        AdFormat.native => 'ca-app-pub-3940256099942544/3986624511',
        AdFormat.rewarded => 'ca-app-pub-3940256099942544/1712485313',
      };
    }
    return remoteIds.isEmpty ? null : remoteIds.first;
  }

  bool _cooldownElapsed(String key, Duration cooldown) {
    final int? lastShown = preferences.getInt(key);
    if (lastShown == null) {
      return true;
    }
    final DateTime lastShownTime = DateTime.fromMillisecondsSinceEpoch(
      lastShown,
    );
    return DateTime.now().difference(lastShownTime) >= cooldown;
  }

  Future<void> _markInterstitialShown() async {
    await preferences.setInt(
      _lastInterstitialShownKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<void> _markAppOpenShown() async {
    await preferences.setInt(
      _lastAppOpenShownKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  void disposeLoadedAds() {
    _interstitialAd?.dispose();
    _appOpenAd?.dispose();
    _interstitialAd = null;
    _appOpenAd = null;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    disposeLoadedAds();
    super.dispose();
  }
}

enum AdFormat { banner, interstitial, appOpen, native, rewarded }

abstract interface class AdsGateway {
  Future<void> initialize();

  void loadInterstitial({
    required String adUnitId,
    required ValueChanged<InterstitialAd> onLoaded,
  });

  void loadAppOpen({
    required String adUnitId,
    required ValueChanged<AppOpenAd> onLoaded,
  });
}

class GoogleMobileAdsGateway implements AdsGateway {
  const GoogleMobileAdsGateway();

  @override
  Future<void> initialize() async {
    await MobileAds.instance.initialize();
  }

  @override
  void loadInterstitial({
    required String adUnitId,
    required ValueChanged<InterstitialAd> onLoaded,
  }) {
    InterstitialAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: onLoaded,
        onAdFailedToLoad: (LoadAdError error) {},
      ),
    );
  }

  @override
  void loadAppOpen({
    required String adUnitId,
    required ValueChanged<AppOpenAd> onLoaded,
  }) {
    AppOpenAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: onLoaded,
        onAdFailedToLoad: (LoadAdError error) {},
      ),
    );
  }
}
