import 'dart:convert';

import '../models/launcher_entry.dart';
import '../validation/launch_url_validator.dart';

class SharedLauncherContract {
  const SharedLauncherContract({
    required this.updatedAt,
    required this.entries,
  });

  static const int schemaVersion = 1;
  static const int maximumEntries = 24;
  static const int maximumNameLength = 60;
  static const int maximumLaunchUrlLength = 512;

  final DateTime updatedAt;
  final List<SharedLauncherEntry> entries;

  factory SharedLauncherContract.fromLauncherEntries(
    List<LauncherEntry> entries, {
    DateTime? updatedAt,
  }) {
    return SharedLauncherContract(
      updatedAt: updatedAt ?? DateTime.now().toUtc(),
      entries: _sanitizeEntries(
        entries
            .map(SharedLauncherEntry.fromLauncherEntry)
            .whereType<SharedLauncherEntry>(),
      ),
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'schemaVersion': schemaVersion,
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      'entries': entries
          .map((SharedLauncherEntry entry) => entry.toJson())
          .toList(),
    };
  }

  String encode() => jsonEncode(toJson());

  static SharedLauncherContract? decode(String rawJson) {
    final Object? decoded;
    try {
      decoded = jsonDecode(rawJson);
    } on FormatException {
      return null;
    }

    if (decoded is! Map<String, Object?> ||
        decoded['schemaVersion'] != schemaVersion) {
      return null;
    }

    final Object? updatedAtValue = decoded['updatedAt'];
    final DateTime? updatedAt = updatedAtValue is String
        ? DateTime.tryParse(updatedAtValue)?.toUtc()
        : null;
    final Object? entriesValue = decoded['entries'];

    if (updatedAt == null || entriesValue is! List<Object?>) {
      return null;
    }

    return SharedLauncherContract(
      updatedAt: updatedAt,
      entries: _sanitizeEntries(
        entriesValue
            .map(SharedLauncherEntry.fromJson)
            .whereType<SharedLauncherEntry>(),
      ),
    );
  }

  static List<SharedLauncherEntry> _sanitizeEntries(
    Iterable<SharedLauncherEntry> entries,
  ) {
    final List<SharedLauncherEntry> sanitizedEntries = <SharedLauncherEntry>[];
    final Set<String> seenIds = <String>{};

    for (final SharedLauncherEntry entry in entries) {
      if (sanitizedEntries.length >= maximumEntries ||
          seenIds.contains(entry.id)) {
        continue;
      }

      seenIds.add(entry.id);
      sanitizedEntries.add(entry);
    }

    return List<SharedLauncherEntry>.unmodifiable(sanitizedEntries);
  }
}

class SharedLauncherEntry {
  const SharedLauncherEntry({
    required this.id,
    required this.name,
    required this.launchUrl,
  });

  final String id;
  final String name;
  final String launchUrl;

  static SharedLauncherEntry? fromLauncherEntry(LauncherEntry entry) {
    return fromFields(
      id: entry.id,
      name: entry.name,
      launchUrl: entry.launchUrl,
    );
  }

  static SharedLauncherEntry? fromJson(Object? value) {
    if (value is! Map<String, Object?>) {
      return null;
    }

    final Object? id = value['id'];
    final Object? name = value['name'];
    final Object? launchUrl = value['launchUrl'];

    if (id is! String || name is! String || launchUrl is! String) {
      return null;
    }

    return fromFields(id: id, name: name, launchUrl: launchUrl);
  }

  static SharedLauncherEntry? fromFields({
    required String id,
    required String name,
    required String launchUrl,
  }) {
    final String normalizedId = id.trim();
    final String normalizedName = name.trim();
    final String normalizedUrl = LaunchUrlValidator.normalize(launchUrl);

    if (normalizedId.isEmpty ||
        normalizedName.isEmpty ||
        normalizedName.length > SharedLauncherContract.maximumNameLength ||
        normalizedUrl.length > SharedLauncherContract.maximumLaunchUrlLength ||
        LaunchUrlValidator.validate(normalizedUrl) != null) {
      return null;
    }

    return SharedLauncherEntry(
      id: normalizedId,
      name: normalizedName,
      launchUrl: normalizedUrl,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{'id': id, 'name': name, 'launchUrl': launchUrl};
  }

  @override
  bool operator ==(Object other) {
    return other is SharedLauncherEntry &&
        other.id == id &&
        other.name == name &&
        other.launchUrl == launchUrl;
  }

  @override
  int get hashCode => Object.hash(id, name, launchUrl);
}
