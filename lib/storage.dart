import 'package:shared_preferences/shared_preferences.dart';

import 'domain.dart';

class MendologStore {
  static const _key = 'mendolog.data.v1';
  final SharedPreferences preferences;

  MendologStore(this.preferences);

  MendologData load() {
    final value = preferences.getString(_key);
    return value == null ? const MendologData() : MendologData.decode(value);
  }

  Future<void> save(MendologData data) =>
      preferences.setString(_key, data.encode());
}
