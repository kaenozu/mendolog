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
    expect(store.recoveryRequired, isFalse);

    await store.save(loaded);
    final migrated = jsonDecode(preferences.getString('mendolog.data.v1')!);
    expect(migrated['schemaVersion'], 2);
    expect(migrated['data']['events'].single['id'], 'legacy-1');
  });

  test('malformed JSON is protected and subsequent save is blocked', () async {
    const corrupt = '{not-json';
    SharedPreferences.setMockInitialValues({'mendolog.data.v1': corrupt});
    final preferences = await SharedPreferences.getInstance();
    final store = MendologStore(preferences);

    final loaded = store.load();

    expect(loaded.events, isEmpty);
    expect(loaded.improvements, isEmpty);
    expect(store.recoveryRequired, isTrue);
    expect(preferences.getString('mendolog.data.v1'), corrupt);

    await expectLater(
      store.save(const MendologData()),
      throwsA(isA<StateError>()),
    );
    expect(preferences.getString('mendolog.data.v1'), corrupt);
    expect(preferences.getString('mendolog.data.recovery.v1'), corrupt);
  });

  test('invalid typed or date data is protected and blocks writes', () async {
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
    expect(store.recoveryRequired, isTrue);

    await expectLater(
      store.save(const MendologData()),
      throwsA(isA<StateError>()),
    );
    expect(preferences.getString('mendolog.data.v1'), invalid);
    expect(preferences.getString('mendolog.data.recovery.v1'), invalid);
  });

  test('unknown future schema is rejected, backed up, and write-blocked', () async {
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
    expect(store.recoveryRequired, isTrue);

    await expectLater(
      store.save(const MendologData()),
      throwsA(isA<StateError>()),
    );
    expect(preferences.getString('mendolog.data.v1'), future);
    expect(preferences.getString('mendolog.data.recovery.v1'), future);
  });

  test('valid current payload clears recovery-required state', () async {
    final valid = jsonEncode({
      'schemaVersion': 2,
      'data': {'events': [], 'improvements': []},
    });
    SharedPreferences.setMockInitialValues({'mendolog.data.v1': valid});
    final store = MendologStore(await SharedPreferences.getInstance());

    expect(store.load().events, isEmpty);
    expect(store.recoveryRequired, isFalse);
  });
}
