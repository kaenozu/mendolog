import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mendolog/main.dart';
import 'package:mendolog/storage.dart';

void main() {
  testWidgets('shows six quick logging categories and records a target', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = MendologStore(await SharedPreferences.getInstance());
    await tester.pumpWidget(MendologApp(store: store));
    await tester.pumpAndSettle();

    expect(find.textContaining('探した'), findsOneWidget);
    expect(find.textContaining('忘れた'), findsOneWidget);
    expect(find.textContaining('やり直した'), findsOneWidget);
    expect(find.textContaining('待った'), findsOneWidget);
    expect(find.textContaining('面倒だった'), findsOneWidget);
    expect(find.textContaining('その他'), findsOneWidget);

    await tester.tap(find.textContaining('探した'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '爪切り');
    await tester.tap(find.text('記録する'));
    await tester.pumpAndSettle();

    expect(store.load().events.single.canonicalTarget, '爪切り');
  });
}
