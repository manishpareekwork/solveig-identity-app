import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/theme/app_theme.dart';
import '../../state/app_state.dart';
import '../../widgets/app_button.dart';
import '../../widgets/live_api_banner.dart';
import 'verification_result_screen.dart';

class FlowScreen extends StatefulWidget {
  const FlowScreen({super.key});

  @override
  State<FlowScreen> createState() => _FlowScreenState();
}

class _FlowScreenState extends State<FlowScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeGoResult());
  }

  @override
  void didUpdateWidget(covariant FlowScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _maybeGoResult();
  }

  void _maybeGoResult() {
    final state = context.read<AppState>();
    if (state.navigateToResult && state.lastSession != null && mounted) {
      state.clearNavigateToResult();
      final args = resultArgsFromSession(state.lastSession!);
      context.pushReplacement('/result', extra: args);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (state.navigateToResult) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeGoResult());
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(state.manualMode ? 'Manual flow' : 'Quick flow'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const LiveApiBanner(compact: true),
              const SizedBox(height: 16),
              _ProgressBar(step: state.step, manual: state.manualMode),
              const SizedBox(height: 20),
              _ActiveStepPanel(state: state),
              if (state.error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.error_outline, color: AppTheme.error),
                      const SizedBox(width: 8),
                      Expanded(child: Text(state.error!)),
                    ],
                  ),
                ),
              ],
              if (state.manualMode) ...[
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
            Container(
              color: Colors.black26,
              child: const Center(child: CircularProgressIndicator()),
            ),
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
    final total = 5;
    final progress = index / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearProgressIndicator(value: progress.clamp(0.05, 1.0)),
        const SizedBox(height: 8),
        Text(
          manual ? 'Step $index of $total · ${_stepLabel(step)}' : 'Quick flow · ${_stepLabel(step)}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  static int _stepIndex(FlowStep step) => switch (step) {
        FlowStep.createIdentity => 1,
        FlowStep.enrollFace => 2,
        FlowStep.showQr => 3,
        FlowStep.startVerification => 4,
        FlowStep.captureVerify => 5,
        FlowStep.result => 5,
        _ => 1,
      };

  static String _stepLabel(FlowStep step) => switch (step) {
        FlowStep.createIdentity => 'Create identity',
        FlowStep.enrollFace => 'Enroll face',
        FlowStep.showQr => 'Issue QR',
        FlowStep.startVerification => 'Start session',
        FlowStep.captureVerify => 'Capture & verify',
        FlowStep.result => 'Result',
        _ => 'Setup',
      };
}

class _ActiveStepPanel extends StatelessWidget {
  const _ActiveStepPanel({required this.state});

  final AppState state;

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
        FlowStep.showQr => 'Identity QR',
        FlowStep.startVerification => 'Verification session',
        FlowStep.captureVerify => 'Capture & verify',
        FlowStep.result => 'Done',
        _ => 'Getting started',
      };

  static String _subtitle(AppState state) => switch (state.step) {
        FlowStep.createIdentity => 'Register a new identity on the platform.',
        FlowStep.enrollFace => 'Live front-camera preview — enroll sends one frame to the API.',
        FlowStep.showQr => state.manualMode
            ? 'Issue an opaque QR reference (no PII).'
            : 'QR issued automatically.',
        FlowStep.startVerification => state.manualMode
            ? 'Open a verification session for 1:1 face + liveness checks.'
            : 'Session started automatically.',
        FlowStep.captureVerify => 'Live camera preview — 1:1 match & liveness run on Solveig API when you capture.',
        FlowStep.result => 'Verification finished.',
        _ => '',
      };

  List<Widget> _actions(BuildContext context, AppState state) {
    if (state.loading) {
      return [const Center(child: Text('Working…'))];
    }
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
              state,
              title: 'Enroll face',
              subtitle: 'Align your face in the oval. Enrollment template is created on the Solveig API — not stored as a static match on this device.',
              onCaptured: state.enrollWithImageBytes,
            ),
          ),
        ],
      FlowStep.showQr => [
          if (state.manualMode)
            AppButton(label: 'Issue QR', icon: Icons.qr_code, onPressed: state.issueQr)
          else
            const Text('Continuing automatically…'),
        ],
      FlowStep.startVerification => [
          if (state.manualMode)
            AppButton(label: 'Start session', icon: Icons.play_arrow, onPressed: state.startVerification)
          else
            const Text('Continuing automatically…'),
        ],
      FlowStep.captureVerify => [
          AppButton(
            label: 'Live camera — verify',
            icon: Icons.videocam,
            onPressed: () => _openLiveCapture(
              context,
              state,
              title: 'Verify face',
              subtitle: 'Align your face and capture. Match accuracy and liveness scores come back from the live API.',
              onCaptured: state.verifyWithImageBytes,
            ),
          ),
        ],
      FlowStep.result => [
          AppButton(
            label: 'View result',
            icon: Icons.fact_check,
            onPressed: state.lastSession == null
                ? null
                : () {
                    final args = resultArgsFromSession(state.lastSession!);
                    context.push('/result', extra: args);
                  },
          ),
          const SizedBox(height: 12),
          AppButton(
            label: 'Start over',
            variant: AppButtonVariant.outline,
            onPressed: () async {
              await state.resetFlow();
              if (context.mounted) context.go('/');
            },
          ),
        ],
      _ => [],
    };
  }

  Future<void> _openLiveCapture(
    BuildContext context,
    AppState state, {
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

// Setup screen lives in setup_screen.dart.
