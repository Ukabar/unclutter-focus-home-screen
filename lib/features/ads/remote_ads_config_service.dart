import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'remote_ads_config.dart';

class AdsRemoteConfigLinks {
  const AdsRemoteConfigLinks._();

  static const String rawConfigUrl =
      'https://raw.githubusercontent.com/Ukabar/Ads-config_screen/main/Ads-config';
}

class RemoteAdsConfigService {
  RemoteAdsConfigService({
    required this.preferences,
    http.Client? client,
    DateTime Function()? now,
  }) : _client = client ?? http.Client(),
       _now = now ?? DateTime.now;

  static const String _cacheJsonKey = 'ads_config_last_valid_json_v1';
  static const String _cacheVersionKey = 'ads_config_last_valid_version_v1';
  static const String _lastFetchKey = 'ads_config_last_success_epoch_ms_v1';

  final SharedPreferences preferences;
  final http.Client _client;
  final DateTime Function() _now;

  RemoteAdsConfig loadCachedOrFallback() {
    final String? raw = preferences.getString(_cacheJsonKey);
    if (raw == null) {
      return RemoteAdsConfig.disabled();
    }
    return RemoteAdsConfig.tryParse(raw) ?? RemoteAdsConfig.disabled();
  }

  Future<RemoteAdsConfig> refreshIfExpired(RemoteAdsConfig current) async {
    if (!_isExpired(current)) {
      return current;
    }
    return refresh();
  }

  Future<RemoteAdsConfig> refresh() async {
    try {
      final http.Response response = await _client
          .get(Uri.parse(AdsRemoteConfigLinks.rawConfigUrl))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) {
        return loadCachedOrFallback();
      }

      final RemoteAdsConfig? parsed = RemoteAdsConfig.tryParse(response.body);
      if (parsed == null) {
        return loadCachedOrFallback();
      }

      await preferences.setString(_cacheJsonKey, response.body);
      await preferences.setInt(_cacheVersionKey, parsed.version);
      await preferences.setInt(_lastFetchKey, _now().millisecondsSinceEpoch);
      return parsed;
    } on Object {
      return loadCachedOrFallback();
    }
  }

  bool _isExpired(RemoteAdsConfig config) {
    final int? lastFetch = preferences.getInt(_lastFetchKey);
    if (lastFetch == null) {
      return true;
    }
    final DateTime lastFetchTime = DateTime.fromMillisecondsSinceEpoch(
      lastFetch,
    );
    return _now().difference(lastFetchTime) >=
        Duration(hours: config.cacheHours);
  }
}
