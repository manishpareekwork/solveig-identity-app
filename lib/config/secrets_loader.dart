import 'dart:convert';

import 'package:flutter/services.dart';

import 'defaults.dart';

class AppSecrets {
  const AppSecrets({
    this.adminToken = '',
    this.clientId = '',
    this.clientKey = '',
    this.clientSecret = '',
  });

  final String adminToken;
  final String clientId;
  final String clientKey;
  final String clientSecret;

  bool get hasAdminToken => _isUsable(adminToken);
  bool get hasClientCredentials =>
      _isUsable(clientId) && _isUsable(clientKey) && _isUsable(clientSecret);

  static bool _isUsable(String value) {
    final v = value.trim();
    if (v.isEmpty) return false;
    const placeholders = {
      'optional',
      'optional-if-already-registered',
      'paste-from-render-dashboard',
    };
    return !placeholders.contains(v.toLowerCase());
  }

  static Future<AppSecrets> load() async {
    var admin = kDevAdminToken;
    var clientId = kDevClientId;
    var clientKey = kDevClientKey;
    var clientSecret = kDevClientSecret;

    try {
      final raw = await rootBundle.loadString('secrets.json');
      final json = jsonDecode(raw) as Map<String, dynamic>;
      admin = _pick(json, 'IDENTITY_ADMIN_TOKEN', admin);
      clientId = _pick(json, 'SOLVEIG_CLIENT_ID', clientId);
      clientKey = _pick(json, 'SOLVEIG_CLIENT_KEY', clientKey);
      clientSecret = _pick(json, 'SOLVEIG_CLIENT_SECRET', clientSecret);
    } catch (_) {
      // Asset optional when using dart-define only.
    }

    return AppSecrets(
      adminToken: admin,
      clientId: clientId,
      clientKey: clientKey,
      clientSecret: clientSecret,
    );
  }

  static String _pick(Map<String, dynamic> json, String key, String fallback) {
    final value = json[key];
    if (value is! String) return fallback;
    return value.trim().isEmpty ? fallback : value.trim();
  }
}
