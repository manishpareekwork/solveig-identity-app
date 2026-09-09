class RegisteredProfile {
  const RegisteredProfile({
    required this.localId,
    required this.label,
    required this.identityId,
    required this.enrollmentId,
    required this.enrolledAt,
  });

  final String localId;
  final String label;
  final String identityId;
  final String enrollmentId;
  final DateTime enrolledAt;

  Map<String, dynamic> toJson() => {
        'localId': localId,
        'label': label,
        'identityId': identityId,
        'enrollmentId': enrollmentId,
        'enrolledAt': enrolledAt.toIso8601String(),
      };

  factory RegisteredProfile.fromJson(Map<String, dynamic> json) => RegisteredProfile(
        localId: json['localId'] as String,
        label: json['label'] as String,
        identityId: json['identityId'] as String,
        enrollmentId: json['enrollmentId'] as String,
        enrolledAt: DateTime.parse(json['enrolledAt'] as String),
      );
}
