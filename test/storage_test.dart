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
}
