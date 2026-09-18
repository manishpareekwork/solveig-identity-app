import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../config/defaults.dart';
import '../config/secrets_loader.dart';
import '../features/flow/flow_models.dart';
import '../features/flow/verification_result_screen.dart';
import '../models/registered_profile.dart';
import '../services/api_error_detail.dart';
import '../services/face_capture_payload.dart';
import '../services/face_capture_quality.dart';
import '../utils/confidence_format.dart' show formatConfidencePercent;
import '../utils/jwt_utils.dart';
import '../services/auth_storage.dart';
import '../services/identity_api_client.dart';

enum FlowStep {
  setup,
  createIdentity,
  enrollFace,
  registerComplete,
  showQr,
  startVerification,
  captureVerify,
  result,
}

enum AppFlowMode { register, manual, liveIdentify }

class AppState extends ChangeNotifier {
  AppState(this._storage);

  final AuthStorage _storage;
  static const _uuid = Uuid();

  bool loading = false;
  String? loadingMessage;
  String? error;
  ApiErrorDetail? errorDetail;
  bool configured = false;
  bool registerFlowPending = false;

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
  VerificationResultArgs? pendingResultArgs;
  List<RegisteredProfile> registeredProfiles = [];
  FlowStep step = FlowStep.setup;
  AppFlowMode flowMode = AppFlowMode.register;
  bool navigateToResult = false;

