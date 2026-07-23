import 'package:stillscreen_focus_launcher/features/essential_apps/catalog/app_catalog_repository.dart';
import 'package:stillscreen_focus_launcher/features/essential_apps/models/launcher_entry.dart';
import 'package:stillscreen_focus_launcher/features/essential_apps/validation/launch_url_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('launcher entry serializes deterministically and supports equality', () {
    final LauncherEntry entry = LauncherEntry.fromUserInput(
      name: ' Maps ',
      launchUrl: ' maps: ',
      category: 'Navigation',
    );
    final LauncherEntry sameEntry = LauncherEntry.fromJson(entry.toJson())!;

    expect(entry, sameEntry);
    expect(entry.toJson(), <String, Object?>{
      'id': entry.id,
      'name': 'Maps',
      'launchUrl': 'maps:',
      'category': 'Navigation',
    });
  });

  test('catalog parsing skips invalid entries without crashing', () {
    const String rawJson = '''
[
  {"name":"Maps","launchUrl":"maps:","category":"Navigation"},
  {"name":"","launchUrl":"sms:"},
  {"name":"Unsafe","launchUrl":"javascript:alert(1)"},
  {"name":"Maps duplicate","launchUrl":"maps:"}
]
''';

    final CatalogLoadResult result = AssetAppCatalogRepository.parseCatalogJson(
      rawJson,
    );

    expect(result.apps, hasLength(1));
    expect(result.apps.single.name, 'Maps');
    expect(result.warning, '3 catalog entries were skipped.');
  });

  test('catalog parsing handles a malformed root safely', () {
    final CatalogLoadResult result = AssetAppCatalogRepository.parseCatalogJson(
      '{"name":"Maps"}',
    );

    expect(result.apps, isEmpty);
    expect(result.warning, isNotNull);
  });

  test('catalog parsing handles malformed JSON safely', () {
    final CatalogLoadResult result = AssetAppCatalogRepository.parseCatalogJson(
      'not json',
    );

    expect(result.apps, isEmpty);
    expect(result.warning, 'Catalog data is malformed.');
  });

  test('URL validation allows custom schemes and rejects unsafe URLs', () {
    expect(LaunchUrlValidator.validate('maps:'), isNull);
    expect(LaunchUrlValidator.validate('myapp://open'), isNull);
    expect(LaunchUrlValidator.validate('https://example.com'), isNull);

    expect(LaunchUrlValidator.validate(''), isNotNull);
    expect(LaunchUrlValidator.validate('example.com'), isNotNull);
    expect(LaunchUrlValidator.validate('https://'), isNotNull);
    expect(LaunchUrlValidator.validate('javascript:alert(1)'), isNotNull);
    expect(LaunchUrlValidator.validate('data:text/plain,hello'), isNotNull);
  });
}
