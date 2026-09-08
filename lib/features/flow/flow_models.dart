class VerificationResultArgs {
  const VerificationResultArgs({
    required this.passed,
    required this.sessionStatus,
    required this.checks,
    this.identityId,
    this.sessionId,
    this.message,
  });

  final bool passed;
  final String sessionStatus;
  final List<Map<String, dynamic>> checks;
  final String? identityId;
  final String? sessionId;
  final String? message;
}
