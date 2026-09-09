class ProfileMatchAttempt {
  const ProfileMatchAttempt({
    required this.profileIndex,
    required this.profileLabel,
    required this.identityId,
    required this.enrollmentId,
    required this.passed,
    this.confidence,
    this.resultCode,
    this.sessionId,
  });

  final int profileIndex;
  final String profileLabel;
  final String identityId;
  final String enrollmentId;
  final bool passed;
  final double? confidence;
  final String? resultCode;
  final String? sessionId;
}

class VerificationResultArgs {
  const VerificationResultArgs({
    required this.passed,
    required this.sessionStatus,
    required this.checks,
    this.identityId,
    this.sessionId,
    this.message,
    this.faceMatchConfidence,
    this.livenessConfidence,
    this.faceCaptureId,
    this.matchedEnrollmentId,
    this.enrollmentCaptureId,
    this.verifiedAt,
    this.identificationMode = false,
    this.totalProfilesCompared,
    this.matchedProfileIndex,
    this.matchedProfileLabel,
    this.profileAttempts = const [],
  });

  final bool passed;
  final String sessionStatus;
  final List<Map<String, dynamic>> checks;
  final String? identityId;
  final String? sessionId;
  final String? message;
  final double? faceMatchConfidence;
  final double? livenessConfidence;
  final String? faceCaptureId;
  final String? matchedEnrollmentId;
  final String? enrollmentCaptureId;
  final String? verifiedAt;
  final bool identificationMode;
  final int? totalProfilesCompared;
  final int? matchedProfileIndex;
  final String? matchedProfileLabel;
  final List<ProfileMatchAttempt> profileAttempts;
}
