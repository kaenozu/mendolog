import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mendolog/main.dart';
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
}
