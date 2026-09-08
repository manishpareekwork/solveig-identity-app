import 'package:flutter/material.dart';

enum AppButtonVariant { filled, outline, text }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.variant = AppButtonVariant.filled,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final AppButtonVariant variant;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
        Text(label),
      ],
    );

    final Widget button;
    switch (variant) {
      case AppButtonVariant.filled:
        button = FilledButton(onPressed: onPressed, child: child);
      case AppButtonVariant.outline:
        button = OutlinedButton(onPressed: onPressed, child: child);
      case AppButtonVariant.text:
        button = TextButton(onPressed: onPressed, child: child);
    }

    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}
