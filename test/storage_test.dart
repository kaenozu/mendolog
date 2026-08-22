import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mendolog/domain.dart';
import 'package:mendolog/storage.dart';

void main() {
  test('save throws when SharedPreferences-style writer returns false', () async {
    SharedPreferences.setMockInitialValues({});
    final store = MendologStore(
      await SharedPreferences.getInstance(),
      writer: (_, _) async => false,
    );

    await expectLater(
      store.save(const MendologData()),
      throwsA(isA<StateError>()),
    );
  });

  test('save propagates writer exceptions', () async {
    SharedPreferences.setMockInitialValues({});
    final store = MendologStore(
      await SharedPreferences.getInstance(),
      writer: (_, _) async => throw Exception('disk failure'),
    );

    await expectLater(
      store.save(const MendologData()),
      throwsA(isA<Exception>()),
    );
  });

  test('legacy unversioned payload loads and next save migrates it', () async {
    final legacy = MendologData(
      events: [
        FrictionEvent(
          id: 'legacy-1',
          category: FrictionCategory.searched,
          target: '鍵',
          occurredAt: DateTime.utc(2026, 8, 20, 1),
        ),
      ],
    ).encode();
    SharedPreferences.setMockInitialValues({'mendolog.data.v1': legacy});
    final preferences = await SharedPreferences.getInstance();
    final store = MendologStore(preferences);

    final loaded = store.load();
    expect(loaded.events.single.id, 'legacy-1');

    await store.save(loaded);
    final migrated = jsonDecode(preferences.getString('mendolog.data.v1')!);
    expect(migrated['schemaVersion'], 2);
    expect(migrated['data']['events'].single['id'], 'legacy-1');
  });

  test('malformed JSON does not crash or overwrite original payload', () async {
    const corrupt = '{not-json';
    SharedPreferences.setMockInitialValues({'mendolog.data.v1': corrupt});
    final preferences = await SharedPreferences.getInstance();
    final store = MendologStore(preferences);

    final loaded = store.load();

    expect(loaded.events, isEmpty);
    expect(loaded.improvements, isEmpty);
    expect(preferences.getString('mendolog.data.v1'), corrupt);
  });

  test('invalid typed or date data fails closed without mutation', () async {
    final invalid = jsonEncode({
      'schemaVersion': 2,
      'data': {
        'events': [
          {
            'id': 123,
            'category': 'searched',
            'target': '鍵',
            'occurredAt': 'not-a-date',
          },
        ],
        'improvements': [],
      },
    });
    SharedPreferences.setMockInitialValues({'mendolog.data.v1': invalid});
    final preferences = await SharedPreferences.getInstance();
    final store = MendologStore(preferences);

    expect(store.load().events, isEmpty);
    expect(preferences.getString('mendolog.data.v1'), invalid);
  });

  test('unknown future schema is rejected and preserved', () async {
    final future = jsonEncode({
      'schemaVersion': 999,
      'data': {'events': [], 'improvements': []},
    });
    SharedPreferences.setMockInitialValues({'mendolog.data.v1': future});
    final preferences = await SharedPreferences.getInstance();
    final store = MendologStore(preferences);

    final loaded = store.load();

    expect(loaded.events, isEmpty);
    expect(loaded.improvements, isEmpty);
    expect(preferences.getString('mendolog.data.v1'), future);
  });
}
