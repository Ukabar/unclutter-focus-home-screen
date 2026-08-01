import 'dart:convert';

class AdsRemoteDefaults {
  const AdsRemoteDefaults._();

  static const int cacheHours = 6;
  static const int minimumActionsBeforeFirst = 3;
  static const int everyActions = 4;
  static const int interstitialCooldownSeconds = 120;
  static const int appOpenMinimumBackgroundSeconds = 240;
  static const int appOpenCooldownSeconds = 14400;
  static const int nativeInsertEveryItems = 5;
}

class RemoteAdsConfig {
  const RemoteAdsConfig({
    required this.version,
    required this.enabled,
    required this.banner,
    required this.interstitial,
    required this.appOpen,
    required this.native,
    required this.rewarded,
    required this.cacheHours,
  });

  factory RemoteAdsConfig.disabled() {
    return RemoteAdsConfig(
      version: 1,
      enabled: false,
      banner: const BannerAdsConfig.disabled(),
      interstitial: const InterstitialAdsConfig.disabled(),
      appOpen: const AppOpenAdsConfig.disabled(),
      native: const NativeAdsConfig.disabled(),
      rewarded: const RewardedAdsConfig.disabled(),
      cacheHours: AdsRemoteDefaults.cacheHours,
    );
  }

  static RemoteAdsConfig? tryParse(String rawJson) {
    try {
      final Object? decoded = jsonDecode(rawJson);
      if (decoded is! Map<String, Object?>) {
        return null;
      }
      return RemoteAdsConfig.fromJson(decoded);
    } on Object {
      return null;
    }
  }

  factory RemoteAdsConfig.fromJson(Map<String, Object?> json) {
    final Object? ads = json['ads'];
    if (ads is! Map<String, Object?>) {
      return RemoteAdsConfig.disabled();
    }

    if (ads['banner'] is Map<String, Object?> ||
        ads['interstitial'] is Map<String, Object?> ||
        ads['app_open'] is Map<String, Object?>) {
      return RemoteAdsConfig._fromNewSchema(json, ads);
    }

    return RemoteAdsConfig._fromOldSchema(ads);
  }

  factory RemoteAdsConfig._fromNewSchema(
    Map<String, Object?> root,
    Map<String, Object?> ads,
  ) {
    final bool enabled = ads['enabled'] == true;
    return RemoteAdsConfig(
      version: _intInRange(root['version'], min: 1, max: 100, fallback: 1),
      enabled: enabled,
      banner: BannerAdsConfig.fromJson(
        _map(ads['banner']),
        globallyEnabled: enabled,
      ),
      interstitial: InterstitialAdsConfig.fromJson(
        _map(ads['interstitial']),
        globallyEnabled: enabled,
      ),
      appOpen: AppOpenAdsConfig.fromJson(
        _map(ads['app_open']),
        globallyEnabled: enabled,
      ),
      native: NativeAdsConfig.fromJson(
        _map(ads['native']),
        globallyEnabled: enabled,
      ),
      rewarded: RewardedAdsConfig.fromJson(
        _map(ads['rewarded']),
        globallyEnabled: enabled,
      ),
      cacheHours: _intInRange(
        ads['cache_hours'],
        min: 1,
        max: 168,
        fallback: AdsRemoteDefaults.cacheHours,
      ),
    );
  }

