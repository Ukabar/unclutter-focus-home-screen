import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stillscreen_focus_launcher/features/ads/ad_ids.dart';
import 'package:stillscreen_focus_launcher/features/ads/ads_controller.dart';
import 'package:stillscreen_focus_launcher/features/ads/remote_ads_config_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const String enabledConfig = '''
{
  "version": 1,
  "ads": {
    "enabled": true,
    "banner": {
      "enabled": true,
      "provider": "admob",
      "ids": ["ca-app-pub-1/2"]
    },
    "interstitial": {
      "enabled": true,
      "provider": "admob",
      "ids": ["ca-app-pub-1/3"],
      "minimum_actions_before_first": 1,
      "every_actions": 1,
      "cooldown_seconds": 30
    },
    "app_open": {
      "enabled": true,
      "provider": "admob",
      "ids": ["ca-app-pub-1/4"]
    }
  }
}
''';

  test(
    'Android does not initialize or load AdMob in this iOS-only app',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'ads_config_last_valid_json_v1': enabledConfig,
        'ads_config_last_success_epoch_ms_v1':
            DateTime.now().millisecondsSinceEpoch,
      });
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();
      final FakeAdsGateway gateway = FakeAdsGateway();
      final AdsController controller = AdsController(
        configService: RemoteAdsConfigService(preferences: preferences),
        preferences: preferences,
        gateway: gateway,
        platform: TargetPlatform.android,
        debugMode: false,
      );

      await controller.initialize(pastOnboarding: true);
      await controller.recordMeaningfulActionCompleted(resultVisible: true);

      expect(controller.isSupportedPlatform, isFalse);
      expect(controller.canShowBanner, isFalse);
      expect(gateway.initializeCount, 0);
      expect(gateway.interstitialLoads, 0);
      expect(gateway.appOpenLoads, 0);

      controller.dispose();
    },
  );

  test('AdMob initialization failure does not crash the controller', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'ads_config_last_valid_json_v1': enabledConfig,
      'ads_config_last_success_epoch_ms_v1':
          DateTime.now().millisecondsSinceEpoch,
    });
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final FakeAdsGateway gateway = FakeAdsGateway(failInitialize: true);
    final AdsController controller = AdsController(
      configService: RemoteAdsConfigService(preferences: preferences),
      preferences: preferences,
      gateway: gateway,
      platform: TargetPlatform.iOS,
      debugMode: false,
    );

    await controller.initialize(pastOnboarding: true);

    expect(controller.isSupportedPlatform, isTrue);
    expect(controller.canShowBanner, isTrue);
    expect(gateway.initializeCount, 1);
    expect(gateway.interstitialLoads, 0);
    expect(gateway.appOpenLoads, 0);

    controller.dispose();
  });

  test('Debug mode uses Google test ad unit ids', () {
    expect(
      AdIds.unitId(
        format: AdFormat.banner,
        remoteIds: const <String>['ca-app-pub-1/production'],
        debugMode: true,
      ),
      'ca-app-pub-3940256099942544/2934735716',
    );
    expect(
      AdIds.unitId(
        format: AdFormat.interstitial,
        remoteIds: const <String>['ca-app-pub-1/production'],
        debugMode: true,
      ),
      'ca-app-pub-3940256099942544/4411468910',
    );
  });
}

class FakeAdsGateway implements AdsGateway {
  FakeAdsGateway({this.failInitialize = false});

  final bool failInitialize;
  int initializeCount = 0;
  int interstitialLoads = 0;
  int appOpenLoads = 0;

  @override
  Future<void> initialize() async {
    initializeCount++;
    if (failInitialize) {
      throw StateError('AdMob unavailable');
    }
  }

  @override
  void loadAppOpen({
    required String adUnitId,
    required ValueChanged<AppOpenAd> onLoaded,
  }) {
    appOpenLoads++;
  }

  @override
  void loadInterstitial({
    required String adUnitId,
    required ValueChanged<InterstitialAd> onLoaded,
  }) {
    interstitialLoads++;
  }
}
