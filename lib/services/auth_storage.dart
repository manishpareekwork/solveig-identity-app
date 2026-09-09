import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../config/defaults.dart';
import '../models/registered_profile.dart';

class AuthStorage {
  static const _baseUrl = 'api_base_url';
  static const _tenantSlug = 'tenant_slug';
  static const _clientId = 'client_id';
  static const _clientKey = 'client_key';
  static const _clientSecret = 'client_secret';
  static const _accessToken = 'access_token';
  static const _adminToken = 'admin_token';
  static const _tenantId = 'tenant_id';
  static const _profilesJson = 'registered_profiles_json';
  static const _regIdentityId = 'reg_identity_id';
  static const _regEnrollmentId = 'reg_enrollment_id';

  Future<void> saveConnection({
    required String baseUrl,
    required String tenantSlug,
    required String tenantId,
    required String clientId,
    required String clientKey,
    required String clientSecret,
    required String accessToken,
    String? adminToken,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_baseUrl, baseUrl);
    await prefs.setString(_tenantSlug, tenantSlug);
    await prefs.setString(_tenantId, tenantId);
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
      'tenantId': prefs.getString(_tenantId) ?? '',
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

  Future<List<RegisteredProfile>> loadRegisteredProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_profilesJson);
    if (raw != null && raw.isNotEmpty) {
      final list = (jsonDecode(raw) as List<dynamic>).cast<Map<String, dynamic>>();
      return list.map(RegisteredProfile.fromJson).toList();
    }
    return _migrateLegacyProfile(prefs);
  }

  Future<List<RegisteredProfile>> _migrateLegacyProfile(SharedPreferences prefs) async {
    final identityId = prefs.getString(_regIdentityId);
    final enrollmentId = prefs.getString(_regEnrollmentId);
    if (identityId == null || enrollmentId == null) return [];

    final profile = RegisteredProfile(
      localId: identityId,
      label: 'Profile 1',
      identityId: identityId,
      enrollmentId: enrollmentId,
      enrolledAt: DateTime.now(),
    );
    await saveRegisteredProfiles([profile]);
    await prefs.remove(_regIdentityId);
    await prefs.remove(_regEnrollmentId);
    return [profile];
  }

  Future<void> saveRegisteredProfiles(List<RegisteredProfile> profiles) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(profiles.map((p) => p.toJson()).toList());
    await prefs.setString(_profilesJson, encoded);
  }
}
