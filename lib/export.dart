import 'dart:convert';

import 'domain.dart';

/// Encodes only user-created data so it can be backed up or imported later.
String encodeForExport(MendologData data) => jsonEncode({
  'format': 'mendolog-export',
  'version': 1,
  'exportedAt': DateTime.now().toUtc().toIso8601String(),
  'data': jsonDecode(data.encode()),
});
