import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/theme/app_theme.dart';
import '../../services/api_error_detail.dart';
import '../../state/app_state.dart';
import '../../utils/view_insets.dart';
import '../../widgets/app_button.dart';
import '../../widgets/api_error_panel.dart';
import '../../widgets/identity_loading.dart';
import '../../widgets/live_api_banner.dart';
class FlowScreen extends StatefulWidget {
  const FlowScreen({super.key});

  @override
  State<FlowScreen> createState() => _FlowScreenState();
}

class _FlowScreenState extends State<FlowScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().continueRegisterFlowIfPending();
      _maybeGoResult();
    });
  }

  @override
  void didUpdateWidget(covariant FlowScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _maybeGoResult();
  }

  void _maybeGoResult() {
    final state = context.read<AppState>();
    final args = state.buildResultArgs();
    if (state.navigateToResult && args != null && mounted) {
      state.clearNavigateToResult();
      state.clearPendingResult();
      context.pushReplacement('/result', extra: args);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final manual = state.flowMode == AppFlowMode.manual;
    if (state.navigateToResult) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeGoResult());
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(manual ? 'Manual flow' : 'Register face'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
      ),
      body: Stack(
        children: [
          ListView(
            padding: screenPadding(context),
            children: [
              const LiveApiBanner(compact: true),
              const SizedBox(height: 16),
              _ProgressBar(step: state.step, manual: manual),
              const SizedBox(height: 20),
              _ActiveStepPanel(state: state),
              if (state.errorDetail != null) ...[
                const SizedBox(height: 16),
                ApiErrorPanel(detail: state.errorDetail!),
              ] else if (state.error != null) ...[
                const SizedBox(height: 16),
                ApiErrorPanel(
                  detail: ApiErrorDetail(summary: state.error!, fullLog: state.error!),
                ),
              ],
              if (manual) ...[
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 8),
                Text('All steps', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                ..._manualSteps(state),
              ],
            ],
          ),
          if (state.loading)
            IdentityLoadingOverlay(message: state.activeLoadingMessage),
        ],
      ),
    );
  }

  List<Widget> _manualSteps(AppState state) {
    return [
      _MiniStep(label: 'Identity', done: state.identityId != null, value: state.identityId),
      _MiniStep(label: 'Enrollment', done: state.enrollmentId != null, value: state.enrollmentId),
      _MiniStep(label: 'QR', done: state.qrToken != null, value: state.qrToken != null ? 'issued' : null),
      _MiniStep(label: 'Session', done: state.sessionId != null, value: state.sessionId),
    ];
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.step, required this.manual});

  final FlowStep step;
  final bool manual;

  @override
  Widget build(BuildContext context) {
    final index = _stepIndex(step);
    final total = manual ? 5 : 3;
    final progress = index / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearProgressIndicator(value: progress.clamp(0.05, 1.0)),
        const SizedBox(height: 8),
        Text(
          manual ? 'Step $index of $total · ${_stepLabel(step)}' : 'Register · ${_stepLabel(step)}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  static int _stepIndex(FlowStep step) => switch (step) {
        FlowStep.createIdentity => 1,
        FlowStep.enrollFace => 2,
        FlowStep.registerComplete => 3,
        FlowStep.showQr => 3,
        FlowStep.startVerification => 4,
        FlowStep.captureVerify => 5,
        FlowStep.result => 5,
        _ => 1,
      };

  static String _stepLabel(FlowStep step) => switch (step) {
        FlowStep.createIdentity => 'Create identity',
        FlowStep.enrollFace => 'Enroll face',
        FlowStep.registerComplete => 'Registered',
        FlowStep.showQr => 'Issue QR',
        FlowStep.startVerification => 'Start session',
        FlowStep.captureVerify => 'Live verify',
        FlowStep.result => 'Result',
        _ => 'Setup',
      };
}

class _ActiveStepPanel extends StatelessWidget {
  const _ActiveStepPanel({required this.state});

  final AppState state;

