import 'package:shared_preferences/shared_preferences.dart';

import '../config/defaults.dart';

class AuthStorage {
  static const _baseUrl = 'api_base_url';
  static const _tenantSlug = 'tenant_slug';
  static const _clientId = 'client_id';
  static const _clientKey = 'client_key';
  static const _clientSecret = 'client_secret';
  static const _accessToken = 'access_token';
  static const _adminToken = 'admin_token';

  Future<void> saveConnection({
    required String baseUrl,
    required String tenantSlug,
    required String clientId,
    required String clientKey,
    required String clientSecret,
    required String accessToken,
    String? adminToken,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_baseUrl, baseUrl);
    await prefs.setString(_tenantSlug, tenantSlug);
    await prefs.setString(_clientId, clientId);
    await prefs.setString(_clientKey, clientKey);
    await prefs.setString(_clientSecret, clientSecret);
    await prefs.setString(_accessToken, accessToken);
    if (adminToken != null && adminToken.isNotEmpty) {
      await prefs.setString(_adminToken, adminToken);
    }
  }

  Future<Map<String, String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'baseUrl': prefs.getString(_baseUrl) ?? kDefaultApiBaseUrl,
      'tenantSlug': prefs.getString(_tenantSlug) ?? kDefaultTenantSlug,
      'clientId': prefs.getString(_clientId) ?? '',
      'clientKey': prefs.getString(_clientKey) ?? '',
      'clientSecret': prefs.getString(_clientSecret) ?? '',
      'accessToken': prefs.getString(_accessToken) ?? '',
      'adminToken': prefs.getString(_adminToken) ?? '',
    };
  }

  Future<bool> isConfigured() async {
    final data = await load();
    return data['accessToken']!.isNotEmpty && data['clientId']!.isNotEmpty;
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessToken);
  }
}
