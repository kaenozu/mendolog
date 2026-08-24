import 'dart:convert';
import 'dart:math';

enum FrictionCategory {
  searched('探した', '🔍'),
  forgot('忘れた', '🧠'),
  redone('やり直した', '🔁'),
  waited('待った', '⏳'),
  troublesome('面倒だった', '🧱'),
  other('その他', '・');

  const FrictionCategory(this.label, this.emoji);
  final String label;
  final String emoji;
}

FrictionCategory categoryFromJson(String value) =>
    FrictionCategory.values.firstWhere(
      (category) => category.name == value,
      orElse: () => FrictionCategory.other,
    );

final Random _idRandom = Random.secure();

/// RFC 4122 version-4 style identifier. Unlike timestamp-derived ids, records
/// created in the same microsecond never collide.
String generateEventId() {
  final bytes = List<int>.generate(16, (_) => _idRandom.nextInt(0x100));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}'
      '-${hex.substring(12, 16)}-${hex.substring(16, 20)}'
      '-${hex.substring(20)}';
}

String canonicalizeTarget(String value) {
  final normalized = value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '');
  const aliases = {'つめきり': '爪切り', '爪きり': '爪切り', 'ネイルクリッパー': '爪切り'};
  return aliases[normalized] ?? value.trim().replaceAll(RegExp(r'\s+'), ' ');
}

class FrictionEvent {
  const FrictionEvent({
    required this.id,
    required this.category,
    required this.target,
    required this.occurredAt,
  });

  final String id;
  final FrictionCategory category;
  final String target;
  final DateTime occurredAt;

  String get canonicalTarget => canonicalizeTarget(target);

  Map<String, dynamic> toJson() => {
    'id': id,
    'category': category.name,
    'target': target,
    'occurredAt': occurredAt.toIso8601String(),
  };

  factory FrictionEvent.fromJson(Map<String, dynamic> json) => FrictionEvent(
    id: json['id'] as String,
    category: categoryFromJson(json['category'] as String),
    target: json['target'] as String,
    occurredAt: DateTime.parse(json['occurredAt'] as String),
  );
}

class Improvement {
  const Improvement({
    required this.category,
    required this.canonicalTarget,
    required this.title,
    this.details = '',
    required this.startedAt,
  });

  final FrictionCategory category;
  final String canonicalTarget;
  final String title;
  final String details;
  final DateTime startedAt;

  String get key => '${category.name}|$canonicalTarget';

  Map<String, dynamic> toJson() => {
    'category': category.name,
    'canonicalTarget': canonicalTarget,
    'title': title,
    'details': details,
    'startedAt': startedAt.toIso8601String(),
  };

  factory Improvement.fromJson(Map<String, dynamic> json) => Improvement(
    category: categoryFromJson(json['category'] as String),
    canonicalTarget: json['canonicalTarget'] as String,
    title: json['title'] as String,
    details: json['details'] as String? ?? '',
    startedAt: DateTime.parse(json['startedAt'] as String),
  );
}

class ImprovementSuggestion {
  const ImprovementSuggestion({
    required this.category,
    required this.canonicalTarget,
    required this.count,
    required this.title,
  });

  final FrictionCategory category;
  final String canonicalTarget;
  final int count;
  final String title;
}

class Comparison {
  const Comparison({required this.before, required this.after});
  final int before;
  final int after;
}

class MendologData {
  const MendologData({this.events = const [], this.improvements = const []});
  final List<FrictionEvent> events;
  final List<Improvement> improvements;

  List<String> get recentTargets {
    final recent = events.toList()
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    return recent
        .map((event) => event.canonicalTarget)
        .toSet()
        .take(8)
        .toList();
  }

  int count({
    required FrictionCategory category,
    required String target,
    required DateTime from,
    DateTime? to,
  }) {
    final canonical = canonicalizeTarget(target);
    return events.where((event) {
      final date = event.occurredAt;
      return event.category == category &&
          event.canonicalTarget == canonical &&
          !date.isBefore(from) &&
          (to == null || date.isBefore(to));
    }).length;
  }

  List<ImprovementSuggestion> suggestions(DateTime now) {
    final from = now.subtract(const Duration(days: 30));
    final keys = events
        .where(
          (event) =>
              !event.occurredAt.isBefore(from) &&
              !event.occurredAt.isAfter(now),
        )
        .map((event) => '${event.category.name}|${event.canonicalTarget}')
        .toSet();
    return keys
        .map((key) {
          final parts = key.split('|');
          final category = categoryFromJson(parts.first);
          final target = parts.skip(1).join('|');
          final improvementExists = improvements.any((item) => item.key == key);
          if (improvementExists) return null;
          final total = count(
            category: category,
            target: target,
            from: from,
            to: now.add(const Duration(microseconds: 1)),
          );
          if (total < 3) return null;
          return ImprovementSuggestion(
            category: category,
            canonicalTarget: target,
            count: total,
            title: category == FrictionCategory.searched
                ? '定位置を決める'
                : 'やり方を見直す',
          );
        })
        .whereType<ImprovementSuggestion>()
        .toList();
  }

  Comparison comparison(Improvement improvement, DateTime now) {
    final beforeStart = improvement.startedAt.subtract(
      const Duration(days: 30),
    );
    final afterEnd = improvement.startedAt.add(const Duration(days: 30));
    final effectiveAfterEnd = now.isBefore(afterEnd)
        ? now.add(const Duration(microseconds: 1))
        : afterEnd;
    return Comparison(
      before: count(
        category: improvement.category,
        target: improvement.canonicalTarget,
        from: beforeStart,
        to: improvement.startedAt,
      ),
      after: count(
        category: improvement.category,
        target: improvement.canonicalTarget,
        from: improvement.startedAt,
        to: effectiveAfterEnd,
      ),
    );
  }

  String encode() => jsonEncode({
    'events': events.map((event) => event.toJson()).toList(),
    'improvements': improvements.map((item) => item.toJson()).toList(),
  });

  factory MendologData.decode(String value) {
    final json = jsonDecode(value) as Map<String, dynamic>;
    return MendologData(
      events: (json['events'] as List<dynamic>? ?? [])
          .map((item) => FrictionEvent.fromJson(item as Map<String, dynamic>))
          .toList(),
      improvements: (json['improvements'] as List<dynamic>? ?? [])
          .map((item) => Improvement.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}
