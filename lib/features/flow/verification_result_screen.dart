import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../widgets/app_button.dart';
import '../../widgets/live_api_banner.dart';
import '../../utils/confidence_format.dart';
import 'flow_models.dart';

class VerificationResultScreen extends StatelessWidget {
  const VerificationResultScreen({super.key, required this.args});

  final VerificationResultArgs args;

  @override
  Widget build(BuildContext context) {
    final passed = args.passed;
    final color = passed ? AppTheme.success : AppTheme.error;
    final label = passed ? 'PASS' : 'FAIL';

    return Scaffold(
      appBar: AppBar(title: const Text('Verification result')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const LiveApiBanner(compact: true),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  label,
                  style: TextStyle(color: color, fontWeight: FontWeight.w700, letterSpacing: 0.6),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Session: ${args.sessionStatus}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          if (args.message != null) ...[
            const SizedBox(height: 12),
            Text(args.message!, style: Theme.of(context).textTheme.bodyLarge),
          ],
          if (args.faceMatchConfidence != null || args.livenessConfidence != null) ...[
            const SizedBox(height: 16),
            _ConfidenceSummary(
              face: args.faceMatchConfidence,
              liveness: args.livenessConfidence,
            ),
          ],
          const SizedBox(height: 20),
          Text('Check outcomes', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          ...args.checks.map((c) => _CheckCard(check: c)),
          if (args.identityId != null) ...[
            const SizedBox(height: 16),
            _InfoRow(label: 'Identity', value: args.identityId!),
          ],
          if (args.sessionId != null) ...[
            const SizedBox(height: 8),
            _InfoRow(label: 'Session', value: args.sessionId!),
          ],
          const SizedBox(height: 28),
          AppButton(
            label: 'Verify another',
            icon: Icons.replay,
            onPressed: () => context.go('/'),
          ),
          const SizedBox(height: 12),
          AppButton(
            label: 'Back to flow',
            variant: AppButtonVariant.outline,
            icon: Icons.list_alt,
            onPressed: () => context.go('/flow'),
          ),
        ],
      ),
    );
  }
}

class _CheckCard extends StatelessWidget {
  const _CheckCard({required this.check});

  final Map<String, dynamic> check;

  @override
  Widget build(BuildContext context) {
    final type = check['check_type'] as String? ?? 'check';
    final status = check['status'] as String? ?? 'unknown';
    final code = check['result_code'] as String? ?? '-';
    final confidence = checkConfidence(check);
    final ok = status == 'passed';
    final color = ok ? AppTheme.success : (status == 'failed' ? AppTheme.error : AppTheme.warning);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(ok ? Icons.check_circle : Icons.cancel, color: color),
        title: Text(_label(type)),
        subtitle: Text(
          confidence != null
              ? '$status · $code · confidence ${formatConfidencePercent(confidence)}'
              : '$status · $code',
        ),
        trailing: confidence != null
            ? Text(
                formatConfidencePercent(confidence),
                style: TextStyle(fontWeight: FontWeight.w700, color: color),
              )
            : null,
      ),
    );
  }

  static String _label(String type) {
    return switch (type) {
      'face_verification' => '1:1 Face match',
      'liveness' => 'Liveness',
      _ => type,
    };
  }
}

class _ConfidenceSummary extends StatelessWidget {
  const _ConfidenceSummary({this.face, this.liveness});

  final double? face;
  final double? liveness;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.card,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Match accuracy (API)', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            if (face != null)
              _MetricRow(
                label: '1:1 face match',
                value: formatConfidencePercent(face),
                icon: Icons.face_retouching_natural,
              ),
            if (liveness != null) ...[
              const SizedBox(height: 8),
              _MetricRow(
                label: 'Liveness score',
                value: formatConfidencePercent(liveness),
                icon: Icons.verified_user_outlined,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppTheme.primary),
        const SizedBox(width: 8),
        Expanded(child: Text(label)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SelectableText('$label: $value', style: Theme.of(context).textTheme.bodySmall);
  }
}

VerificationResultArgs resultArgsFromSession(Map<String, dynamic> session) {
  final checks = (session['checks'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
  final allPassed = checks.isNotEmpty && checks.every((c) => c['status'] == 'passed');
  final status = session['status'] as String? ?? 'unknown';
  final passed = status == 'verified' || (status != 'failed' && allPassed);

  String? message;
  if (!passed) {
    final failed = checks.where((c) => c['status'] == 'failed').toList();
    if (failed.isNotEmpty) {
      message = failed.map((c) => '${c['check_type']}: ${c['result_code']}').join('\n');
    }
  }

  return VerificationResultArgs(
    passed: passed,
    sessionStatus: status,
    checks: checks,
    identityId: session['identity_id'] as String?,
    sessionId: session['id'] as String?,
    message: message,
    faceMatchConfidence: checkConfidence(findCheck(checks, 'face_verification') ?? {}),
    livenessConfidence: checkConfidence(findCheck(checks, 'liveness') ?? {}),
  );
}
