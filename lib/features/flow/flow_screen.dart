import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../config/defaults.dart';
import '../../state/app_state.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _baseUrl = TextEditingController(text: kDefaultApiBaseUrl);
  final _tenant = TextEditingController(text: kDefaultTenantSlug);
  final _adminToken = TextEditingController();
  final _clientId = TextEditingController();
  final _clientKey = TextEditingController();
  final _clientSecret = TextEditingController();

  @override
  void dispose() {
    _baseUrl.dispose();
    _tenant.dispose();
    _adminToken.dispose();
    _clientId.dispose();
    _clientKey.dispose();
    _clientSecret.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('API Setup')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (state.loading) ...[
            const LinearProgressIndicator(),
            const SizedBox(height: 12),
            const Text('Connecting to API…'),
          ] else ...[
            const Text(
              'Connect to Solveig Identity API. Provide the admin token to auto-register '
              'a mobile client, or paste existing client credentials.',
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _baseUrl,
            decoration: const InputDecoration(labelText: 'API base URL'),
          ),
          TextField(
            controller: _tenant,
            decoration: const InputDecoration(labelText: 'Tenant slug'),
          ),
          TextField(
            controller: _adminToken,
            decoration: const InputDecoration(labelText: 'Admin token (IDENTITY_ADMIN_TOKEN)'),
            obscureText: true,
          ),
          const Divider(height: 32),
          TextField(
            controller: _clientId,
            decoration: const InputDecoration(labelText: 'Existing client ID (optional)'),
          ),
          TextField(
            controller: _clientKey,
            decoration: const InputDecoration(labelText: 'Client key (optional)'),
          ),
          TextField(
            controller: _clientSecret,
            decoration: const InputDecoration(labelText: 'Client secret (optional)'),
            obscureText: true,
          ),
          if (state.error != null) ...[
            const SizedBox(height: 12),
            Text(state.error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: state.loading
                ? null
                : () => state.connect(
                      baseUrl: _baseUrl.text,
                      tenantSlug: _tenant.text,
                      adminToken: _adminToken.text,
                      existingClientId: _clientId.text.isEmpty ? null : _clientId.text,
                      existingClientKey: _clientKey.text.isEmpty ? null : _clientKey.text,
                      existingClientSecret:
                          _clientSecret.text.isEmpty ? null : _clientSecret.text,
                    ),
            child: state.loading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Connect'),
          ),
        ],
      ),
    );
  }
}

class FlowScreen extends StatelessWidget {
  const FlowScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Solveig Identity'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.go('/setup'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _StepTile(
            title: '1. Create / Select Identity',
            done: state.identityId != null,
            active: state.step == FlowStep.createIdentity,
            subtitle: state.identityId ?? 'Not created',
            action: state.step == FlowStep.createIdentity && !state.loading
                ? FilledButton(onPressed: state.createIdentity, child: const Text('Create identity'))
                : null,
          ),
          _StepTile(
            title: '2. Enroll Face',
            done: state.enrollmentId != null,
            active: state.step == FlowStep.enrollFace,
            subtitle: state.enrollmentId ?? 'Capture front camera',
            action: state.step == FlowStep.enrollFace && !state.loading
                ? FilledButton(onPressed: state.captureAndEnroll, child: const Text('Capture & enroll'))
                : null,
          ),
          _StepTile(
            title: '3. Show Identity / QR Reference',
            done: state.qrToken != null,
            active: state.step == FlowStep.showQr,
            subtitle: state.qrToken != null ? 'QR issued' : 'Issue opaque token',
            action: state.step == FlowStep.showQr && !state.loading
                ? FilledButton(onPressed: state.issueQr, child: const Text('Issue QR'))
                : null,
            extra: state.qrToken != null
                ? Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Center(
                      child: QrImageView(data: state.qrToken!, size: 200),
                    ),
                  )
                : null,
          ),
          _StepTile(
            title: '4. Start Verification',
            done: state.sessionId != null,
            active: state.step == FlowStep.startVerification,
            subtitle: state.sessionId ?? 'Create session',
            action: state.step == FlowStep.startVerification && !state.loading
                ? FilledButton(onPressed: state.startVerification, child: const Text('Start session'))
                : null,
          ),
          _StepTile(
            title: '5–6. Capture Face → 1:1 Verify + Liveness',
            done: state.step == FlowStep.result,
            active: state.step == FlowStep.captureVerify,
            subtitle: 'Same face photo runs face + liveness checks',
            action: state.step == FlowStep.captureVerify && !state.loading
                ? FilledButton(onPressed: state.captureAndVerify, child: const Text('Capture & verify'))
                : null,
          ),
          _StepTile(
            title: '7. Verification Result',
            done: state.step == FlowStep.result,
            active: state.step == FlowStep.result,
            subtitle: _sessionSummary(state.lastSession),
            extra: state.lastSession != null ? _CheckList(session: state.lastSession!) : null,
          ),
          if (state.error != null) ...[
            const SizedBox(height: 16),
            Text(state.error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          if (state.loading) const LinearProgressIndicator(minHeight: 2),
          const SizedBox(height: 24),
          if (state.step == FlowStep.result)
            OutlinedButton(onPressed: state.resetFlow, child: const Text('Start new identity')),
        ],
      ),
    );
  }

  static String _sessionSummary(Map<String, dynamic>? session) {
    if (session == null) return 'Pending';
    return 'Status: ${session['status']}';
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({
    required this.title,
    required this.done,
    required this.active,
    required this.subtitle,
    this.action,
    this.extra,
  });

  final String title;
  final bool done;
  final bool active;
  final String subtitle;
  final Widget? action;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    final color = done
        ? Colors.green
        : active
            ? Theme.of(context).colorScheme.primary
            : Colors.grey;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(done ? Icons.check_circle : Icons.radio_button_off, color: color),
                const SizedBox(width: 8),
                Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
              ],
            ),
            const SizedBox(height: 8),
            Text(subtitle),
            if (action != null) ...[const SizedBox(height: 12), action!],
            if (extra != null) extra!,
          ],
        ),
      ),
    );
  }
}

class _CheckList extends StatelessWidget {
  const _CheckList({required this.session});

  final Map<String, dynamic> session;

  @override
  Widget build(BuildContext context) {
    final checks = (session['checks'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    if (checks.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        const Text('Checks', style: TextStyle(fontWeight: FontWeight.bold)),
        ...checks.map(
          (c) => ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text('${c['check_type']} — ${c['status']}'),
            subtitle: Text('result: ${c['result_code'] ?? '-'}'),
          ),
        ),
      ],
    );
  }
}
