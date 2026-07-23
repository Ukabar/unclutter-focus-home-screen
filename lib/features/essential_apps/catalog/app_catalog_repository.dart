import 'dart:convert';

import 'package:flutter/services.dart';

import '../validation/launch_url_validator.dart';
import 'catalog_app.dart';

class CatalogLoadResult {
  const CatalogLoadResult({required this.apps, this.warning});

  final List<CatalogApp> apps;
  final String? warning;
}

abstract interface class AppCatalogRepository {
  Future<CatalogLoadResult> loadCatalog();
}

class AssetAppCatalogRepository implements AppCatalogRepository {
  const AssetAppCatalogRepository();

  static const String _assetPath = 'assets/catalog/curated_apps.json';

  @override
  Future<CatalogLoadResult> loadCatalog() async {
    final String rawJson = await rootBundle.loadString(_assetPath);
    return parseCatalogJson(rawJson);
  }

  static CatalogLoadResult parseCatalogJson(String rawJson) {
    final Object? decoded;
    try {
      decoded = jsonDecode(rawJson);
    } on FormatException {
      return const CatalogLoadResult(
        apps: <CatalogApp>[],
        warning: 'Catalog data is malformed.',
      );
    }

    if (decoded is! List<Object?>) {
      return const CatalogLoadResult(
        apps: <CatalogApp>[],
        warning: 'Catalog data is not a list.',
      );
    }

    final List<CatalogApp> apps = <CatalogApp>[];
    final Set<String> seenLaunchUrls = <String>{};
    int skippedEntries = 0;

    for (final Object? item in decoded) {
      final CatalogApp? app = CatalogApp.fromJson(item);
      if (app == null) {
        skippedEntries++;
        continue;
      }

      final String duplicateKey = LaunchUrlValidator.duplicateKey(
        app.launchUrl,
      );
      if (seenLaunchUrls.contains(duplicateKey)) {
        skippedEntries++;
        continue;
      }

      seenLaunchUrls.add(duplicateKey);
      apps.add(app);
    }

    return CatalogLoadResult(
      apps: List<CatalogApp>.unmodifiable(apps),
      warning: skippedEntries == 0
          ? null
          : '$skippedEntries catalog entries were skipped.',
    );
  }
}
