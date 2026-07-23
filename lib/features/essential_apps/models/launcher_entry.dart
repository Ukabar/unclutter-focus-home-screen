import '../validation/launch_url_validator.dart';
import 'stable_id.dart';

class LauncherEntry {
  const LauncherEntry({
    required this.id,
    required this.name,
    required this.launchUrl,
    this.category,
  });

  final String id;
  final String name;
  final String launchUrl;
  final String? category;

  static LauncherEntry fromUserInput({
    required String name,
    required String launchUrl,
    String? category,
  }) {
    final String normalizedName = name.trim();
    final String normalizedUrl = LaunchUrlValidator.normalize(launchUrl);

    return LauncherEntry(
      id: StableId.fromParts(<String>[normalizedName, normalizedUrl]),
      name: normalizedName,
      launchUrl: normalizedUrl,
      category: _optionalText(category),
    );
  }

  LauncherEntry copyWith({String? name, String? launchUrl, String? category}) {
    return LauncherEntry(
      id: id,
      name: name ?? this.name,
      launchUrl: launchUrl ?? this.launchUrl,
      category: category ?? this.category,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'name': name,
      'launchUrl': launchUrl,
      if (category != null) 'category': category,
    };
  }

  static LauncherEntry? fromJson(Object? value) {
    if (value is! Map<String, Object?>) {
      return null;
    }

    final Object? id = value['id'];
    final Object? name = value['name'];
    final Object? launchUrl = value['launchUrl'];
    final Object? category = value['category'];

    if (id is! String ||
        id.trim().isEmpty ||
        name is! String ||
        name.trim().isEmpty ||
        launchUrl is! String ||
        LaunchUrlValidator.validate(launchUrl) != null) {
      return null;
    }

    return LauncherEntry(
      id: id.trim(),
      name: name.trim(),
      launchUrl: LaunchUrlValidator.normalize(launchUrl),
      category: category is String ? _optionalText(category) : null,
    );
  }

  static String? _optionalText(String? value) {
    final String? trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }

  @override
  bool operator ==(Object other) {
    return other is LauncherEntry &&
        other.id == id &&
        other.name == name &&
        other.launchUrl == launchUrl &&
        other.category == category;
  }

  @override
  int get hashCode => Object.hash(id, name, launchUrl, category);
}