  Future<void> _openLiveVerify(BuildContext context) async {
    final count = state.registeredProfileCount;
    final bytes = await context.push<Uint8List>(
      '/capture',
      extra: {
        'title': 'Live verify',
        'subtitle': 'Capture now — compared against $count registered profile${count == 1 ? '' : 's'}.',
      },
    );
    if (bytes == null || !context.mounted) return;
    await state.verifyLiveAgainstProfiles(bytes);
    if (!context.mounted) return;
    final args = state.buildResultArgs();
    if (state.navigateToResult && args != null) {
      state.clearNavigateToResult();
      state.clearPendingResult();
      context.push('/result', extra: args);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_title(state.step), style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(_subtitle(state)),
            const SizedBox(height: 20),
            ..._actions(context, state),
            if (state.qrToken != null && state.step.index >= FlowStep.showQr.index) ...[
              const SizedBox(height: 16),
              Center(child: QrImageView(data: state.qrToken!, size: 180)),
            ],
          ],
        ),
      ),
    );
  }

  static String _title(FlowStep step) => switch (step) {
        FlowStep.createIdentity => 'Create identity',
        FlowStep.enrollFace => 'Enroll your face',
        FlowStep.registerComplete => 'Face registered',
        FlowStep.showQr => 'Identity QR',
        FlowStep.startVerification => 'Verification session',
        FlowStep.captureVerify => 'Live verify',
        FlowStep.result => 'Done',
        _ => 'Getting started',
      };

  static String _subtitle(AppState state) {
    final manual = state.flowMode == AppFlowMode.manual;
    return switch (state.step) {
      FlowStep.createIdentity => 'Register a new identity on the platform.',
      FlowStep.enrollFace => 'Live camera — one frame sent to the in-house API to create a template.',
      FlowStep.registerComplete =>
        '${state.registeredProfiles.lastOrNull?.label ?? 'Profile'} saved. ${state.registeredProfileCount} profile${state.registeredProfileCount == 1 ? '' : 's'} on this device. Use Verify live from home to match against all.',
      FlowStep.showQr => manual ? 'Issue an opaque QR reference (no PII).' : 'QR reference step.',
      FlowStep.startVerification => manual
          ? 'Open a verification session for 1:1 face + liveness checks.'
          : 'Session for manual verify.',
      FlowStep.captureVerify =>
        'Live camera required — compared against ${state.registeredProfileCount} registered profile${state.registeredProfileCount == 1 ? '' : 's'}.',
      FlowStep.result => 'Verification finished.',
      _ => '',
    };
  }

  List<Widget> _actions(BuildContext context, AppState state) {
    final manual = state.flowMode == AppFlowMode.manual;
    return switch (state.step) {
      FlowStep.createIdentity => [
          AppButton(
            label: 'Create identity',
            icon: Icons.person_add_alt_1,
            onPressed: state.createIdentity,
          ),
        ],
      FlowStep.enrollFace => [
          AppButton(
            label: 'Live camera — enroll',
            icon: Icons.videocam,
            onPressed: () => _openLiveCapture(
              context,
              title: 'Enroll face',
              subtitle:
                  'Align your face in the oval. This creates a new registered profile on the in-house API.',
              onCaptured: state.enrollWithImageBytes,
            ),
          ),
        ],
      FlowStep.registerComplete => [
          Text(
            'Identity: ${state.identityId ?? '—'}\nEnrollment: ${state.enrollmentId ?? '—'}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          AppButton(
            label: 'Register another face',
            icon: Icons.person_add,
            onPressed: state.beginAnotherRegistration,
          ),
          const SizedBox(height: 12),
          AppButton(
            label: 'Verify live (${state.registeredProfileCount} profile${state.registeredProfileCount == 1 ? '' : 's'})',
            icon: Icons.videocam,
            variant: AppButtonVariant.outline,
            onPressed: state.hasRegisteredProfiles ? () => _openLiveVerify(context) : null,
          ),
          const SizedBox(height: 12),
          AppButton(
            label: 'Back to home',
            variant: AppButtonVariant.text,
            onPressed: () => context.go('/'),
          ),
        ],
      FlowStep.showQr => [
          AppButton(label: 'Issue QR', icon: Icons.qr_code, onPressed: state.issueQr),
        ],
      FlowStep.startVerification => [
          AppButton(label: 'Start session', icon: Icons.play_arrow, onPressed: state.startVerification),
        ],
      FlowStep.captureVerify => [
          AppButton(
            label: 'Live camera — verify',
            icon: Icons.videocam,
            onPressed: manual
                ? () => _openLiveCapture(
                      context,
                      title: 'Verify face',
                      subtitle: 'Live capture for 1:1 match against this identity\'s enrollment.',
                      onCaptured: state.verifyWithImageBytes,
                    )
                : () => _openLiveVerify(context),
          ),
        ],
      FlowStep.result => [
          AppButton(
            label: 'View result',
            icon: Icons.fact_check,
            onPressed: state.buildResultArgs() == null
                ? null
                : () {
                    final args = state.buildResultArgs()!;
                    context.push('/result', extra: args);
                  },
          ),
          const SizedBox(height: 12),
          AppButton(
            label: 'Back to home',
            variant: AppButtonVariant.outline,
            onPressed: () => context.go('/'),
          ),
        ],
      _ => [],
    };
  }

  Future<void> _openLiveCapture(
    BuildContext context, {
    required String title,
    required String subtitle,
    required Future<void> Function(List<int> bytes) onCaptured,
  }) async {
    final bytes = await context.push<Uint8List>(
      '/capture',
      extra: {'title': title, 'subtitle': subtitle},
    );
    if (bytes == null || !context.mounted) return;
    await onCaptured(bytes);
    if (!context.mounted) return;
    final state = context.read<AppState>();
    final args = state.buildResultArgs();
    if (state.navigateToResult && args != null) {
      state.clearNavigateToResult();
      state.clearPendingResult();
      context.push('/result', extra: args);
    }
  }
}

class _MiniStep extends StatelessWidget {
  const _MiniStep({required this.label, required this.done, this.value});

  final String label;
  final bool done;
  final String? value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(done ? Icons.check_circle : Icons.radio_button_unchecked,
          color: done ? AppTheme.success : Colors.grey, size: 20),
      title: Text(label),
      subtitle: value != null ? Text(value!, maxLines: 1, overflow: TextOverflow.ellipsis) : null,
    );
  }
}
