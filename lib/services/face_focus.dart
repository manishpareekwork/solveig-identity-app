import 'dart:math' as math;
import 'dart:ui';

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// Shared oval guide geometry — matches [FaceCaptureScreen] preview overlay.
class FaceFocusGuide {
  static Rect focusRect(Size size) {
    return Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.42),
      width: size.width * 0.72,
      height: size.height * 0.55,
    );
  }

  /// Pick the subject in the oval; ignore smaller background faces.
  static Face? selectPrimaryFace(List<Face> faces, Size imageSize) {
    if (faces.isEmpty) return null;
    if (faces.length == 1) return faces.first;

    final focus = focusRect(imageSize);
    final ranked = [...faces]..sort((a, b) {
        return _score(b, focus).compareTo(_score(a, focus));
      });

    final primary = ranked.first;
    final primaryArea = primary.boundingBox.width * primary.boundingBox.height;
    if (primaryArea <= 0) return primary;

    final competitors = ranked.skip(1).where((face) {
      final box = face.boundingBox;
      final area = box.width * box.height;
      if (area < primaryArea * 0.22) return false;
      final inFocus = overlapRatio(box, focus) > 0.28 || focus.contains(box.center);
      return inFocus;
    }).length;

    if (competitors > 0) return null;
    return primary;
  }

  static double _score(Face face, Rect focus) {
    final box = face.boundingBox;
    final area = box.width * box.height;
    final overlap = overlapRatio(box, focus);
    final centerInside = focus.contains(box.center) ? 1.0 : 0.0;
    final dist = (box.center - focus.center).distance;
    final distPenalty = 1 / (1 + dist / math.max(focus.width, 1));
    return area * (0.35 + overlap * 0.45 + centerInside * 0.2) * distPenalty;
  }

  static double overlapRatio(Rect face, Rect focus) {
    final inter = face.intersect(focus);
    if (inter.isEmpty) return 0;
    final interArea = inter.width * inter.height;
    return interArea / (face.width * face.height);
  }
}
