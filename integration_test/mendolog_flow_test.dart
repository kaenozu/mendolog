import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mendolog/main.dart';
import 'package:mendolog/domain.dart';
import 'package:mendolog/storage.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('user can record a friction event and see it in history', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = MendologStore(await SharedPreferences.getInstance());
    await tester.pumpWidget(MendologApp(store: store));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('探した'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '鍵');
    await tester.tap(find.text('記録する'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('履歴'));
    await tester.pumpAndSettle();
    expect(find.text('探した · 鍵'), findsOneWidget);
  });

  testWidgets('user can reach the improvement loop and delete a history item', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = MendologStore(await SharedPreferences.getInstance());
    await tester.pumpWidget(MendologApp(store: store));
    await tester.pumpAndSettle();

    Future<void> record(String target, {bool useRecent = false}) async {
      await tester.tap(find.textContaining('探した').first);
      await tester.pumpAndSettle();
      if (useRecent) {
        await tester.tap(find.text(target).first);
      } else {
        await tester.enterText(find.byType(TextField), target);
        await tester.tap(find.text('記録する'));
      }
      await tester.pumpAndSettle();
    }

    await record('爪切り');
    await record('爪切り');
    await record('爪切り');
    expect(store.load().events, hasLength(3));
    expect(
      store.load().events.map((event) => event.category),
      everyElement(FrictionCategory.searched),
    );
    expect(
      store.load().events.map((event) => event.canonicalTarget),
      everyElement('爪切り'),
    );
    expect(store.load().suggestions(DateTime.now()), hasLength(1));
    await tester.drag(find.byType(ListView).first, const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('改善する'), findsOneWidget);

    await tester.tap(find.text('改善する'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '洗面所の右側の引き出し');
    await tester.tap(find.text('改善を始める'));
    await tester.pumpAndSettle();
    expect(store.load().improvements, hasLength(1));
    expect(store.load().improvements.single.details, '洗面所の右側の引き出し');

    await tester.tap(find.text('集計'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).last, const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(find.textContaining('洗面所の右側の引き出し'), findsOneWidget);
    expect(find.textContaining('改善前'), findsOneWidget);

    await tester.tap(find.text('履歴'));
    await tester.pumpAndSettle();
    await tester.drag(find.text('探した · 爪切り').first, const Offset(-500, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('削除'));
    await tester.pumpAndSettle();
    expect(find.text('探した · 爪切り'), findsNWidgets(2));
  });
}
