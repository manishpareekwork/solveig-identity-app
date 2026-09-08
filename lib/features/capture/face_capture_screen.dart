import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/theme/app_theme.dart';
import '../../services/face_capture_quality.dart';
import '../../widgets/app_button.dart';
import '../../widgets/live_api_banner.dart';

class FaceCaptureScreen extends StatefulWidget {
  const FaceCaptureScreen({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  State<FaceCaptureScreen> createState() => _FaceCaptureScreenState();
}

class _FaceCaptureScreenState extends State<FaceCaptureScreen> {
  CameraController? _controller;
  final _quality = FaceCaptureQualityService();
  bool _initializing = true;
  String? _error;
  String? _qualityHint;
  bool _capturing = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      setState(() {
        _error = 'Camera permission is required.';
        _initializing = false;
      });
      return;
    }

    try {
      final cameras = await availableCameras();
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        front,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _initializing = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Could not open camera: $e';
        _initializing = false;
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _quality.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _capturing) return;

    setState(() {
      _capturing = true;
      _qualityHint = null;
    });
    try {
      final file = await controller.takePicture();
      var bytes = Uint8List.fromList(await file.readAsBytes());
      bytes = await normalizeCaptureBytes(bytes);

      final issue = await _quality.validateBytes(bytes);
      if (issue != null) {
        if (mounted) {
          setState(() => _qualityHint = '${issue.title}: ${issue.message}');
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(issue.message)));
        }
        return;
      }

      if (!mounted) return;
      context.pop(bytes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Capture failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: LiveApiBanner(compact: true),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(widget.subtitle, style: Theme.of(context).textTheme.bodyMedium),
          ),
          if (_qualityHint != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Material(
                color: AppTheme.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(_qualityHint!, style: const TextStyle(color: AppTheme.error)),
                ),
              ),
            ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              'Tips: one face only · open eyes · no mask · even lighting · specs OK if eyes visible',
              style: TextStyle(fontSize: 12),
            ),
          ),
          Expanded(child: _buildPreview()),
          Padding(
            padding: const EdgeInsets.all(20),
            child: AppButton(
              label: _capturing ? 'Checking…' : 'Capture & send to API',
              icon: Icons.camera,
              onPressed: _capturing || _controller == null ? null : _capture,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    if (_initializing) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!)));
    }
    final controller = _controller!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CameraPreview(controller),
            CustomPaint(painter: _FaceOvalPainter()),
            Positioned(
              left: 0,
              right: 0,
              bottom: 16,
              child: Text(
                'Align face in oval — quality checked locally, match on API',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white,
                      shadows: const [Shadow(color: Colors.black54, blurRadius: 6)],
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FaceOvalPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.42),
      width: size.width * 0.72,
      height: size.height * 0.55,
    );
    final paint = Paint()
      ..color = AppTheme.accent.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawOval(rect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
