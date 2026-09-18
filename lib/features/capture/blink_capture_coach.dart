import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../services/blink_capture_status.dart';

/// Looping “open → blink → open” guide before capture starts.
class BlinkCoachAnimation extends StatefulWidget {
  const BlinkCoachAnimation({super.key});

  @override
  State<BlinkCoachAnimation> createState() => _BlinkCoachAnimationState();
}

class _BlinkCoachAnimationState extends State<BlinkCoachAnimation> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        // 0–0.35 open, 0.35–0.55 closed, 0.55–1 open
        final openness = t < 0.35
            ? 1.0
            : t < 0.55
                ? 1.0 - ((t - 0.35) / 0.2)
                : ((t - 0.55) / 0.45).clamp(0.0, 1.0);
        return CustomPaint(
          size: const Size(72, 72),
          painter: _BlinkFacePainter(openness: openness),
        );
      },
    );
  }
}

class _BlinkFacePainter extends CustomPainter {
  _BlinkFacePainter({required this.openness});

  final double openness;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final faceR = size.width * 0.38;
    final face = Paint()
      ..color = AppTheme.accent.withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy), faceR, face);

    final stroke = Paint()
      ..color = AppTheme.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawCircle(Offset(cx, cy), faceR, stroke);

    final eyeY = cy - faceR * 0.15;
    final eyeDx = faceR * 0.45;
    final lidH = (1.0 - openness.clamp(0.0, 1.0)) * faceR * 0.35;

    for (final sign in [-1.0, 1.0]) {
      final ex = cx + sign * eyeDx;
      canvas.drawOval(
        Rect.fromCenter(center: Offset(ex, eyeY), width: faceR * 0.28, height: faceR * 0.18),
        stroke,
      );
      final lid = Paint()..color = AppTheme.accent.withValues(alpha: 0.85);
      canvas.drawRect(
        Rect.fromLTWH(ex - faceR * 0.16, eyeY - faceR * 0.12, faceR * 0.32, lidH),
        lid,
      );
    }

    canvas.drawArc(
      Rect.fromCenter(center: Offset(cx, cy + faceR * 0.25), width: faceR * 0.5, height: faceR * 0.25),
      0.1,
      3.0,
      false,
      stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _BlinkFacePainter oldDelegate) => oldDelegate.openness != openness;
}

class BlinkCaptureProgressPanel extends StatelessWidget {
  const BlinkCaptureProgressPanel({
    super.key,
    required this.status,
  });

  final BlinkCaptureStatus status;

  @override
  Widget build(BuildContext context) {
    final steps = [
      _StepDef('Face in oval', _stepDone(BlinkCapturePhase.frameCaptured)),
      _StepDef('Blink detected', _stepDone(BlinkCapturePhase.blinkDetected)),
      _StepDef('Face captured', _stepDone(BlinkCapturePhase.done)),
    ];

    return Material(
      color: Colors.black.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              status.message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: status.progress,
                minHeight: 8,
                backgroundColor: Colors.white24,
                color: AppTheme.accent,
              ),
            ),
            if (status.phase == BlinkCapturePhase.frameCaptured) ...[
              const SizedBox(height: 6),
              Text(
                'Frame ${status.framesDone} of ${status.framesTotal}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
            const SizedBox(height: 14),
            ...steps.map(
              (s) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(
                      s.done ? Icons.check_circle : Icons.radio_button_unchecked,
                      size: 20,
                      color: s.done ? AppTheme.success : Colors.white54,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        s.label,
                        style: TextStyle(
                          color: s.done ? Colors.white : Colors.white70,
                          fontWeight: s.done ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _stepDone(BlinkCapturePhase threshold) {
    const order = BlinkCapturePhase.values;
    return order.indexOf(status.phase) >= order.indexOf(threshold);
  }
}

class _StepDef {
  const _StepDef(this.label, this.done);
  final String label;
  final bool done;
}

class BlinkCoachInstructions extends StatelessWidget {
  const BlinkCoachInstructions({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(
                width: 72,
                height: 72,
                child: BlinkCoachAnimation(),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Center face in oval → tap Start → blink once → hold still until Done.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
