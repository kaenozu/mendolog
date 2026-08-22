import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'domain.dart';

typedef MendologWriter = Future<bool> Function(String key, String value);

class MendologStore {
  static const _key = 'mendolog.data.v1';
  static const int _currentSchemaVersion = 2;

  final SharedPreferences preferences;
  final MendologWriter _writer;

  MendologStore(this.preferences, {MendologWriter? writer})
    : _writer = writer ?? preferences.setString;

  MendologData load() {
    final value = preferences.getString(_key);
    if (value == null) return const MendologData();

    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map<String, dynamic>) {
        return const MendologData();
      }

      final schemaVersion = decoded['schemaVersion'];
      if (schemaVersion == null) {
        // Legacy v1 payloads stored the MendologData JSON directly.
        return MendologData.decode(value);
      }
      if (schemaVersion != _currentSchemaVersion) {
        // Fail closed for future/unknown schemas. The original preference is
        // deliberately left untouched so a newer app can still recover it.
        return const MendologData();
      }

      final data = decoded['data'];
      if (data is! Map<String, dynamic>) {
        return const MendologData();
      }
      return MendologData.decode(jsonEncode(data));
    } on Object {
      // A corrupt payload must not make startup fail and must not be replaced
      // automatically with an empty payload. Recovery remains possible from
      // the untouched value in SharedPreferences.
      return const MendologData();
    }
  }

  Future<void> save(MendologData data) async {
    final payload = jsonEncode({
      'schemaVersion': _currentSchemaVersion,
      'data': jsonDecode(data.encode()),
    });
    final saved = await _writer(_key, payload);
    if (!saved) {
      throw StateError('めんどログの保存に失敗しました。');
    }
  }
}
