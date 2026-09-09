import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../config/defaults.dart';

class ApiException implements Exception {
  ApiException(
    this.message, {
    this.statusCode,
    this.code,
    this.endpoint,
    this.correlationId,
    this.rawBody,
    this.retryable,
  });

  final String message;
  final int? statusCode;
  final String? code;
  final String? endpoint;
  final String? correlationId;
  final String? rawBody;
  final bool? retryable;

  String get fullLog {
    final buf = StringBuffer()
      ..writeln('endpoint: ${endpoint ?? 'unknown'}')
      ..writeln('http_status: ${statusCode ?? 'unknown'}')
      ..writeln('error_code: ${code ?? 'unknown'}')
      ..writeln('correlation_id: ${correlationId ?? 'unknown'}')
      ..writeln('retryable: ${retryable ?? false}')
      ..writeln('message: $message');
    if (rawBody != null && rawBody!.isNotEmpty) {
      buf.writeln('response_body:');
      buf.writeln(rawBody);
    }
    return buf.toString().trim();
  }

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
  final String tenantSlug;
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

  Future<Map<String, dynamic>> _get(String path, {bool admin = false}) async {
    final corr = _uuid.v4();
    final res = await http.get(_uri(path), headers: _headers(admin: admin, correlationId: corr));
    return _decode(res, method: 'GET', path: path, correlationId: corr);
  }

  Future<Map<String, dynamic>> _post(
    String path, {
    Map<String, String>? extraHeaders,
    Object? body,
    bool admin = false,
  }) async {
    final corr = _uuid.v4();
    final headers = {..._headers(admin: admin, correlationId: corr), ...?extraHeaders};
    final res = await http.post(
      _uri(path),
      headers: headers,
      body: body == null ? null : jsonEncode(body),
    );
    return _decode(res, method: 'POST', path: path, correlationId: corr);
  }

  Never _throwApi({
    required String method,
    required String path,
    required String correlationId,
    required int statusCode,
    required String message,
    String? code,
    String? rawBody,
    bool? retryable,
  }) {
    final exc = ApiException(
      message,
      statusCode: statusCode,
      code: code,
      endpoint: '$method $path',
      correlationId: correlationId,
      rawBody: _trimBody(rawBody),
      retryable: retryable,
    );
    if (kDebugMode) {
      debugPrint('=== In-house API error ===\n${exc.fullLog}');
    }
    throw exc;
  }

  String? _trimBody(String? body) {
    if (body == null || body.isEmpty) return body;
    const max = 4000;
    return body.length <= max ? body : '${body.substring(0, max)}\n…(truncated)';
  }

  Future<Map<String, dynamic>> _decode(
    http.Response response, {
    required String method,
    required String path,
    required String correlationId,
  }) async {
    final responseCorr = response.headers['x-correlation-id'] ?? correlationId;
    Map<String, dynamic>? body;
    if (response.body.isNotEmpty) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          body = decoded;
        }
      } catch (_) {
        _throwApi(
          method: method,
          path: path,
          correlationId: responseCorr,
          statusCode: response.statusCode,
          code: response.statusCode >= 500 ? 'SERVER_ERROR' : 'INVALID_RESPONSE',
          message: response.statusCode >= 500
              ? 'Server returned non-JSON error (HTTP ${response.statusCode})'
              : 'Unexpected response from API (HTTP ${response.statusCode})',
          rawBody: response.body,
        );
      }
    }
    if (response.statusCode >= 400) {
      final err = body?['error'] as Map<String, dynamic>?;
      final code = err?['code'] as String?;
      var message = err?['message'] as String? ?? 'Request failed (${response.statusCode})';
      final retryable = err?['retryable'] as bool?;
      if (code == 'BIOMETRIC_UNAVAILABLE') {
        message = 'Biometric processing failed on server. See full log below.';
      }
      _throwApi(
        method: method,
        path: path,
        correlationId: err?['correlation_id'] as String? ?? responseCorr,
        statusCode: response.statusCode,
        code: code,
        message: message,
        rawBody: response.body,
        retryable: retryable,
      );
    }
    return body ?? {};
  }

  Future<Map<String, dynamic>> health() => _get('/health');

  Future<Map<String, dynamic>> registerClient({required String displayName}) => _post(
        '/v1/clients',
        admin: true,
        body: {
          'tenant_slug': tenantSlug,
          'tenant_display_name': 'Demo Tenant',
          'display_name': displayName,
          'allowed_scopes': kRequiredScopes,
        },
      );

  Future<Map<String, dynamic>> issueToken() => _post(
        '/v1/clients/$clientId/tokens',
        body: {'client_key': clientKey, 'client_secret': clientSecret},
      );

  Future<Map<String, dynamic>> createIdentity() => _post(
        '/v1/identities',
        extraHeaders: {'Idempotency-Key': _uuid.v4()},
        body: {},
      );

  Future<Map<String, dynamic>> getIdentity(String id) => _get('/v1/identities/$id');

  Future<Map<String, dynamic>> createConsent(String identityId) => _post(
        '/v1/identities/$identityId/consents',
        body: {
          'purpose': 'identity_verification',
          'purpose_version': '1.0',
          'granted': true,
        },
      );

  Future<Map<String, dynamic>> enrollFace({
    required String identityId,
    required String imageBase64,
  }) =>
      _post(
        '/v1/face/enrollments',
        body: {'identity_id': identityId, 'image_base64': imageBase64},
      );

  Future<Map<String, dynamic>> issueQrReference(String identityId) => _post(
        '/v1/qr/references',
        body: {'identity_id': identityId},
      );

  Future<Map<String, dynamic>> createVerificationSession(
    String identityId, {
    List<String>? requiredChecks,
  }) =>
      _post(
        '/v1/verification-sessions',
        body: {
          'identity_id': identityId,
          'required_checks': requiredChecks ?? ['face_verification', 'liveness'],
        },
      );

  Future<Map<String, dynamic>> submitFaceCheck({
    required String sessionId,
    required String imageBase64,
  }) =>
      _post(
        '/v1/verification-sessions/$sessionId/checks/face',
        body: {'image_base64': imageBase64},
      );

  Future<Map<String, dynamic>> submitLivenessCheck({
    required String sessionId,
    required String imageBase64,
  }) =>
      _post(
        '/v1/verification-sessions/$sessionId/checks/liveness',
        body: {'image_base64': imageBase64},
      );

  Future<Map<String, dynamic>> completeSession(String sessionId) => _post(
        '/v1/verification-sessions/$sessionId/complete',
        body: {'decision': 'approved'},
      );

  Future<Map<String, dynamic>> getSession(String sessionId) =>
      _get('/v1/verification-sessions/$sessionId');
}