  factory RemoteAdsConfig._fromOldSchema(Map<String, Object?> ads) {
    final Map<String, Object?> admob = _map(ads['admob']);
    final Map<String, Object?> settings = _map(ads['settings']);
    final BannerAdsConfig banner = BannerAdsConfig.old(
      enabledProvider: settings['banners'],
      ids: admob['bannerIds'],
    );
    final InterstitialAdsConfig interstitial = InterstitialAdsConfig.old(
      enabledProvider: settings['inters'],
      ids: admob['interIds'],
    );
    final AppOpenAdsConfig appOpen = AppOpenAdsConfig.old(
      enabledProvider: settings['openads'],
      ids: admob['openAdsIds'],
    );
    final NativeAdsConfig native = NativeAdsConfig.old(
      enabledProvider: settings['natives'],
      ids: admob['nativeIds'],
    );
    final RewardedAdsConfig rewarded = RewardedAdsConfig.old(
      enabledProvider: settings['rewards'],
      ids: admob['rewardIds'],
    );
    final bool anyEnabled =
        banner.enabled ||
        interstitial.enabled ||
        appOpen.enabled ||
        native.enabled ||
        rewarded.enabled;

    return RemoteAdsConfig(
      version: 1,
      enabled: anyEnabled,
      banner: banner,
      interstitial: interstitial,
      appOpen: appOpen,
      native: native,
      rewarded: rewarded,
      cacheHours: AdsRemoteDefaults.cacheHours,
    );
  }

  final int version;
  final bool enabled;
  final BannerAdsConfig banner;
  final InterstitialAdsConfig interstitial;
  final AppOpenAdsConfig appOpen;
  final NativeAdsConfig native;
  final RewardedAdsConfig rewarded;
  final int cacheHours;

  bool get allowsAnyAd => enabled;
}

class BannerAdsConfig extends _AdsFormatConfig {
  const BannerAdsConfig({
    required super.enabled,
    required super.provider,
    required super.ids,
  });

  const BannerAdsConfig.disabled()
    : super(enabled: false, provider: 'admob', ids: const <String>[]);

  factory BannerAdsConfig.fromJson(
    Map<String, Object?> json, {
    required bool globallyEnabled,
  }) {
    return BannerAdsConfig(
      enabled: globallyEnabled && json['enabled'] == true,
      provider: _provider(json['provider']),
      ids: _validAdMobIds(json['ids']),
    ).validated();
  }

  factory BannerAdsConfig.old({Object? enabledProvider, Object? ids}) {
    return BannerAdsConfig(
      enabled: _provider(enabledProvider) == 'admob',
      provider: _provider(enabledProvider),
      ids: _validAdMobIds(ids),
    ).validated();
  }

  BannerAdsConfig validated() {
    return BannerAdsConfig(
      enabled: enabled && supportsAdMob && ids.isNotEmpty,
      provider: provider,
      ids: ids,
    );
  }
}

class InterstitialAdsConfig extends _AdsFormatConfig {
  const InterstitialAdsConfig({
    required super.enabled,
    required super.provider,
    required super.ids,
    required this.minimumActionsBeforeFirst,
    required this.everyActions,
    required this.cooldownSeconds,
  });

  const InterstitialAdsConfig.disabled()
    : minimumActionsBeforeFirst = AdsRemoteDefaults.minimumActionsBeforeFirst,
      everyActions = AdsRemoteDefaults.everyActions,
      cooldownSeconds = AdsRemoteDefaults.interstitialCooldownSeconds,
      super(enabled: false, provider: 'admob', ids: const <String>[]);

  factory InterstitialAdsConfig.fromJson(
    Map<String, Object?> json, {
    required bool globallyEnabled,
  }) {
    return InterstitialAdsConfig(
      enabled: globallyEnabled && json['enabled'] == true,
      provider: _provider(json['provider']),
      ids: _validAdMobIds(json['ids']),
      minimumActionsBeforeFirst: _intInRange(
        json['minimum_actions_before_first'],
        min: 0,
        max: 100,
        fallback: AdsRemoteDefaults.minimumActionsBeforeFirst,
      ),
      everyActions: _intInRange(
        json['every_actions'],
        min: 1,
        max: 100,
        fallback: AdsRemoteDefaults.everyActions,
      ),
      cooldownSeconds: _intInRange(
        json['cooldown_seconds'],
        min: 30,
        max: 86400,
        fallback: AdsRemoteDefaults.interstitialCooldownSeconds,
      ),
    ).validated();
  }

