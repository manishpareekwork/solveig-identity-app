// Client-side face capture quality checks (ML Kit) before sending frames to the API.

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import 'face_focus.dart';

class FaceCaptureQualityIssue {
  const FaceCaptureQualityIssue(this.title, this.message, {this.code = 'quality'});

  final String title;
  final String message;
  final String code;
}

class FaceCaptureResult {
  const FaceCaptureResult({this.issue, this.preparedBytes});

  final FaceCaptureQualityIssue? issue;
  final Uint8List? preparedBytes;

  bool get ok => issue == null && preparedBytes != null;
}

class FaceCaptureQualityService {
  FaceCaptureQualityService()
      : _detector = FaceDetector(
          options: FaceDetectorOptions(
            performanceMode: FaceDetectorMode.accurate,
            enableClassification: true,
            enableLandmarks: true,
          ),
        );

  final FaceDetector _detector;

  Future<void> dispose() => _detector.close();

  Future<FaceCaptureResult> prepareCapture(Uint8List bytes) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/solveig_capture_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await file.writeAsBytes(bytes, flush: true);
    try {
      final faces = await _detector.processImage(InputImage.fromFilePath(file.path));
      final decoded = img.decodeImage(bytes);
      final imageSize = decoded != null
          ? Size(decoded.width.toDouble(), decoded.height.toDouble())
          : Size.zero;

      final issue = _evaluate(faces, bytes, imageSize);
      if (issue != null) {
        return FaceCaptureResult(issue: issue);
      }

      final primary = FaceFocusGuide.selectPrimaryFace(faces, imageSize) ?? faces.first;
      final prepared = _cropToFace(bytes, primary.boundingBox);
      return FaceCaptureResult(preparedBytes: prepared);
    } finally {
      try {
        await file.delete();
      } catch (_) {}
    }
  }

  FaceCaptureQualityIssue? _evaluate(List<Face> faces, Uint8List bytes, Size imageSize) {
    if (faces.isEmpty) {
      return const FaceCaptureQualityIssue(
        'No face detected',
        'Center your face in the oval with even lighting facing the camera.',
        code: 'no_face',
      );
    }

    final primary = FaceFocusGuide.selectPrimaryFace(faces, imageSize);
    if (primary == null) {
      return const FaceCaptureQualityIssue(
        'Multiple faces in focus',
        'Two faces appear in the oval — only you should be in the focus area.',
        code: 'multiple_faces',
      );
    }

    if (imageSize != Size.zero) {
      final focus = FaceFocusGuide.focusRect(imageSize);
      final overlap = FaceFocusGuide.overlapRatio(primary.boundingBox, focus);
      if (overlap < 0.08 && !focus.contains(primary.boundingBox.center)) {
      return const FaceCaptureQualityIssue(
        'Face not in oval',
        'Move your face into the oval — background people are ignored.',
        code: 'no_face',
      );
      }
    }

    return _evaluateFace(primary, bytes);
  }

  FaceCaptureQualityIssue? _evaluateFace(Face face, Uint8List bytes) {
    final yaw = (face.headEulerAngleY ?? 0).abs();
    final pitch = (face.headEulerAngleX ?? 0).abs();
    if (math.max(yaw, pitch) > 18) {
      return const FaceCaptureQualityIssue(
        'Face angle',
        'Look straight at the camera — frontal pose only (no sideways turns).',
        code: 'bad_pose',
      );
    }

    final left = face.leftEyeOpenProbability;
    final right = face.rightEyeOpenProbability;
    if (left != null && right != null) {
      final bestOpen = math.max(left, right);
      if (bestOpen < 0.38 && left < 0.18 && right < 0.18) {
        return const FaceCaptureQualityIssue(
          'Eyes closed',
          'Open your eyes and look at the camera. Remove sunglasses if worn.',
          code: 'eyes_closed',
        );
      }
    }

    final nose = face.landmarks[FaceLandmarkType.noseBase];
    final mouthL = face.landmarks[FaceLandmarkType.leftMouth];
    final mouthR = face.landmarks[FaceLandmarkType.rightMouth];
    final mouthB = face.landmarks[FaceLandmarkType.bottomMouth];
    if (nose == null || (mouthL == null && mouthR == null && mouthB == null)) {
      return const FaceCaptureQualityIssue(
        'Face obstructed',
        'Remove mask or anything covering your nose and mouth.',
        code: 'face_obstructed',
      );
    }

    try {
      final decoded = img.decodeImage(bytes);
      if (decoded != null) {
        final box = face.boundingBox;
        final ratio = (box.width * box.height) / (decoded.width * decoded.height);
        if (ratio < 0.05) {
          return const FaceCaptureQualityIssue(
            'Face too small',
            'Move closer to the camera or improve lighting.',
            code: 'face_too_small',
          );
        }

        final brightness = _averageFaceLuminance(decoded, box);
        if (brightness < 45) {
          return const FaceCaptureQualityIssue(
            'Too dark',
            'Find brighter, even lighting on your face.',
            code: 'poor_lighting',
          );
        }
        if (brightness > 220) {
          return const FaceCaptureQualityIssue(
            'Too bright',
            'Avoid strong backlight or washed-out lighting.',
            code: 'poor_lighting',
          );
        }
      }
    } catch (_) {
      // Non-fatal — still send to API.
    }

    return null;
  }

  Uint8List _cropToFace(Uint8List bytes, Rect box, {double padding = 0.18}) {
    try {
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return bytes;

      final padX = box.width * padding;
      final padY = box.height * padding;
      final x0 = (box.left - padX).clamp(0, decoded.width - 1).toInt();
      final y0 = (box.top - padY).clamp(0, decoded.height - 1).toInt();
      final x1 = (box.right + padX).clamp(0, decoded.width).toInt();
      final y1 = (box.bottom + padY).clamp(0, decoded.height).toInt();
      final w = math.max(1, x1 - x0);
      final h = math.max(1, y1 - y0);

      final cropped = img.copyCrop(decoded, x: x0, y: y0, width: w, height: h);
      return Uint8List.fromList(img.encodeJpg(cropped, quality: 88));
    } catch (_) {
      return bytes;
    }
  }

  double _averageFaceLuminance(img.Image decoded, Rect box) {
    final x0 = box.left.clamp(0, decoded.width - 1).toInt();
    final y0 = box.top.clamp(0, decoded.height - 1).toInt();
    final x1 = box.right.clamp(0, decoded.width).toInt();
    final y1 = box.bottom.clamp(0, decoded.height).toInt();
    if (x1 <= x0 || y1 <= y0) return 128;

    var sum = 0.0;
    var count = 0;
    for (var y = y0; y < y1; y += 2) {
      for (var x = x0; x < x1; x += 2) {
        final px = decoded.getPixel(x, y);
        sum += 0.299 * px.r + 0.587 * px.g + 0.114 * px.b;
        count++;
      }
    }
    return count == 0 ? 128 : sum / count;
  }
}

/// Normalize JPEG size before API upload for stabler stub matching.
Future<Uint8List> normalizeCaptureBytes(Uint8List bytes, {int maxWidth = 720}) async {
  try {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return bytes;
    if (decoded.width <= maxWidth) return bytes;
    final resized = img.copyResize(decoded, width: maxWidth);
    return Uint8List.fromList(img.encodeJpg(resized, quality: 88));
  } catch (_) {
    return bytes;
  }
}
