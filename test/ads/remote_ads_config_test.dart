import 'package:stillscreen_focus_launcher/features/ads/remote_ads_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const String newSchema = '''
{
  "version": 1,
  "ads": {
    "enabled": true,
    "cache_hours": 6,
    "banner": {
      "enabled": true,
      "provider": "admob",
      "ids": ["ca-app-pub-7416708332505708/6436767011"]
    },
    "interstitial": {
      "enabled": true,
      "provider": "admob",
      "ids": ["ca-app-pub-7416708332505708/4796382288"],
      "minimum_actions_before_first": 3,
      "every_actions": 4,
      "cooldown_seconds": 120
    },
    "app_open": {
      "enabled": true,
      "provider": "admob",
      "ids": ["ca-app-pub-7416708332505708/7509195590"],
      "minimum_background_seconds": 240,
      "cooldown_seconds": 14400,
      "show_on_first_launch": false
    },
    "native": {
      "enabled": true,
      "provider": "admob",
      "ids": ["ca-app-pub-7416708332505708/2170218945"],
      "insert_every_items": 5
    },
    "rewarded": {
      "enabled": false,
      "provider": "admob",
      "ids": ["ca-app-pub-7416708332505708/3483300615"]
    }
  }
}
''';

  test('new JSON schema parses correctly', () {
    final RemoteAdsConfig config = RemoteAdsConfig.tryParse(newSchema)!;

    expect(config.enabled, isTrue);
    expect(config.banner.enabled, isTrue);
    expect(config.banner.firstId, 'ca-app-pub-7416708332505708/6436767011');
    expect(config.interstitial.minimumActionsBeforeFirst, 3);
    expect(config.interstitial.everyActions, 4);
    expect(config.appOpen.minimumBackgroundSeconds, 240);
    expect(config.native.insertEveryItems, 5);
    expect(config.rewarded.enabled, isFalse);
  });

  test('old JSON schema parses conservatively', () {
    const String raw = '''
{
  "ads": {
    "admob": {
      "openAdsIds": "ca-app-pub-1/2",
      "bannerIds": ["ca-app-pub-1/3"],
      "interIds": ["ca-app-pub-1/4"],
      "nativeIds": ["ca-app-pub-1/5"],
      "rewardIds": [""]
    },
    "settings": {
      "openads": "admob",
      "banners": "admob",
      "inters": "admob",
      "natives": "admob",
      "rewards": "admob"
    }
  }
}
''';

    final RemoteAdsConfig config = RemoteAdsConfig.tryParse(raw)!;

    expect(config.enabled, isTrue);
    expect(config.appOpen.enabled, isTrue);
    expect(config.banner.enabled, isTrue);
    expect(config.interstitial.enabled, isTrue);
    expect(config.native.enabled, isTrue);
    expect(config.rewarded.enabled, isFalse);
    expect(config.interstitial.everyActions, AdsRemoteDefaults.everyActions);
  });

  test('new schema takes precedence when both are present', () {
    const String raw = '''
{
  "version": 1,
  "ads": {
    "enabled": false,
    "admob": {"bannerIds": ["ca-app-pub-1/old"]},
    "settings": {"banners": "admob"},
    "banner": {
      "enabled": true,
      "provider": "admob",
      "ids": ["ca-app-pub-1/new"]
    }
  }
}
''';

    final RemoteAdsConfig config = RemoteAdsConfig.tryParse(raw)!;

    expect(config.enabled, isFalse);
    expect(config.banner.enabled, isFalse);
    expect(config.banner.firstId, 'ca-app-pub-1/new');
  });

  test('invalid fields use safe defaults and invalid ids are rejected', () {
    const String raw = '''
{
  "version": 1,
  "ads": {
    "enabled": true,
    "cache_hours": 1000,
    "banner": {
      "enabled": true,
      "provider": "applovin",
      "ids": ["bad", "ca-app-pub-1/2", "ca-app-pub-1/2"]
    },
    "interstitial": {
      "enabled": true,
      "provider": "admob",
      "ids": ["ca-app-pub-1/3"],
      "minimum_actions_before_first": -4,
      "every_actions": 0,
      "cooldown_seconds": 2
    },
    "app_open": {
      "enabled": true,
      "provider": "admob",
      "ids": [],
      "minimum_background_seconds": 1,
      "cooldown_seconds": 1
    },
    "native": {
      "enabled": true,
      "provider": "",
      "ids": ["ca-app-pub-1/4"],
      "insert_every_items": 2
    }
  }
}
''';

    final RemoteAdsConfig config = RemoteAdsConfig.tryParse(raw)!;

    expect(config.cacheHours, AdsRemoteDefaults.cacheHours);
    expect(config.banner.enabled, isFalse);
    expect(config.banner.ids, <String>['ca-app-pub-1/2']);
    expect(
      config.interstitial.minimumActionsBeforeFirst,
      AdsRemoteDefaults.minimumActionsBeforeFirst,
    );
    expect(config.interstitial.everyActions, AdsRemoteDefaults.everyActions);
    expect(
      config.interstitial.cooldownSeconds,
      AdsRemoteDefaults.interstitialCooldownSeconds,
    );
    expect(config.appOpen.enabled, isFalse);
    expect(config.native.enabled, isFalse);
  });

  test('missing config disables all ads', () {
    final RemoteAdsConfig config = RemoteAdsConfig.tryParse('{}')!;

    expect(config.enabled, isFalse);
    expect(config.banner.enabled, isFalse);
    expect(config.interstitial.enabled, isFalse);
    expect(config.appOpen.enabled, isFalse);
    expect(config.native.enabled, isFalse);
    expect(config.rewarded.enabled, isFalse);
  });

  test('global kill switch disables all formats', () {
    const String raw = '''
{
  "version": 1,
  "ads": {
    "enabled": false,
    "banner": {
      "enabled": true,
      "provider": "admob",
      "ids": ["ca-app-pub-1/2"]
    },
    "interstitial": {
      "enabled": true,
      "provider": "admob",
      "ids": ["ca-app-pub-1/3"]
    }
  }
}
''';

    final RemoteAdsConfig config = RemoteAdsConfig.tryParse(raw)!;

    expect(config.enabled, isFalse);
    expect(config.banner.enabled, isFalse);
    expect(config.interstitial.enabled, isFalse);
  });

  test('individual switches disable only their formats', () {
    const String raw = '''
{
  "version": 1,
  "ads": {
    "enabled": true,
    "banner": {
      "enabled": false,
      "provider": "admob",
      "ids": ["ca-app-pub-1/2"]
    },
    "interstitial": {
      "enabled": true,
      "provider": "admob",
      "ids": ["ca-app-pub-1/3"]
    }
  }
}
''';

    final RemoteAdsConfig config = RemoteAdsConfig.tryParse(raw)!;

    expect(config.banner.enabled, isFalse);
    expect(config.interstitial.enabled, isTrue);
  });
}
