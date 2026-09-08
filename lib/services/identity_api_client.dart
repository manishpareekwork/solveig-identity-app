import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../config/defaults.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.code});

  final String message;
  final int? statusCode;
  final String? code;

  @override
  String toString() => message;
}

class IdentityApiClient {
  IdentityApiClient({
    required this.baseUrl,
    this.tenantSlug = kDefaultTenantSlug,
    this.tenantId = '',
    required this.accessToken,
    this.clientId = '',
    this.clientKey = '',
    this.clientSecret = '',
    this.adminToken = '',
  });

  final String baseUrl;
  /// Slug sent when registering a tenant (admin only).
  final String tenantSlug;
  /// UUID for X-Tenant-Id on authenticated client calls.
  final String tenantId;
  final String accessToken;
  final String clientId;
  final String clientKey;
  final String clientSecret;
  final String adminToken;

  static const _uuid = Uuid();

  Uri _uri(String path) => Uri.parse('${baseUrl.replaceAll(RegExp(r'/+$'), '')}$path');

  Map<String, String> _headers({bool admin = false, String? correlationId}) {
    final token = admin ? adminToken : accessToken;
    final tenantHeader = tenantId.isNotEmpty ? tenantId : tenantSlug;
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
      if (!admin || tenantId.isNotEmpty) 'X-Tenant-Id': tenantHeader,
      'X-Correlation-Id': correlationId ?? _uuid.v4(),
    };
  }

  Future<Map<String, dynamic>> _decode(http.Response response) async {
    Map<String, dynamic>? body;
    if (response.body.isNotEmpty) {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    }
    if (response.statusCode >= 400) {
      final err = body?['error'] as Map<String, dynamic>?;
      throw ApiException(
        err?['message'] as String? ?? 'Request failed (${response.statusCode})',
        statusCode: response.statusCode,
        code: err?['code'] as String?,
      );
    }
    return body ?? {};
  }

  Future<Map<String, dynamic>> health() async {
    final res = await http.get(_uri('/health'));
    return _decode(res);
  }

  Future<Map<String, dynamic>> registerClient({
    required String displayName,
  }) async {
    final res = await http.post(
      _uri('/v1/clients'),
      headers: _headers(admin: true),
      body: jsonEncode({
        'tenant_slug': tenantSlug,
        'tenant_display_name': 'Demo Tenant',
        'display_name': displayName,
        'allowed_scopes': kRequiredScopes,
      }),
    );
    return _decode(res);
  }

  Future<Map<String, dynamic>> issueToken() async {
    final res = await http.post(
      _uri('/v1/clients/$clientId/tokens'),
      headers: _headers(),
      body: jsonEncode({
        'client_key': clientKey,
        'client_secret': clientSecret,
      }),
    );
    return _decode(res);
  }

  Future<Map<String, dynamic>> createIdentity() async {
    final res = await http.post(
      _uri('/v1/identities'),
      headers: {
        ..._headers(),
        'Idempotency-Key': _uuid.v4(),
      },
      body: jsonEncode({}),
    );
    return _decode(res);
  }

  Future<Map<String, dynamic>> getIdentity(String id) async {
    final res = await http.get(
      _uri('/v1/identities/$id'),
      headers: _headers(),
    );
    return _decode(res);
  }

  Future<Map<String, dynamic>> createConsent(String identityId) async {
    final res = await http.post(
      _uri('/v1/identities/$identityId/consents'),
      headers: _headers(),
      body: jsonEncode({
        'purpose': 'identity_verification',
        'purpose_version': '1.0',
        'granted': true,
      }),
    );
    return _decode(res);
  }

  Future<Map<String, dynamic>> enrollFace({
    required String identityId,
    required String imageBase64,
  }) async {
    final res = await http.post(
      _uri('/v1/face/enrollments'),
      headers: _headers(),
      body: jsonEncode({
        'identity_id': identityId,
        'image_base64': imageBase64,
      }),
    );
    return _decode(res);
  }

  Future<Map<String, dynamic>> issueQrReference(String identityId) async {
    final res = await http.post(
      _uri('/v1/qr/references'),
      headers: _headers(),
      body: jsonEncode({'identity_id': identityId}),
    );
    return _decode(res);
  }

  Future<Map<String, dynamic>> createVerificationSession(String identityId) async {
    final res = await http.post(
      _uri('/v1/verification-sessions'),
      headers: _headers(),
      body: jsonEncode({
        'identity_id': identityId,
        'required_checks': ['face_verification', 'liveness'],
      }),
    );
    return _decode(res);
  }

  Future<Map<String, dynamic>> submitFaceCheck({
    required String sessionId,
    required String imageBase64,
  }) async {
    final res = await http.post(
      _uri('/v1/verification-sessions/$sessionId/checks/face'),
      headers: _headers(),
      body: jsonEncode({'image_base64': imageBase64}),
    );
    return _decode(res);
  }

  Future<Map<String, dynamic>> submitLivenessCheck({
    required String sessionId,
    required String imageBase64,
  }) async {
    final res = await http.post(
      _uri('/v1/verification-sessions/$sessionId/checks/liveness'),
      headers: _headers(),
      body: jsonEncode({'image_base64': imageBase64}),
    );
    return _decode(res);
  }

  Future<Map<String, dynamic>> completeSession(String sessionId) async {
    final res = await http.post(
      _uri('/v1/verification-sessions/$sessionId/complete'),
      headers: _headers(),
      body: jsonEncode({'decision': 'approved'}),
    );
    return _decode(res);
  }

  Future<Map<String, dynamic>> getSession(String sessionId) async {
    final res = await http.get(
      _uri('/v1/verification-sessions/$sessionId'),
      headers: _headers(),
    );
    return _decode(res);
  }
}
