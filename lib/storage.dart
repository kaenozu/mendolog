import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'domain.dart';

typedef MendologWriter = Future<bool> Function(String key, String value);

class MendologStore {
  static const _key = 'mendolog.data.v1';
  static const _quarantineKey = 'mendolog_payload_quarantine';
  static const int _currentSchemaVersion = 2;

  final SharedPreferences preferences;
  final MendologWriter _writer;

  bool _hasQuarantinedPayload = false;
  bool _isSavingBlocked = false;
  Future<void>? _quarantineWrite;

  MendologStore(this.preferences, {MendologWriter? writer})
    : _writer = writer ?? preferences.setString;

  /// 読み込めないペイロードを [_quarantineKey] へ退避済みかどうか。
  bool get hasQuarantinedPayload => _hasQuarantinedPayload;

  /// 退避が完了しておらず [save] で上書きできない状態かどうか。
  bool get isSavingBlocked => _isSavingBlocked;

  /// 進行中の退避書き込みの完了を待つ Future。
  Future<void>? get quarantineCompletion => _quarantineWrite;

  MendologData load() {
    final value = preferences.getString(_key);
    if (value == null) return const MendologData();

    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map<String, dynamic>) {
        return _rejectUnreadable(value);
      }

      final schemaVersion = decoded['schemaVersion'];
      if (schemaVersion == null) {
        // Legacy v1 payloads stored the MendologData JSON directly.
        return MendologData.decode(value);
      }
      if (schemaVersion != _currentSchemaVersion) {
        // Fail closed for future/unknown schemas after securing the original
        // so a newer app can still recover it.
        return _rejectUnreadable(value);
      }

      final data = decoded['data'];
      if (data is! Map<String, dynamic>) {
        return _rejectUnreadable(value);
      }
      return MendologData.decode(jsonEncode(data));
    } on Object {
      // A corrupt payload must not make startup fail and must not be replaced
      // automatically with an empty payload. Quarantining keeps it recoverable.
      return _rejectUnreadable(value);
    }
  }

  Future<void> save(MendologData data) async {
    if (_isSavingBlocked) {
      throw StateError('破損した旧データの退避が完了していないため保存を中断しました。');
    }
    final payload = jsonEncode({
      'schemaVersion': _currentSchemaVersion,
      'data': jsonDecode(data.encode()),
    });
    final saved = await _writer(_key, payload);
    if (!saved) {
      throw StateError('めんどログの保存に失敗しました。');
    }
  }

  MendologData _rejectUnreadable(String original) {
    _hasQuarantinedPayload = true;
    if (_quarantineWrite != null) return const MendologData();

    final secured = preferences.getString(_quarantineKey);
    if (secured == original) return const MendologData();
    if (secured != null) {
      // Keep the earlier backup intact and leave the current payload in place
      // by refusing further saves.
      _isSavingBlocked = true;
      return const MendologData();
    }

    _isSavingBlocked = true;
    _quarantineWrite = _writeQuarantine(original);
    return const MendologData();
  }

  Future<void> _writeQuarantine(String original) async {
    try {
      final saved = await _writer(_quarantineKey, original);
      if (!saved) {
        throw StateError('退避キーの書き込みが拒否されました。');
      }
      _isSavingBlocked = false;
    } on Object {
      // Fail closed: without a secured copy the original value must never be
      // overwritten by later saves.
      _isSavingBlocked = true;
    }
  }
}
