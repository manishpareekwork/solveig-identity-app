import 'dart:convert';
import 'dart:typed_data';

/// Primary still sent for face match; optional burst for active blink liveness.
class FaceCapturePayload {
  const FaceCapturePayload({
    required this.primary,
    this.livenessFramesBase64 = const [],
  });

  final Uint8List primary;
  final List<String> livenessFramesBase64;

  static FaceCapturePayload fromPrimary(Uint8List bytes) =>
      FaceCapturePayload(primary: bytes);

  static FaceCapturePayload fromParts({
    required Uint8List primary,
    required List<Uint8List> frames,
  }) =>
      FaceCapturePayload(
        primary: primary,
        livenessFramesBase64: frames.map((f) => base64Encode(f)).toList(growable: false),
      );
}
