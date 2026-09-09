import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// Branded loading panel — oval pulse like the face-capture screen (no spinner).
class IdentityLoadingPanel extends StatefulWidget {
  const IdentityLoadingPanel({
    super.key,
    required this.message,
    this.height = 220,
  });

  final String message;
  final double height;

  @override
  State<IdentityLoadingPanel> createState() => _IdentityLoadingPanelState();
}

class _IdentityLoadingPanelState extends State<IdentityLoadingPanel> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: widget.height,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Container(
              color: AppTheme.primaryDark,
              child: AnimatedBuilder(
                animation: _pulse,
                builder: (context, _) {
                  final t = Curves.easeInOut.transform(_pulse.value);
                  final stroke = 2.5 + t * 1.5;
                  final glow = 0.35 + t * 0.45;
                  return CustomPaint(
                    painter: _PulsingOvalPainter(strokeWidth: stroke, glowAlpha: glow),
                    child: Center(
                      child: Icon(
                        Icons.face_retouching_natural,
                        size: 48,
                        color: AppTheme.accent.withValues(alpha: 0.55 + t * 0.35),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          widget.message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppTheme.primaryDark),
        ),
        const SizedBox(height: 6),
        Text(
          'In-house API · live verification',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class IdentityLoadingOverlay extends StatelessWidget {
  const IdentityLoadingOverlay({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.45),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              elevation: 8,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
                child: IdentityLoadingPanel(message: message),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PulsingOvalPainter extends CustomPainter {
  _PulsingOvalPainter({required this.strokeWidth, required this.glowAlpha});

  final double strokeWidth;
  final double glowAlpha;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.width * 0.52,
      height: size.height * 0.62,
    );
    final glow = Paint()
      ..color = AppTheme.accent.withValues(alpha: glowAlpha * 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + 6
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawOval(rect, glow);
    final stroke = Paint()
      ..color = AppTheme.accent.withValues(alpha: glowAlpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawOval(rect, stroke);
  }

  @override
  bool shouldRepaint(covariant _PulsingOvalPainter oldDelegate) =>
      oldDelegate.strokeWidth != strokeWidth || oldDelegate.glowAlpha != glowAlpha;

}
