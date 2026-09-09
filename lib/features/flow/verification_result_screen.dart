import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../utils/view_insets.dart';
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
        padding: screenPadding(context),
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
          if (args.identificationMode && args.totalProfilesCompared != null) ...[
            const SizedBox(height: 16),
            _IdentificationSummary(args: args),
          ],
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
          if (passed && (args.faceCaptureId != null || args.matchedEnrollmentId != null)) ...[
            const SizedBox(height: 16),
            _ConfirmationCard(args: args),
          ],
          if (args.checks.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('Check outcomes', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            ...args.checks.map((c) => _CheckCard(check: c)),
          ],
          if (args.identityId != null) ...[
            const SizedBox(height: 16),
            Text('Reference IDs', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _InfoRow(label: 'Identity', value: args.identityId!),
          ],
          if (args.sessionId != null) ...[
            const SizedBox(height: 8),
            _InfoRow(label: 'Session', value: args.sessionId!),
          ],
          if (args.faceCaptureId != null) ...[
            const SizedBox(height: 8),
            _InfoRow(label: 'Face capture', value: args.faceCaptureId!),
          ],
          if (args.matchedEnrollmentId != null) ...[
            const SizedBox(height: 8),
            _InfoRow(label: 'Matched enrollment', value: args.matchedEnrollmentId!),
          ],
          if (args.verifiedAt != null) ...[
            const SizedBox(height: 8),
            _InfoRow(label: 'Verified at', value: args.verifiedAt!),
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

class _IdentificationSummary extends StatelessWidget {
  const _IdentificationSummary({required this.args});

  final VerificationResultArgs args;

  @override
  Widget build(BuildContext context) {
    final total = args.totalProfilesCompared ?? args.profileAttempts.length;
    final matched = args.passed && args.matchedProfileIndex != null;
    final headerColor = matched ? AppTheme.success : AppTheme.error;

    return Card(
      color: headerColor.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(matched ? Icons.check_circle : Icons.search_off, color: headerColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    matched
                        ? 'Match in ${args.matchedProfileLabel} (${args.matchedProfileIndex} of $total)'
                        : 'No match among $total profile${total == 1 ? '' : 's'}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(color: headerColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Compared live capture against:', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            ...args.profileAttempts.map((a) {
              final isWinner = matched && a.profileIndex == args.matchedProfileIndex;
              final rowColor = a.passed
                  ? (isWinner ? AppTheme.success : AppTheme.warning)
                  : AppTheme.error;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(
                      a.passed ? (isWinner ? Icons.star : Icons.check) : Icons.close,
                      size: 18,
                      color: rowColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${a.profileLabel} · profile ${a.profileIndex} of $total',
                        style: TextStyle(fontWeight: isWinner ? FontWeight.w700 : FontWeight.normal),
                      ),
                    ),
                    Text(
                      a.passed ? formatConfidencePercent(a.confidence) : (a.resultCode ?? 'no match'),
                      style: TextStyle(color: rowColor, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
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
    final confidence = checkConfidence(check);
    final ok = status == 'passed';
    final color = ok ? AppTheme.success : (status == 'failed' ? AppTheme.error : AppTheme.warning);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(ok ? Icons.check_circle : Icons.cancel, color: color),
        title: Text(_label(type)),
        subtitle: Text(
          _subtitle(type, check),
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

  static String _subtitle(String type, Map<String, dynamic> check) {
    final status = check['status'] as String? ?? 'unknown';
    final code = check['result_code'] as String? ?? '-';
    final confidence = checkConfidence(check);
    final captureId = check['capture_id'] as String?;
    final parts = <String>[status, code];
    if (confidence != null) {
      parts.add('confidence ${formatConfidencePercent(confidence)}');
    }
    if (captureId != null) {
      parts.add('capture $captureId');
    }
    return parts.join(' · ');
  }
}

class _ConfirmationCard extends StatelessWidget {
  const _ConfirmationCard({required this.args});

  final VerificationResultArgs args;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.success.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.verified, color: AppTheme.success),
                const SizedBox(width: 8),
                Text('Identity confirmed', style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            if (args.faceCaptureId != null)
              _ConfirmationRow(
                label: 'Face capture ID',
                value: args.faceCaptureId!,
                hint: 'Logged in API — use for audit / admin lookup',
              ),
            if (args.matchedEnrollmentId != null) ...[
              const SizedBox(height: 10),
              _ConfirmationRow(
                label: 'Matched enrollment',
                value: args.matchedEnrollmentId!,
                hint: 'Template used for 1:1 match',
              ),
            ],
            if (args.identityId != null) ...[
              const SizedBox(height: 10),
              _ConfirmationRow(label: 'Identity', value: args.identityId!),
            ],
            if (args.sessionId != null) ...[
              const SizedBox(height: 10),
              _ConfirmationRow(label: 'Session', value: args.sessionId!),
            ],
          ],
        ),
      ),
    );
  }
}

class _ConfirmationRow extends StatelessWidget {
  const _ConfirmationRow({required this.label, required this.value, this.hint});

  final String label;
  final String value;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 4),
        SelectableText(
          value,
          style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w600),
        ),
        if (hint != null) ...[
          const SizedBox(height: 2),
          Text(hint!, style: Theme.of(context).textTheme.bodySmall),
        ],
      ],
    );
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

  final faceCheck = findCheck(checks, 'face_verification');
  final faceCaptureId = session['face_capture_id'] as String? ?? faceCheck?['capture_id'] as String?;
  final matchedEnrollmentId =
      session['matched_enrollment_id'] as String? ?? faceCheck?['enrollment_id'] as String?;
  final verifiedAt = session['verified_at'] as String?;

  return VerificationResultArgs(
    passed: passed,
    sessionStatus: status,
    checks: checks,
    identityId: session['identity_id'] as String?,
    sessionId: session['id'] as String?,
    message: message,
    faceMatchConfidence: checkConfidence(faceCheck ?? {}),
    livenessConfidence: checkConfidence(findCheck(checks, 'liveness') ?? {}),
    faceCaptureId: faceCaptureId,
    matchedEnrollmentId: matchedEnrollmentId,
    verifiedAt: verifiedAt,
  );
}
