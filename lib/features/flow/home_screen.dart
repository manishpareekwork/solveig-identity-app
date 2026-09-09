import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../state/app_state.dart';
import '../../services/api_error_detail.dart';
import '../../widgets/api_error_panel.dart';
import '../../utils/view_insets.dart';
import '../../widgets/live_api_banner.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _openLiveVerify(BuildContext context, AppState state) async {
    final bytes = await context.push<Uint8List>(
      '/capture',
      extra: {
        'title': 'Live verify',
        'subtitle':
            'Capture your face now. The app will compare against ${state.registeredProfileCount} registered profile${state.registeredProfileCount == 1 ? '' : 's'} on this device.',
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
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Identity Verification'),
        actions: [
          IconButton(icon: const Icon(Icons.settings), onPressed: () => context.go('/setup')),
        ],
      ),
      body: Padding(
        padding: screenPadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const LiveApiBanner(),
            const SizedBox(height: 20),
            Text(
              'Register multiple faces, then verify live against all profiles on this device.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 28),
            _ChoiceTile(
              icon: Icons.person_add_alt_1,
              title: 'Register face',
              subtitle: state.hasRegisteredProfiles
                  ? 'Add profile ${state.registeredProfileCount + 1} — create identity and enroll with live camera.'
                  : 'Create identity and enroll your first face with live camera.',
              accent: AppTheme.accent,
              onTap: () async {
                await state.beginRegisterFlow();
                if (!context.mounted) return;
                context.go('/flow');
              },
            ),
            const SizedBox(height: 16),
            _ChoiceTile(
              icon: Icons.videocam,
              title: 'Verify live',
              subtitle: state.hasRegisteredProfiles
                  ? 'Live camera capture — match against ${state.registeredProfileCount} registered profile${state.registeredProfileCount == 1 ? '' : 's'}.'
                  : 'Register at least one face first.',
              accent: AppTheme.success,
              onTap: state.hasRegisteredProfiles ? () => _openLiveVerify(context, state) : null,
            ),
            if (state.hasRegisteredProfiles) ...[
              const SizedBox(height: 20),
              Text('Registered profiles (${state.registeredProfileCount})',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              ...state.registeredProfiles.map(
                (p) => _ProfileChip(label: p.label, identityId: p.identityId),
              ),
            ],
            const SizedBox(height: 16),
            _ChoiceTile(
              icon: Icons.list_alt_rounded,
              title: 'Manual API steps',
              subtitle: 'Walk through each API step one at a time (create, enroll, QR, session, verify).',
              accent: const Color(0xFFA78BFA),
              onTap: () {
                state.setManualMode(true);
                context.go('/flow');
              },
            ),
            if (state.errorDetail != null) ...[
              const SizedBox(height: 20),
              ApiErrorPanel(detail: state.errorDetail!),
            ] else if (state.error != null) ...[
              const SizedBox(height: 20),
              ApiErrorPanel(
                detail: ApiErrorDetail(summary: state.error!, fullLog: state.error!),
              ),
            ],
            const Spacer(),
            Text(
              'Development API · ${state.baseUrl.replaceAll('https://', '')}',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileChip extends StatelessWidget {
  const _ProfileChip({required this.label, required this.identityId});

  final String label;
  final String identityId;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(12),
        child: ListTile(
          dense: true,
          leading: const Icon(Icons.face, color: AppTheme.primary),
          title: Text(label),
          subtitle: Text(identityId, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.card,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(alpha: onTap == null ? 0.08 : 0.2),
                ),
                child: Icon(icon, size: 32, color: onTap == null ? Colors.grey : AppTheme.primaryDark),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: onTap == null ? Colors.grey : null),
            ],
          ),
        ),
      ),
    );
  }
}
