import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../config/defaults.dart';
import '../config/secrets_loader.dart';
import '../services/face_capture_quality.dart';
import '../utils/jwt_utils.dart';
import '../services/auth_storage.dart';
import '../services/identity_api_client.dart';

enum FlowStep {
  setup,
  createIdentity,
  enrollFace,
  showQr,
  startVerification,
  captureVerify,
  result,
}

class AppState extends ChangeNotifier {
  AppState(this._storage);

  final AuthStorage _storage;

  bool loading = false;
  String? error;
  bool configured = false;

  String baseUrl = kDefaultApiBaseUrl;
  String tenantSlug = kDefaultTenantSlug;
  String tenantId = '';
  String clientId = '';
  String clientKey = '';
  String clientSecret = '';
  String accessToken = '';
  String adminToken = '';

  String? identityId;
  String? enrollmentId;
  String? qrToken;
  String? sessionId;
  Map<String, dynamic>? lastSession;
  FlowStep step = FlowStep.setup;
  bool manualMode = false;
  bool navigateToResult = false;

  bool get _hasValidClientCreds => AppSecrets(
        clientId: clientId,
        clientKey: clientKey,
        clientSecret: clientSecret,
      ).hasClientCredentials;

  IdentityApiClient get api => IdentityApiClient(
        baseUrl: baseUrl,
        tenantSlug: tenantSlug,
        tenantId: tenantId,
        accessToken: accessToken,
        clientId: clientId,
        clientKey: clientKey,
        clientSecret: clientSecret,
        adminToken: adminToken,
      );

  void _applyToken(String token, {String? resolvedTenantId}) {
    accessToken = token;
    tenantId = resolvedTenantId ?? tenantIdFromAccessToken(token) ?? tenantId;
  }

  void _applyRegisteredClient(Map<String, dynamic> client) {
    clientId = client['id'] as String;
    clientKey = client['client_key'] as String;
    clientSecret = client['client_secret'] as String;
    tenantId = client['tenant_id'] as String;
  }

  Future<void> bootstrap() async {
    loading = true;
    notifyListeners();

    final data = await _storage.load();
    baseUrl = data['baseUrl']!;
    tenantSlug = data['tenantSlug']!;
    tenantId = data['tenantId']!;
    clientId = data['clientId']!;
    clientKey = data['clientKey']!;
    clientSecret = data['clientSecret']!;
    accessToken = data['accessToken']!;
    adminToken = data['adminToken']!;

    final secrets = await AppSecrets.load();
    if (adminToken.isEmpty && secrets.hasAdminToken) {
      adminToken = secrets.adminToken;
    }
    if (!_hasValidClientCreds && secrets.hasClientCredentials) {
      clientId = secrets.clientId;
      clientKey = secrets.clientKey;
      clientSecret = secrets.clientSecret;
    }

    configured = accessToken.isNotEmpty && _hasValidClientCreds && tenantId.isNotEmpty;
    if (!configured) {
      await autoConnect(silent: true);
    } else {
      step = FlowStep.createIdentity;
    }
    loading = false;
    notifyListeners();
  }

