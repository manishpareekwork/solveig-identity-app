import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../config/defaults.dart';
import '../config/secrets_loader.dart';
import '../features/flow/flow_models.dart';
import '../features/flow/verification_result_screen.dart';
import '../models/registered_profile.dart';
import '../services/api_error_detail.dart';
import '../services/face_capture_quality.dart';
import '../utils/confidence_format.dart';
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
  Future<void> verifyLiveAgainstProfiles(List<int> image) async {
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
      final normalized = await normalizeCaptureBytes(Uint8List.fromList(image));
      final b64 = base64Encode(normalized);
      loadingMessage = total == 1
          ? 'Matching live capture against ${registeredProfiles.first.label}…'
          : 'Matching live capture against $total profiles…';
      notifyListeners();

      final attempts = await Future.wait([
        for (var i = 0; i < total; i++)
          _probeProfile(
            profile: registeredProfiles[i],
            profileIndex: i + 1,
            imageBase64: b64,
          ),
      ]);

      ProfileMatchAttempt? best;
      for (final attempt in attempts) {
        if (attempt.passed && (best == null || (attempt.confidence ?? 0) > (best.confidence ?? 0))) {
          best = attempt;
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
      sessionId = best.sessionId;
      if (sessionId == null) {
        final session = await api.createVerificationSession(best.identityId);
        sessionId = session['id'] as String;
        await _runVerificationPipeline(b64);
      } else {
        await _finishMatchedSession(b64);
      }

      final sessionArgs = lastSession != null ? resultArgsFromSession(lastSession!) : null;
      pendingResultArgs = VerificationResultArgs(
        passed: sessionArgs?.passed ?? false,
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
        message:
            'Match found in ${best.profileLabel} (profile ${best.profileIndex} of $total). ${total - 1} other profile${total - 1 == 1 ? '' : 's'} did not match.',
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

  Future<ProfileMatchAttempt> _probeProfile({
    required RegisteredProfile profile,
    required int profileIndex,
    required String imageBase64,
  }) async {
    try {
      final session = await api.createVerificationSession(
        profile.identityId,
        requiredChecks: const ['face_verification', 'liveness'],
      );
      final probeSessionId = session['id'] as String;
      final result = await api.submitFaceCheck(sessionId: probeSessionId, imageBase64: imageBase64);
      final checks = (result['checks'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
      final faceCheck = findCheck(checks, 'face_verification') ?? {};
      final status = faceCheck['status'] as String? ?? 'failed';
      return ProfileMatchAttempt(
        profileIndex: profileIndex,
        profileLabel: profile.label,
        identityId: profile.identityId,
        enrollmentId: profile.enrollmentId,
        passed: status == 'passed',
        confidence: checkConfidence(faceCheck),
        resultCode: faceCheck['result_code'] as String?,
        sessionId: status == 'passed' ? probeSessionId : null,
      );
    } on ApiException catch (e) {
      return ProfileMatchAttempt(
        profileIndex: profileIndex,
        profileLabel: profile.label,
        identityId: profile.identityId,
        enrollmentId: profile.enrollmentId,
        passed: false,
        resultCode: e.code ?? 'error',
      );
    }
  }

  /// Complete a probe session that already passed face match — liveness + finalize only.
  Future<void> _finishMatchedSession(String b64) async {
    var session = await _submitCheckSafely(
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

  Future<void> verifyWithImageBytes(List<int> image) async {
    final normalized = await normalizeCaptureBytes(Uint8List.fromList(image));
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
