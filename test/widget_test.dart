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
    expect(find.textContaining('繰り返す面倒を記録すると'), findsOneWidget);
    expect(find.textContaining('改善候補が見えてきます'), findsOneWidget);

    await tester.tap(find.textContaining('探した'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '爪切り');
    await tester.tap(find.text('記録する'));
    await tester.pumpAndSettle();

    expect(store.load().events.single.canonicalTarget, '爪切り');
  });

  testWidgets('does not show a successful mutation when persistence fails', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final store = MendologStore(
      preferences,
      writer: (_, _) async => false,
    );

    await tester.pumpWidget(MendologApp(store: store));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('探した'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '鍵');
    await tester.tap(find.text('記録する'));
    await tester.pumpAndSettle();

    expect(store.load().events, isEmpty);
    expect(find.textContaining('保存できませんでした'), findsOneWidget);

    await tester.tap(find.text('履歴'));
    await tester.pumpAndSettle();
    expect(find.textContaining('まだ記録がありません'), findsOneWidget);
  });

  testWidgets('keeps bottom actions clear of Android navigation insets', (
    tester,
  ) async {
    tester.view.padding = FakeViewPadding(bottom: 24);
    addTearDown(tester.view.resetPadding);
    SharedPreferences.setMockInitialValues({});
    final store = MendologStore(await SharedPreferences.getInstance());

    await tester.pumpWidget(MendologApp(store: store));
    await tester.pumpAndSettle();

    final list = tester.widget<ListView>(find.byType(ListView).first);
    expect((list.padding! as EdgeInsets).bottom, greaterThan(24));
    expect(
      find.ancestor(
        of: find.byType(NavigationBar),
        matching: find.byType(SafeArea),
      ),
      findsOneWidget,
    );
  });
}
