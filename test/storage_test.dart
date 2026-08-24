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

  Future<void> drainEvents(int turns) async {
    for (var i = 0; i < turns; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  test('corrupt payload is quarantined before saving resumes', () async {
    const corrupt = '{not-json';
    SharedPreferences.setMockInitialValues({'mendolog.data.v1': corrupt});
    final preferences = await SharedPreferences.getInstance();
    final store = MendologStore(preferences);

    expect(store.load().events, isEmpty);
    expect(store.hasQuarantinedPayload, isTrue);
    expect(store.isSavingBlocked, isTrue);

    await drainEvents(10);

    expect(store.isSavingBlocked, isFalse);
    expect(
      preferences.getString('mendolog_payload_quarantine'),
      corrupt,
    );
    expect(preferences.getString('mendolog.data.v1'), corrupt);

    await store.save(const MendologData());
    final migrated = jsonDecode(preferences.getString('mendolog.data.v1')!);
    expect(migrated['schemaVersion'], 2);
    expect(preferences.getString('mendolog_payload_quarantine'), corrupt);
  });

  test('failed quarantine keeps blocking saves on the original payload', () async {
    const corrupt =
        '{"schemaVersion":2,"data":{"events":"broken","improvements":[]}}';
    SharedPreferences.setMockInitialValues({'mendolog.data.v1': corrupt});
    final preferences = await SharedPreferences.getInstance();
    var quarantineAttempts = 0;
    final store = MendologStore(
      preferences,
      writer: (_, _) async {
        quarantineAttempts++;
        return false;
      },
    );

    store.load();
    await drainEvents(10);

    expect(store.hasQuarantinedPayload, isTrue);
    expect(store.isSavingBlocked, isTrue);
    expect(quarantineAttempts, 1);
    await expectLater(
      store.save(const MendologData()),
      throwsA(isA<StateError>()),
    );
    expect(preferences.getString('mendolog.data.v1'), corrupt);
  });

  test('an already quarantined identical payload unblocks saving', () async {
    const corrupt = '{not-json';
    SharedPreferences.setMockInitialValues({
      'mendolog.data.v1': corrupt,
      'mendolog_payload_quarantine': corrupt,
    });
    final preferences = await SharedPreferences.getInstance();
    final store = MendologStore(preferences);

    expect(store.load().events, isEmpty);
    expect(store.hasQuarantinedPayload, isTrue);
    expect(store.isSavingBlocked, isFalse);

    await store.save(const MendologData());
    final migrated = jsonDecode(preferences.getString('mendolog.data.v1')!);
    expect(migrated['schemaVersion'], 2);
  });

  test('a different pre-existing quarantine copy keeps saving blocked', () async {
    const corrupt = '{not-json';
    SharedPreferences.setMockInitialValues({
      'mendolog.data.v1': corrupt,
      'mendolog_payload_quarantine': 'older-incident-backup',
    });
    final preferences = await SharedPreferences.getInstance();
    final store = MendologStore(preferences);

    expect(store.load().events, isEmpty);
    expect(store.isSavingBlocked, isTrue);
    expect(preferences.getString('mendolog_payload_quarantine'), 'older-incident-backup');
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