  bool get hasRegisteredProfiles => registeredProfiles.isNotEmpty;
  int get registeredProfileCount => registeredProfiles.length;

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
    await loadRegisteredProfiles();
    if (!configured) {
      await autoConnect(silent: true);
    } else {
      try {
        await ensureFreshToken();
        step = FlowStep.createIdentity;
      } catch (_) {
        await autoConnect(silent: true);
      }
    }
    loading = false;
    notifyListeners();
  }

  Future<bool> autoConnect({bool silent = false}) async {
    if (!silent) {
      loading = true;
      loadingMessage = 'Connecting to in-house API…';
      error = null;
      errorDetail = null;
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
        ).registerClient(displayName: 'Mobile Demo');
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
      _setError(e, context: 'autoConnect');
      step = FlowStep.setup;
      return false;
    } catch (e) {
      _setUnknownError(e, context: 'autoConnect');
      step = FlowStep.setup;
      return false;
    } finally {
      if (!silent) {
        loading = false;
        loadingMessage = null;
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
        ).registerClient(displayName: 'Mobile Demo');
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
    }, loadingMessage: 'Connecting to in-house API…');
  }

  Future<void> loadRegisteredProfiles() async {
    registeredProfiles = await _storage.loadRegisteredProfiles();
    notifyListeners();
  }

  Future<void> deleteRegisteredProfile(RegisteredProfile profile) async {
    await _run(() async {
      await ensureFreshToken();
      await api.revokeEnrollment(profile.enrollmentId);
      registeredProfiles = registeredProfiles.where((p) => p.localId != profile.localId).toList();
      await _storage.saveRegisteredProfiles(registeredProfiles);
      if (identityId == profile.identityId) {
        identityId = null;
        enrollmentId = null;
      }
    }, loadingMessage: 'Removing profile…');
  }

  Future<void> beginRegisterFlow() async {
    flowMode = AppFlowMode.register;
    await resetFlow();
    registerFlowPending = true;
    notifyListeners();
  }

  Future<void> continueRegisterFlowIfPending() async {
    if (!registerFlowPending || flowMode != AppFlowMode.register) return;
    registerFlowPending = false;
    if (!configured) {
      loadingMessage = 'Connecting to in-house API…';
      loading = true;
      notifyListeners();
      try {
        final ok = await autoConnect(silent: true);
        if (!ok) return;
      } finally {
        loading = false;
        loadingMessage = null;
        notifyListeners();
      }
    }
    await createIdentity();
  }

  Future<void> beginAnotherRegistration() async {
    flowMode = AppFlowMode.register;
    identityId = null;
    enrollmentId = null;
    qrToken = null;
    sessionId = null;
    lastSession = null;
    error = null;
    errorDetail = null;
    step = FlowStep.createIdentity;
    registerFlowPending = true;
    notifyListeners();
    await continueRegisterFlowIfPending();
  }

  String get activeLoadingMessage =>
      loadingMessage ??
      switch (step) {
        FlowStep.createIdentity => 'Creating identity…',
        FlowStep.enrollFace => 'Processing face enrollment…',
        FlowStep.registerComplete => 'Registration complete',
        FlowStep.showQr => 'Issuing QR reference…',
        FlowStep.startVerification => 'Starting verification session…',
        FlowStep.captureVerify => 'Running face match & liveness…',
        _ => 'Working with in-house API…',
      };

  void setManualMode(bool value) {
    flowMode = value ? AppFlowMode.manual : AppFlowMode.register;
    notifyListeners();
  }

  Future<void> refreshAccessToken() async {
    if (!_hasValidClientCreds) {
      throw ApiException('Client credentials required to refresh token');
    }
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
  }

  Future<void> ensureFreshToken() async {
    if (!_hasValidClientCreds) {
      final ok = await autoConnect(silent: true);
      if (!ok) throw ApiException('Not connected — check API setup or secrets.json');
      return;
    }
    if (accessToken.isEmpty || isAccessTokenExpired(accessToken)) {
      try {
        await refreshAccessToken();
      } on ApiException catch (e) {
        if (e.statusCode == 401 && adminToken.isNotEmpty) {
          final ok = await autoConnect(silent: true);
          if (!ok) rethrow;
        } else {
          rethrow;
        }
      }
    }
  }

  Future<void> createIdentity() async {
    await _run(() async {
      await ensureFreshToken();
      final body = await api.createIdentity();
      identityId = body['id'] as String;
      await api.createConsent(identityId!);
      step = FlowStep.enrollFace;
    }, loadingMessage: 'Creating identity…');
  }

  Future<void> enrollWithImageBytes(List<int> image) async {
    final normalized = await normalizeCaptureBytes(Uint8List.fromList(image));
    await _run(() async {
      final b64 = base64Encode(normalized);
      final body = await api.enrollFace(identityId: identityId!, imageBase64: b64);
      enrollmentId = body['id'] as String;
      if (flowMode == AppFlowMode.manual) {
        step = FlowStep.showQr;
      } else {
        step = FlowStep.registerComplete;
      }
    }, loadingMessage: 'Enrolling face template…');
    if (error == null) {
      await _addRegisteredProfile();
    }
  }

  Future<void> _addRegisteredProfile() async {
    if (identityId == null || enrollmentId == null) return;
    final label = 'Profile ${registeredProfiles.length + 1}';
    final profile = RegisteredProfile(
      localId: _uuid.v4(),
      label: label,
      identityId: identityId!,
      enrollmentId: enrollmentId!,
      enrolledAt: DateTime.now(),
    );
    registeredProfiles = [...registeredProfiles, profile];
    await _storage.saveRegisteredProfiles(registeredProfiles);
    notifyListeners();
  }

  /// Live capture compared against every registered profile (1:1 API loop).
  Future<void> verifyLiveAgainstProfiles(FaceCapturePayload capture) async {
    final total = registeredProfiles.length;
    if (total == 0) {
      error = 'No registered profiles — register at least one face first.';
      errorDetail = ApiErrorDetail(summary: error!, fullLog: error!);
      notifyListeners();
      return;
    }

    loading = true;
    error = null;
    errorDetail = null;
    loadingMessage = 'Preparing live match against $total profile${total == 1 ? '' : 's'}…';
    notifyListeners();

    try {
      await ensureFreshToken();
      final normalized = await normalizeCaptureBytes(capture.primary);
      final b64 = base64Encode(normalized);

      if (total == 1) {
        final profile = registeredProfiles.first;
        loadingMessage = 'Verifying ${profile.label}…';
        notifyListeners();
        identityId = profile.identityId;
        enrollmentId = profile.enrollmentId;
        sessionId = (await api.createVerificationSession(profile.identityId))['id'] as String;
        await _runVerificationPipeline(b64);
        final sessionArgs = lastSession != null ? resultArgsFromSession(lastSession!) : null;
        final sessionPassed = sessionArgs?.passed ?? false;
        pendingResultArgs = VerificationResultArgs(
          passed: sessionPassed,
          sessionStatus: sessionArgs?.sessionStatus ?? 'unknown',
          checks: sessionArgs?.checks ?? const [],
          identityId: profile.identityId,
          sessionId: sessionId,
          faceMatchConfidence: sessionArgs?.faceMatchConfidence,
          livenessConfidence: sessionArgs?.livenessConfidence,
          faceCaptureId: sessionArgs?.faceCaptureId,
          matchedEnrollmentId: profile.enrollmentId,
          verifiedAt: sessionArgs?.verifiedAt,
          identificationMode: true,
          totalProfilesCompared: 1,
          matchedProfileIndex: 1,
          matchedProfileLabel: profile.label,
          profileAttempts: [
            ProfileMatchAttempt(
              profileIndex: 1,
              profileLabel: profile.label,
              identityId: profile.identityId,
              enrollmentId: profile.enrollmentId,
              passed: sessionPassed,
              confidence: sessionArgs?.faceMatchConfidence,
              resultCode: sessionPassed ? 'verification_passed' : 'verification_failed',
            ),
          ],
          message: sessionPassed ? 'Verified: ${profile.label}.' : sessionArgs?.message,
        );
        navigateToResult = true;
        return;
      }

      loadingMessage = 'Matching live capture against $total profiles…';
      notifyListeners();

      final identify = await api.identifyFace(
        imageBase64: b64,
        identityIds: registeredProfiles.map((p) => p.identityId).toList(),
      );
      final candidates = (identify['candidates'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
      final attempts = <ProfileMatchAttempt>[];
      for (var i = 0; i < registeredProfiles.length; i++) {
        final profile = registeredProfiles[i];
        Map<String, dynamic>? row;
        for (final candidate in candidates) {
          if (candidate['identity_id'] == profile.identityId) {
            row = candidate;
            break;
          }
        }
        final confidence = (row?['confidence'] as num?)?.toDouble();
        final matched = row?['matched'] == true;
        attempts.add(
          ProfileMatchAttempt(
            profileIndex: i + 1,
            profileLabel: profile.label,
            identityId: profile.identityId,
            enrollmentId: profile.enrollmentId,
            passed: matched,
            confidence: confidence,
            resultCode: matched ? 'verification_passed' : 'verification_failed',
          ),
        );
      }

      ProfileMatchAttempt? best;
      if (identify['matched'] == true && identify['identity_id'] != null) {
        final matchedId = identify['identity_id'] as String;
        final idx = registeredProfiles.indexWhere((p) => p.identityId == matchedId);
        if (idx >= 0) {
          best = attempts[idx];
        }
      }

      if (best == null) {
        pendingResultArgs = VerificationResultArgs(
          passed: false,
          sessionStatus: 'no_match',
          checks: const [],
          identificationMode: true,
          totalProfilesCompared: total,
          profileAttempts: attempts,
          message: 'No match found among $total registered profile${total == 1 ? '' : 's'}.',
        );
        navigateToResult = true;
        notifyListeners();
        return;
      }

      loadingMessage = 'Match in ${best.profileLabel} — liveness check…';
      notifyListeners();

      identityId = best.identityId;
      enrollmentId = best.enrollmentId;
      final session = await api.createVerificationSession(
        best.identityId,
        requiredChecks: const ['liveness'],
      );
      sessionId = session['id'] as String;
      await _runVerificationPipeline(b64, skipFaceCheck: true);

      final sessionArgs = lastSession != null ? resultArgsFromSession(lastSession!) : null;
      final sessionPassed = sessionArgs?.passed ?? false;
      pendingResultArgs = VerificationResultArgs(
        passed: sessionPassed,
        sessionStatus: sessionArgs?.sessionStatus ?? 'unknown',
        checks: sessionArgs?.checks ?? const [],
        identityId: best.identityId,
        sessionId: sessionId,
        faceMatchConfidence: best.confidence ?? sessionArgs?.faceMatchConfidence,
        livenessConfidence: sessionArgs?.livenessConfidence,
        faceCaptureId: sessionArgs?.faceCaptureId,
        matchedEnrollmentId: best.enrollmentId,
        verifiedAt: sessionArgs?.verifiedAt,
        identificationMode: true,
        totalProfilesCompared: total,
        matchedProfileIndex: best.profileIndex,
        matchedProfileLabel: best.profileLabel,
        profileAttempts: attempts,
        message: sessionPassed
            ? 'Verified: ${best.profileLabel} (${best.profileIndex} of $total).'
            : 'Face matched ${best.profileLabel} at ${formatConfidencePercent(best.confidence ?? 0)} — '
                '${sessionArgs?.message ?? 'liveness or session check failed'}.',
      );
      navigateToResult = true;
    } on ApiException catch (e) {
      _setError(e, context: 'liveIdentify');
    } catch (e) {
      _setUnknownError(e, context: 'liveIdentify');
    } finally {
      loading = false;
      loadingMessage = null;
      notifyListeners();
    }
  }

  Future<void> verifyWithCapture(FaceCapturePayload capture) async {
    final normalized = await normalizeCaptureBytes(capture.primary);
    await _run(() async {
      await _runVerificationPipeline(base64Encode(normalized));
    }, loadingMessage: 'Running face match & liveness…');
  }

  Future<void> issueQr() async {
    await _run(() async {
      final body = await api.issueQrReference(identityId!);
      qrToken = body['token'] as String;
      step = FlowStep.startVerification;
    }, loadingMessage: 'Issuing QR reference…');
  }

  Future<void> startVerification() async {
    await _run(() async {
      final body = await api.createVerificationSession(identityId!);
      sessionId = body['id'] as String;
      lastSession = body;
      step = FlowStep.captureVerify;
    }, loadingMessage: 'Starting verification session…');
  }

  Future<void> _runVerificationPipeline(
    String b64, {
    bool skipFaceCheck = false,
  }) async {
    Map<String, dynamic> session;

    if (!skipFaceCheck) {
      session = await _submitCheckSafely(
        () => api.submitFaceCheck(sessionId: sessionId!, imageBase64: b64),
      );
      lastSession = session;
    }

    session = await _submitCheckSafely(
      () => api.submitLivenessCheck(sessionId: sessionId!, imageBase64: b64),
    );
    lastSession = session;

    if (_allChecksPassed(session)) {
      session = await _completeSafely();
    } else {
      try {
        session = await api.getSession(sessionId!);
      } catch (_) {
        session = lastSession!;
      }
    }

    lastSession = session;
    step = FlowStep.result;
    pendingResultArgs = resultArgsFromSession(session);
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

  void clearPendingResult() {
    pendingResultArgs = null;
  }

  VerificationResultArgs? buildResultArgs() {
    if (pendingResultArgs != null) return pendingResultArgs;
    if (lastSession != null) return resultArgsFromSession(lastSession!);
    return null;
  }

  void _setError(ApiException e, {String? context}) {
    final detail = ApiErrorDetail.fromException(e);
    errorDetail = context != null
        ? ApiErrorDetail(
            summary: detail.summary,
            fullLog: 'Context: $context\n${detail.fullLog}',
            correlationId: detail.correlationId,
            endpoint: detail.endpoint,
            statusCode: detail.statusCode,
            code: detail.code,
          )
        : detail;
    error = errorDetail!.summary;
  }

  void _setUnknownError(Object e, {String? context}) {
    errorDetail = ApiErrorDetail.fromUnknown(e, context: context);
    error = errorDetail!.summary;
  }

  Future<void> resetFlow() async {
    identityId = null;
    enrollmentId = null;
    qrToken = null;
    sessionId = null;
    lastSession = null;
    pendingResultArgs = null;
    navigateToResult = false;
    error = null;
    errorDetail = null;
    step = FlowStep.createIdentity;
    notifyListeners();
  }

  Future<void> _run(
    Future<void> Function() action, {
    bool retried = false,
    String? loadingMessage,
  }) async {
    loading = true;
    this.loadingMessage = loadingMessage;
    error = null;
    errorDetail = null;
    notifyListeners();
    try {
      await action();
    } on ApiException catch (e) {
      if (!retried &&
          e.statusCode == 401 &&
          (e.message.contains('invalid or expired token') || e.code == 'UNAUTHENTICATED')) {
        try {
          await ensureFreshToken();
          return _run(action, retried: true, loadingMessage: loadingMessage);
        } catch (_) {
          _setError(e);
        }
      } else {
        _setError(e);
      }
    } catch (e) {
      _setUnknownError(e);
    } finally {
      loading = false;
      this.loadingMessage = null;
      notifyListeners();
    }
  }
}
