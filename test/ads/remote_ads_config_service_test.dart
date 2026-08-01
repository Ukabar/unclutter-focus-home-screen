import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stillscreen_focus_launcher/features/ads/remote_ads_config_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const String validConfig = '''
{
  "version": 1,
  "ads": {
    "enabled": true,
    "cache_hours": 6,
    "banner": {
      "enabled": true,
      "provider": "admob",
      "ids": ["ca-app-pub-1/2"]
    }
  }
}
''';

  test('cached valid config is used immediately', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'ads_config_last_valid_json_v1': validConfig,
    });
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final RemoteAdsConfigService service = RemoteAdsConfigService(
      preferences: preferences,
      client: MockClient((http.Request request) async {
        throw StateError('network should not be used');
      }),
    );

    final config = service.loadCachedOrFallback();

    expect(config.enabled, isTrue);
    expect(config.banner.enabled, isTrue);
  });

  test('failed refresh preserves cache', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'ads_config_last_valid_json_v1': validConfig,
      'ads_config_last_success_epoch_ms_v1': 0,
    });
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final RemoteAdsConfigService service = RemoteAdsConfigService(
      preferences: preferences,
      now: () =>
          DateTime.fromMillisecondsSinceEpoch(Duration(days: 2).inMilliseconds),
      client: MockClient((http.Request request) async {
        return http.Response('not found', 404);
      }),
    );

    final config = await service.refreshIfExpired(
      service.loadCachedOrFallback(),
    );

    expect(config.enabled, isTrue);
    expect(config.banner.enabled, isTrue);
  });

  test('successful refresh replaces cache only after valid response', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final RemoteAdsConfigService service = RemoteAdsConfigService(
      preferences: preferences,
      client: MockClient((http.Request request) async {
        expect(request.url.toString(), AdsRemoteConfigLinks.rawConfigUrl);
        return http.Response(validConfig, 200);
      }),
    );

    final config = await service.refresh();

    expect(config.enabled, isTrue);
    expect(preferences.getString('ads_config_last_valid_json_v1'), validConfig);
    expect(preferences.getInt('ads_config_last_valid_version_v1'), 1);
    expect(
      preferences.getInt('ads_config_last_success_epoch_ms_v1'),
      isNotNull,
    );
  });
}
