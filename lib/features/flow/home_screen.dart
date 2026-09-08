import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../state/app_state.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Solveig Identity'),
        actions: [
          IconButton(icon: const Icon(Icons.settings), onPressed: () => context.go('/setup')),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Verify an identity against the platform API.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 28),
            _ChoiceTile(
              icon: Icons.bolt_rounded,
              title: 'Quick flow',
              subtitle: 'Create identity → enroll → verify with minimal taps. QR and session run automatically.',
              accent: AppTheme.accent,
              onTap: state.loading
                  ? null
                  : () async {
                      state.setManualMode(false);
                      await state.startQuickFlow();
                      if (context.mounted && state.error == null) {
                        context.go('/flow');
                      }
                    },
            ),
            const SizedBox(height: 16),
            _ChoiceTile(
              icon: Icons.list_alt_rounded,
              title: 'Manual steps',
              subtitle: 'Walk through each API step one at a time (create, enroll, QR, session, verify).',
              accent: const Color(0xFFA78BFA),
              onTap: () {
                state.setManualMode(true);
                context.go('/flow');
              },
            ),
            if (state.error != null) ...[
              const SizedBox(height: 20),
              Text(state.error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
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
                  color: accent.withValues(alpha: 0.2),
                ),
                child: Icon(icon, size: 32, color: AppTheme.primaryDark),
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
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
