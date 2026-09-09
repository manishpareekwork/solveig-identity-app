import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_theme.dart';
import '../services/api_error_detail.dart';

/// Shows a short summary plus expandable full error log (copyable).
class ApiErrorPanel extends StatefulWidget {
  const ApiErrorPanel({super.key, required this.detail});

  final ApiErrorDetail detail;

  @override
  State<ApiErrorPanel> createState() => _ApiErrorPanelState();
}

class _ApiErrorPanelState extends State<ApiErrorPanel> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final d = widget.detail;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.error.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.error_outline, color: AppTheme.error, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(d.summary, style: const TextStyle(color: AppTheme.error))),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton.icon(
                onPressed: () => setState(() => _expanded = !_expanded),
                icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more, size: 18),
                label: Text(_expanded ? 'Hide details' : 'Show full error log'),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () async {
                  await d.copyToClipboard();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Error log copied — paste it in chat')),
                    );
                  }
                },
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('Copy'),
              ),
            ],
          ),
          if (_expanded) ...[
            const SizedBox(height: 4),
            SelectableText(
              d.fullLog,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}
