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
    expect(canonicalizeTarget('ネイルクリッパー'), '爪切り');
    expect(canonicalizeTarget('  財布  '), '財布');
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
