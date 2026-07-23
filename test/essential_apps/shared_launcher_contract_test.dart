import 'dart:convert';
import 'dart:io';

import 'package:stillscreen_focus_launcher/features/essential_apps/models/launcher_entry.dart';
import 'package:stillscreen_focus_launcher/features/essential_apps/shared/shared_launcher_contract.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('encodes stable field names and preserves ordering', () {
    final SharedLauncherContract contract =
        SharedLauncherContract.fromLauncherEntries(<LauncherEntry>[
          const LauncherEntry(id: 'one', name: 'Maps', launchUrl: 'maps:'),
          const LauncherEntry(id: 'two', name: 'Mail', launchUrl: 'mailto:'),
        ], updatedAt: DateTime.utc(2026, 7, 23));

    final Map<String, Object?> json =
        jsonDecode(contract.encode()) as Map<String, Object?>;
    final List<Object?> entries = json['entries']! as List<Object?>;

    expect(json.keys, <String>['schemaVersion', 'updatedAt', 'entries']);
    expect((entries.first! as Map<String, Object?>).keys, <String>[
      'id',
      'name',
      'launchUrl',
    ]);
    expect((entries.first! as Map<String, Object?>)['id'], 'one');
    expect((entries.last! as Map<String, Object?>)['id'], 'two');
  });

  test('decodes compatibility fixture', () {
    final String fixture = File(
      'test/fixtures/shared_launcher_data_v1.json',
    ).readAsStringSync();

    final SharedLauncherContract? contract = SharedLauncherContract.decode(
      fixture,
    );

    expect(contract, isNotNull);
    expect(
      contract!.entries.map((SharedLauncherEntry entry) => entry.id),
      <String>['entry-maps', 'entry-mail'],
    );
  });

  test('supports empty lists', () {
    final SharedLauncherContract contract =
        SharedLauncherContract.fromLauncherEntries(
          <LauncherEntry>[],
          updatedAt: DateTime.utc(2026, 7, 23),
        );

    expect(SharedLauncherContract.decode(contract.encode())!.entries, isEmpty);
  });

  test('filters invalid, duplicate, and oversized entries', () {
    final String oversizedName =
        'a' * (SharedLauncherContract.maximumNameLength + 1);
    final String rawJson = jsonEncode(<String, Object?>{
      'schemaVersion': 1,
      'updatedAt': '2026-07-23T00:00:00.000Z',
      'unknownField': true,
      'entries': <Object?>[
        <String, Object?>{'id': 'a', 'name': 'Maps', 'launchUrl': 'maps:'},
        <String, Object?>{'id': 'a', 'name': 'Duplicate', 'launchUrl': 'sms:'},
        <String, Object?>{'id': 'b', 'name': '', 'launchUrl': 'mailto:'},
        <String, Object?>{
          'id': 'c',
          'name': oversizedName,
          'launchUrl': 'mailto:',
        },
        <String, Object?>{
          'id': 'd',
          'name': 'Unsafe',
          'launchUrl': 'javascript:alert(1)',
        },
      ],
    });

    final SharedLauncherContract? contract = SharedLauncherContract.decode(
      rawJson,
    );

    expect(contract, isNotNull);
    expect(contract!.entries, hasLength(1));
    expect(contract.entries.single.id, 'a');
  });

  test(
    'rejects unsupported schema, missing fields, and invalid timestamps',
    () {
      expect(
        SharedLauncherContract.decode('{"schemaVersion":2,"entries":[]}'),
        isNull,
      );
      expect(
        SharedLauncherContract.decode('{"schemaVersion":1,"entries":[]}'),
        isNull,
      );
      expect(
        SharedLauncherContract.decode(
          '{"schemaVersion":1,"updatedAt":"bad","entries":[]}',
        ),
        isNull,
      );
    },
  );
}
