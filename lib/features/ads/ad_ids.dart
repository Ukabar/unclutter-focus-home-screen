import 'package:flutter/foundation.dart';

enum AdFormat { banner, interstitial, appOpen, native, rewarded }

class AdIds {
  const AdIds._();

  static String? unitId({
    required AdFormat format,
    required List<String> remoteIds,
    bool debugMode = kDebugMode,
  }) {
    if (debugMode) {
      return testUnitId(format);
    }
    return remoteIds.isEmpty ? null : remoteIds.first;
  }

  static String testUnitId(AdFormat format) {
    return switch (format) {
      AdFormat.banner => 'ca-app-pub-3940256099942544/2934735716',
      AdFormat.interstitial => 'ca-app-pub-3940256099942544/4411468910',
      AdFormat.appOpen => 'ca-app-pub-3940256099942544/5575463023',
      AdFormat.native => 'ca-app-pub-3940256099942544/3986624511',
      AdFormat.rewarded => 'ca-app-pub-3940256099942544/1712485313',
    };
  }
}
