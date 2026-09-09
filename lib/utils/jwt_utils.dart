import 'dart:convert';

Map<String, dynamic>? _accessTokenPayload(String token) {
  final parts = token.split('.');
  if (parts.length != 3) return null;
  try {
    var payload = parts[1];
    payload = base64Url.normalize(payload);
    final decoded = utf8.decode(base64Url.decode(payload));
    return jsonDecode(decoded) as Map<String, dynamic>;
  } catch (_) {
    return null;
  }
}

/// Reads `tid` from a Solveig client access JWT (no signature verify — local use only).
String? tenantIdFromAccessToken(String token) {
  final json = _accessTokenPayload(token);
  if (json == null) return null;
  final tid = json['tid'];
  return tid is String && tid.isNotEmpty ? tid : null;
}

/// True when JWT is missing, unreadable, or within [leeway] of expiry.
bool isAccessTokenExpired(
  String token, {
  Duration leeway = const Duration(minutes: 2),
}) {
  if (token.trim().isEmpty) return true;
  final json = _accessTokenPayload(token);
  if (json == null) return true;
  final exp = json['exp'];
  if (exp is! num) return true;
  final expiresAt = DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000, isUtc: true);
  return DateTime.now().toUtc().add(leeway).isAfter(expiresAt);
}
