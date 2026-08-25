import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mendolog/domain.dart';

void main() {
  final now = DateTime(2026, 8, 10, 12);

  FrictionEvent event(
    String target, {
    int daysAgo = 0,
    FrictionCategory category = FrictionCategory.searched,
    DateTime? at,
  }) => FrictionEvent(
    id: '$target-$daysAgo',
    category: category,
    target: target,
    occurredAt: at ?? now.subtract(Duration(days: daysAgo)),
  );

  test('canonicalizes common Japanese target spelling variants', () {
    expect(canonicalizeTarget('  つめきり '), '爪切り');

    // 全角ASCIIは半角へ寄せ、全角スペース/連続空白も正規化される。
    expect(canonicalizeTarget('ａｂｃ'), 'abc');
    expect(canonicalizeTarget('散歩　　'), '散歩');
    expect(canonicalizeTarget('abc　　def'), 'abc def');
    expect(canonicalizeTarget('ネイルクリッパー'), '爪切り');
    expect(canonicalizeTarget('  財布  '), '財布');
  });

  test('generates unique RFC 4122 style event ids', () {
    final ids = List.generate(10000, (_) => generateEventId());
    expect(ids.toSet().length, ids.length);
    final pattern = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    );
    for (final id in ids) {
      expect(pattern.hasMatch(id), isTrue, reason: id);
    }
  });

  test(
    'suggests improvement after three matching events in the last 30 days',
    () {
      final data = MendologData(
        events: [
          event('爪切り'),
          event('つめきり', daysAgo: 5),
          event('爪きり', daysAgo: 12),
        ],
      );
      final suggestions = data.suggestions(now);
      expect(suggestions.single.canonicalTarget, '爪切り');
      expect(suggestions.single.count, 3);
      expect(suggestions.single.title, '定位置を決める');
    },
  );

  test('does not count an event older than 30 days', () {
    final data = MendologData(
      events: [
        event('爪切り'),
        event('爪切り', daysAgo: 31),
        event('爪切り', daysAgo: 32),
      ],
    );
    expect(data.suggestions(now), isEmpty);
  });

  test('serializes timestamps as UTC and restores the same instant', () {
    final local = DateTime(2026, 8, 10, 21);
    final data = MendologData(
      events: [
        FrictionEvent(
          id: 'utc-1',
          category: FrictionCategory.searched,
          target: '爪切り',
          occurredAt: local.toUtc(),
        ),
      ],
    );

    final payload = data.encode();
    expect(
      payload.contains('"occurredAt":"${local.toUtc().toIso8601String()}'),
      isTrue,
    );

    final restored = MendologData.decode(payload);
    expect(restored.events.single.occurredAt.isUtc, isTrue);
    expect(
      restored.events.single.occurredAt.microsecondsSinceEpoch,
      local.microsecondsSinceEpoch,
    );
  });

  test('legacy offset-less timestamps keep their original instant', () {
    final restored = MendologData.decode(
      jsonEncode({
        'events': [
          {
            'id': 'legacy',
            'category': 'searched',
            'target': '爪切り',
            'occurredAt': '2026-08-10T21:00:00.000',
          },
        ],
        'improvements': [],
      }),
    );

    final expected = DateTime(2026, 8, 10, 21);
    expect(restored.events.single.occurredAt.isUtc, isTrue);
    expect(
      restored.events.single.occurredAt.microsecondsSinceEpoch,
      expected.toUtc().microsecondsSinceEpoch,
    );
  });

  test('30-day window edges are consistent across aggregation paths', () {
    final atFrom = now.subtract(const Duration(days: 30));
    final atNow = now;
    final future = now.add(const Duration(days: 1));
    FrictionEvent at(DateTime at) => FrictionEvent(
      id: '$at',
      category: FrictionCategory.searched,
      target: '爪切り',
      occurredAt: at,
    );

    final edgeData = MendologData(events: [at(atFrom)]);
    expect(
      edgeData.recentCount(category: FrictionCategory.searched, now: now),
      1,
    );
    expect(edgeData.suggestions(now), isEmpty);

    final nowData = MendologData(events: [at(atNow)]);
    expect(
      nowData.recentCount(category: FrictionCategory.searched, now: now),
      1,
    );

    final futureData = MendologData(events: [at(future)]);
    expect(
      futureData.recentCount(category: FrictionCategory.searched, now: now),
      0,
    );
    expect(futureData.suggestions(now), isEmpty);
  });

  test(
    'comparison counts the 30 days before and after improvement separately',
    () {
      final startedAt = now.subtract(const Duration(days: 10));
      final improvement = Improvement(
        category: FrictionCategory.searched,
        canonicalTarget: '爪切り',
        title: '定位置を決める',
        startedAt: startedAt,
      );
      final data = MendologData(
        events: [
          event('爪切り', at: startedAt.subtract(const Duration(days: 1))),
          event('爪切り', at: startedAt.subtract(const Duration(days: 2))),
          event('爪切り', at: startedAt.subtract(const Duration(days: 3))),
          event('爪切り', at: startedAt.add(const Duration(days: 1))),
        ],
        improvements: [improvement],
      );
      final comparison = data.comparison(improvement, now);
      expect(comparison.before, 3);
      expect(comparison.after, 1);
      expect(comparison.observedAfterDays, 10);
      expect(comparison.isComplete, isFalse);
    },
  );

  test(
    'marks comparison complete only after a full 30-day observation window',
    () {
      final startedAt = now.subtract(const Duration(days: 30));
      final improvement = Improvement(
        category: FrictionCategory.searched,
        canonicalTarget: '爪切り',
        title: '定位置を決める',
        startedAt: startedAt,
      );
      final comparison = MendologData().comparison(improvement, now);

      expect(comparison.observedAfterDays, 30);
      expect(comparison.isComplete, isTrue);
    },
  );

  test('does not repeat a suggestion after improvement is started', () {
    final data = MendologData(
      events: [
        event('爪切り'),
        event('爪切り', daysAgo: 5),
        event('爪切り', daysAgo: 12),
      ],
      improvements: [
        Improvement(
          category: FrictionCategory.searched,
          canonicalTarget: '爪切り',
          title: '定位置を決める',
          startedAt: now,
        ),
      ],
    );
    expect(data.suggestions(now), isEmpty);
  });

  test('round trips improvement details through local JSON storage', () {
    final improvement = Improvement(
      category: FrictionCategory.searched,
      canonicalTarget: '爪切り',
      title: '定位置を決める',
      details: '洗面所の右側の引き出し',
      startedAt: now,
    );
    final restored = MendologData.decode(
      MendologData(improvements: [improvement]).encode(),
    );
    expect(restored.improvements.single.details, '洗面所の右側の引き出し');
  });
}
