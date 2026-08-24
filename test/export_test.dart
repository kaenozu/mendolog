import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mendolog/domain.dart';
import 'package:mendolog/export.dart';

void main() {
  test('export contains a stable format envelope and all user data', () {
    final event = FrictionEvent(
      id: 'event-1',
      category: FrictionCategory.searched,
      target: '鍵',
      occurredAt: DateTime.utc(2026, 1, 2, 3, 4),
    );

    final exported =
        jsonDecode(encodeForExport(MendologData(events: [event])))
            as Map<String, dynamic>;

    expect(exported['format'], 'mendolog-export');
    expect(exported['version'], 1);
    expect(DateTime.tryParse(exported['exportedAt'] as String), isNotNull);
    expect((exported['data'] as Map<String, dynamic>)['events'], hasLength(1));
    expect(
      ((exported['data'] as Map<String, dynamic>)['events'] as List)
          .single['id'],
      'event-1',
    );
  });
}