  /// Auto-register or refresh token — skips manual API Setup when secrets are available.
  Future<bool> autoConnect({bool silent = false}) async {
    if (!silent) {
      loading = true;
      error = null;
      notifyListeners();
    }
    try {
      if (_hasValidClientCreds) {
        final token = await IdentityApiClient(
          baseUrl: baseUrl,
          tenantSlug: tenantSlug,
          tenantId: tenantId,
          accessToken: '',
          clientId: clientId,
          clientKey: clientKey,
          clientSecret: clientSecret,
        ).issueToken();
        _applyToken(token['access_token'] as String);
      } else if (adminToken.isNotEmpty) {
        final client = await IdentityApiClient(
          baseUrl: baseUrl,
          tenantSlug: tenantSlug,
          accessToken: '',
          adminToken: adminToken,
        ).registerClient(displayName: 'Solveig Mobile Demo');
        _applyRegisteredClient(client);

        final token = await IdentityApiClient(
          baseUrl: baseUrl,
          tenantSlug: tenantSlug,
          tenantId: tenantId,
          accessToken: '',
          clientId: clientId,
          clientKey: clientKey,
          clientSecret: clientSecret,
        ).issueToken();
        _applyToken(token['access_token'] as String, resolvedTenantId: tenantId);
      } else {
        step = FlowStep.setup;
        return false;
      }

      await _storage.saveConnection(
        baseUrl: baseUrl,
        tenantSlug: tenantSlug,
        tenantId: tenantId,
        clientId: clientId,
        clientKey: clientKey,
        clientSecret: clientSecret,
        accessToken: accessToken,
        adminToken: adminToken,
      );
      configured = true;
      step = FlowStep.createIdentity;
      return true;
    } on ApiException catch (e) {
      error = e.message;
      step = FlowStep.setup;
      return false;
    } catch (e) {
      error = e.toString();
      step = FlowStep.setup;
      return false;
    } finally {
      if (!silent) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> connect({
    required String baseUrl,
    required String tenantSlug,
    required String adminToken,
    String? existingClientId,
    String? existingClientKey,
    String? existingClientSecret,
  }) async {
    _run(() async {
      this.baseUrl = baseUrl.trim();
      this.tenantSlug = tenantSlug.trim();
      this.adminToken = adminToken.trim();

      if (existingClientId != null &&
          existingClientId.isNotEmpty &&
          existingClientKey != null &&
          existingClientSecret != null) {
        clientId = existingClientId;
        clientKey = existingClientKey;
        clientSecret = existingClientSecret;
      } else {
        final client = await IdentityApiClient(
          baseUrl: this.baseUrl,
          tenantSlug: this.tenantSlug,
          accessToken: '',
          adminToken: this.adminToken,
        ).registerClient(displayName: 'Solveig Mobile Demo');
        _applyRegisteredClient(client);
      }

      final token = await IdentityApiClient(
        baseUrl: this.baseUrl,
        tenantSlug: this.tenantSlug,
        tenantId: tenantId,
        accessToken: '',
        clientId: clientId,
        clientKey: clientKey,
        clientSecret: clientSecret,
      ).issueToken();
      _applyToken(token['access_token'] as String, resolvedTenantId: tenantId);

      await _storage.saveConnection(
        baseUrl: this.baseUrl,
        tenantSlug: this.tenantSlug,
        tenantId: tenantId,
        clientId: clientId,
        clientKey: clientKey,
        clientSecret: clientSecret,
        accessToken: accessToken,
        adminToken: this.adminToken,
      );
      configured = true;
      step = FlowStep.createIdentity;
    });
  }

  Future<void> startQuickFlow() async {
    manualMode = false;
    await resetFlow();
    await createIdentity();
  }

  void setManualMode(bool value) {
    manualMode = value;
    notifyListeners();
  }

  Future<void> afterEnrollInQuickFlow() async {
    if (manualMode || error != null) return;
    await issueQr();
    if (error != null) return;
    await startVerification();
  }

  Future<void> createIdentity() async {
    await _run(() async {
      final body = await api.createIdentity();
      identityId = body['id'] as String;
      await api.createConsent(identityId!);
      step = FlowStep.enrollFace;
    });
  }

  Future<void> enrollWithImageBytes(List<int> image) async {
    final normalized = await normalizeCaptureBytes(Uint8List.fromList(image));
    await _run(() async {
      final b64 = base64Encode(normalized);
      final body = await api.enrollFace(identityId: identityId!, imageBase64: b64);
      enrollmentId = body['id'] as String;
      step = FlowStep.showQr;
    });
    if (!manualMode && error == null) {
      await afterEnrollInQuickFlow();
    }
  }

  Future<void> verifyWithImageBytes(List<int> image) async {
    final normalized = await normalizeCaptureBytes(Uint8List.fromList(image));
    await _run(() async {
      await _runVerificationPipeline(base64Encode(normalized));
    });
  }

  Future<void> issueQr() async {
    await _run(() async {
      final body = await api.issueQrReference(identityId!);
      qrToken = body['token'] as String;
      step = FlowStep.startVerification;
    });
  }

  Future<void> startVerification() async {
    await _run(() async {
      final body = await api.createVerificationSession(identityId!);
      sessionId = body['id'] as String;
      lastSession = body;
      step = FlowStep.captureVerify;
    });
  }

  Future<void> _runVerificationPipeline(String b64) async {
    Map<String, dynamic> session;

    session = await _submitCheckSafely(
      () => api.submitFaceCheck(sessionId: sessionId!, imageBase64: b64),
    );
    lastSession = session;

    session = await _submitCheckSafely(
      () => api.submitLivenessCheck(sessionId: sessionId!, imageBase64: b64),
    );
    lastSession = session;

    if (_allChecksPassed(session)) {
      session = await _completeSafely();
    } else {
      // Failed checks cannot complete on API — still show outcome to user.
      try {
        session = await api.getSession(sessionId!);
      } catch (_) {
        session = lastSession!;
      }
    }

    lastSession = session;
    step = FlowStep.result;
    navigateToResult = true;
    notifyListeners();
  }

  Future<Map<String, dynamic>> _submitCheckSafely(
    Future<Map<String, dynamic>> Function() submit,
  ) async {
    try {
      return await submit();
    } on ApiException catch (e) {
      if (e.code == 'CHECK_TERMINAL') {
        return api.getSession(sessionId!);
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _completeSafely() async {
    try {
      return await api.completeSession(sessionId!);
    } on ApiException catch (e) {
      if (e.code == 'SESSION_TERMINAL' || e.code == 'CHECKS_INCOMPLETE') {
        return api.getSession(sessionId!);
      }
      rethrow;
    }
  }

  bool _allChecksPassed(Map<String, dynamic> session) {
    final checks = (session['checks'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    return checks.isNotEmpty && checks.every((c) => c['status'] == 'passed');
  }

  void clearNavigateToResult() {
    navigateToResult = false;
  }

  Future<void> resetFlow() async {
    identityId = null;
    enrollmentId = null;
    qrToken = null;
    sessionId = null;
    lastSession = null;
    navigateToResult = false;
    error = null;
    step = FlowStep.createIdentity;
    notifyListeners();
  }

  Future<void> _run(Future<void> Function() action) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      await action();
    } on ApiException catch (e) {
      error = e.message;
    } catch (e) {
      final text = e.toString();
      error = text.startsWith('FormatException') ? 'Unexpected API response — server may be down or need redeploy.' : text;
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}