  factory InterstitialAdsConfig.old({Object? enabledProvider, Object? ids}) {
    return InterstitialAdsConfig(
      enabled: _provider(enabledProvider) == 'admob',
      provider: _provider(enabledProvider),
      ids: _validAdMobIds(ids),
      minimumActionsBeforeFirst: AdsRemoteDefaults.minimumActionsBeforeFirst,
      everyActions: AdsRemoteDefaults.everyActions,
      cooldownSeconds: AdsRemoteDefaults.interstitialCooldownSeconds,
    ).validated();
  }

  final int minimumActionsBeforeFirst;
  final int everyActions;
  final int cooldownSeconds;

  InterstitialAdsConfig validated() {
    return InterstitialAdsConfig(
      enabled: enabled && supportsAdMob && ids.isNotEmpty,
      provider: provider,
      ids: ids,
      minimumActionsBeforeFirst: minimumActionsBeforeFirst,
      everyActions: everyActions,
      cooldownSeconds: cooldownSeconds,
    );
  }
}

class AppOpenAdsConfig extends _AdsFormatConfig {
  const AppOpenAdsConfig({
    required super.enabled,
    required super.provider,
    required super.ids,
    required this.minimumBackgroundSeconds,
    required this.cooldownSeconds,
    required this.showOnFirstLaunch,
  });

  const AppOpenAdsConfig.disabled()
    : minimumBackgroundSeconds =
          AdsRemoteDefaults.appOpenMinimumBackgroundSeconds,
      cooldownSeconds = AdsRemoteDefaults.appOpenCooldownSeconds,
      showOnFirstLaunch = false,
      super(enabled: false, provider: 'admob', ids: const <String>[]);

  factory AppOpenAdsConfig.fromJson(
    Map<String, Object?> json, {
    required bool globallyEnabled,
  }) {
    return AppOpenAdsConfig(
      enabled: globallyEnabled && json['enabled'] == true,
      provider: _provider(json['provider']),
      ids: _validAdMobIds(json['ids']),
      minimumBackgroundSeconds: _intInRange(
        json['minimum_background_seconds'],
        min: 30,
        max: 86400,
        fallback: AdsRemoteDefaults.appOpenMinimumBackgroundSeconds,
      ),
      cooldownSeconds: _intInRange(
        json['cooldown_seconds'],
        min: 300,
        max: 604800,
        fallback: AdsRemoteDefaults.appOpenCooldownSeconds,
      ),
      showOnFirstLaunch: json['show_on_first_launch'] == true,
    ).validated();
  }

  factory AppOpenAdsConfig.old({Object? enabledProvider, Object? ids}) {
    return AppOpenAdsConfig(
      enabled: _provider(enabledProvider) == 'admob',
      provider: _provider(enabledProvider),
      ids: _validAdMobIds(ids),
      minimumBackgroundSeconds:
          AdsRemoteDefaults.appOpenMinimumBackgroundSeconds,
      cooldownSeconds: AdsRemoteDefaults.appOpenCooldownSeconds,
      showOnFirstLaunch: false,
    ).validated();
  }

  final int minimumBackgroundSeconds;
  final int cooldownSeconds;
  final bool showOnFirstLaunch;

  AppOpenAdsConfig validated() {
    return AppOpenAdsConfig(
      enabled: enabled && supportsAdMob && ids.isNotEmpty,
      provider: provider,
      ids: ids,
      minimumBackgroundSeconds: minimumBackgroundSeconds,
      cooldownSeconds: cooldownSeconds,
      showOnFirstLaunch: showOnFirstLaunch,
    );
  }
}

class NativeAdsConfig extends _AdsFormatConfig {
  const NativeAdsConfig({
    required super.enabled,
    required super.provider,
    required super.ids,
    required this.insertEveryItems,
  });

  const NativeAdsConfig.disabled()
    : insertEveryItems = AdsRemoteDefaults.nativeInsertEveryItems,
      super(enabled: false, provider: 'admob', ids: const <String>[]);

