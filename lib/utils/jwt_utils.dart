import 'dart:convert';

/// Reads `tid` from a Solveig client access JWT (no signature verify — local use only).
String? tenantIdFromAccessToken(String token) {
  final parts = token.split('.');
  if (parts.length != 3) return null;
  try {
    var payload = parts[1];
    payload = base64Url.normalize(payload);
    final decoded = utf8.decode(base64Url.decode(payload));
    final json = jsonDecode(decoded) as Map<String, dynamic>;
    final tid = json['tid'];
    return tid is String && tid.isNotEmpty ? tid : null;
  } catch (_) {
    return null;
  }
}
