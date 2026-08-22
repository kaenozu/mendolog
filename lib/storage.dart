import 'package:shared_preferences/shared_preferences.dart';

import 'domain.dart';

typedef MendologWriter = Future<bool> Function(String key, String value);

class MendologStore {
  static const _key = 'mendolog.data.v1';
  final SharedPreferences preferences;
  final MendologWriter _writer;

  MendologStore(this.preferences, {MendologWriter? writer})
    : _writer = writer ?? preferences.setString;

  MendologData load() {
    final value = preferences.getString(_key);
    return value == null ? const MendologData() : MendologData.decode(value);
  }

  Future<void> save(MendologData data) async {
    final saved = await _writer(_key, data.encode());
    if (!saved) {
      throw StateError('めんどログの保存に失敗しました。');
    }
  }
}