  factory NativeAdsConfig.fromJson(
    Map<String, Object?> json, {
    required bool globallyEnabled,
  }) {
    return NativeAdsConfig(
      enabled: globallyEnabled && json['enabled'] == true,
      provider: _provider(json['provider']),
      ids: _validAdMobIds(json['ids']),
      insertEveryItems: _intInRange(
        json['insert_every_items'],
        min: 3,
        max: 50,
        fallback: AdsRemoteDefaults.nativeInsertEveryItems,
      ),
    ).validated();
  }

  factory NativeAdsConfig.old({Object? enabledProvider, Object? ids}) {
    return NativeAdsConfig(
      enabled: _provider(enabledProvider) == 'admob',
      provider: _provider(enabledProvider),
      ids: _validAdMobIds(ids),
      insertEveryItems: AdsRemoteDefaults.nativeInsertEveryItems,
    ).validated();
  }

  final int insertEveryItems;

  NativeAdsConfig validated() {
    return NativeAdsConfig(
      enabled: enabled && supportsAdMob && ids.isNotEmpty,
      provider: provider,
      ids: ids,
      insertEveryItems: insertEveryItems,
    );
  }
}

class RewardedAdsConfig extends _AdsFormatConfig {
  const RewardedAdsConfig({
    required super.enabled,
    required super.provider,
    required super.ids,
  });

  const RewardedAdsConfig.disabled()
    : super(enabled: false, provider: 'admob', ids: const <String>[]);

  factory RewardedAdsConfig.fromJson(
    Map<String, Object?> json, {
    required bool globallyEnabled,
  }) {
    return RewardedAdsConfig(
      enabled: globallyEnabled && json['enabled'] == true,
      provider: _provider(json['provider']),
      ids: _validAdMobIds(json['ids']),
    ).validated();
  }

  factory RewardedAdsConfig.old({Object? enabledProvider, Object? ids}) {
    return RewardedAdsConfig(
      enabled: _provider(enabledProvider) == 'admob',
      provider: _provider(enabledProvider),
      ids: _validAdMobIds(ids),
    ).validated();
  }

  RewardedAdsConfig validated() {
    return RewardedAdsConfig(
      enabled: enabled && supportsAdMob && ids.isNotEmpty,
      provider: provider,
      ids: ids,
    );
  }
}

class _AdsFormatConfig {
  const _AdsFormatConfig({
    required this.enabled,
    required this.provider,
    required this.ids,
  });

  final bool enabled;
  final String provider;
  final List<String> ids;

  bool get supportsAdMob => provider == 'admob';
  String? get firstId => ids.isEmpty ? null : ids.first;
}

Map<String, Object?> _map(Object? value) {
  if (value is Map<String, Object?>) {
    return value;
  }
  if (value is Map<Object?, Object?>) {
    return value.map((Object? key, Object? value) {
      return MapEntry<String, Object?>(key.toString(), value);
    });
  }
  return const <String, Object?>{};
}

String _provider(Object? value) =>
    (value as String? ?? '').trim().toLowerCase();

int _intInRange(
  Object? value, {
  required int min,
  required int max,
  required int fallback,
}) {
  final int? parsed = value is int ? value : int.tryParse('$value');
  if (parsed == null || parsed < min || parsed > max) {
    return fallback;
  }
  return parsed;
}

List<String> _validAdMobIds(Object? value) {
  final Iterable<Object?> raw = switch (value) {
    String text => <Object?>[text],
    List<Object?> list => list,
    _ => const <Object?>[],
  };
  final Set<String> seen = <String>{};
  final List<String> ids = <String>[];
  for (final Object? item in raw) {
    final String id = (item as String? ?? '').trim();
    if (id.startsWith('ca-app-pub-') && seen.add(id)) {
      ids.add(id);
    }
  }
  return List<String>.unmodifiable(ids);
}
