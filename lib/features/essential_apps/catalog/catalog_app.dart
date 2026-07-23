import '../models/launcher_entry.dart';
import '../models/stable_id.dart';
import '../validation/launch_url_validator.dart';

class CatalogApp {
  const CatalogApp({
    required this.id,
    required this.name,
    required this.launchUrl,
    this.category,
  });

  final String id;
  final String name;
  final String launchUrl;
  final String? category;

  LauncherEntry toLauncherEntry() {
    return LauncherEntry(
      id: id,
      name: name,
      launchUrl: launchUrl,
      category: category,
    );
  }

  static CatalogApp? fromJson(Object? value) {
    if (value is! Map<String, Object?>) {
      return null;
    }

    final Object? name = value['name'];
    final Object? launchUrl = value['launchUrl'];
    final Object? category = value['category'];

    if (name is! String ||
        name.trim().isEmpty ||
        launchUrl is! String ||
        LaunchUrlValidator.validate(launchUrl) != null) {
      return null;
    }

    final String normalizedName = name.trim();
    final String normalizedUrl = LaunchUrlValidator.normalize(launchUrl);
    final String? normalizedCategory =
        category is String && category.trim().isNotEmpty
        ? category.trim()
        : null;

    return CatalogApp(
      id: StableId.fromParts(<String>[
        'catalog',
        normalizedName,
        normalizedUrl,
      ]),
      name: normalizedName,
      launchUrl: normalizedUrl,
      category: normalizedCategory,
    );
  }
}
