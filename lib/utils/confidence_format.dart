/// Formats API confidence (0–1 float) as a percentage label.
String formatConfidencePercent(dynamic value) {
  if (value == null) return '—';
  final n = value is num ? value.toDouble() : double.tryParse('$value');
  if (n == null) return '—';
  final pct = n <= 1 ? n * 100 : n;
  return '${pct.clamp(0, 100).toStringAsFixed(1)}%';
}

double? checkConfidence(Map<String, dynamic> check) {
  final v = check['confidence'];
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse('$v');
}

Map<String, dynamic>? findCheck(List<Map<String, dynamic>> checks, String type) {
  for (final c in checks) {
    if (c['check_type'] == type) return c;
  }
  return null;
}
