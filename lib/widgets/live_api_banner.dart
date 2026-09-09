import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// Small banner: verification uses remote in-house API, not on-device matching.
class LiveApiBanner extends StatelessWidget {
  const LiveApiBanner({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.accent.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(compact ? 10 : 12),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 12, vertical: compact ? 8 : 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.cloud_done_outlined, size: compact ? 18 : 20, color: AppTheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                compact
                    ? 'Live in-house API — match & liveness on server, not on this device.'
                    : 'Live API verification — face match and liveness are processed on the '
                        'in-house identity API. This device only captures camera '
                        'frames; no static on-device template matching.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.primaryDark,
                      height: 1.35,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
