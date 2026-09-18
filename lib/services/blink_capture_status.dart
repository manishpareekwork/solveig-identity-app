enum BlinkCapturePhase {
  starting,
  frameCaptured,
  checkingBlink,
  blinkDetected,
  selectingBestFrame,
  done,
  failedNoBlink,
  failedQuality,
}

class BlinkCaptureStatus {
  const BlinkCaptureStatus({
    required this.phase,
    required this.message,
    this.framesDone = 0,
    this.framesTotal = 4,
  });

  final BlinkCapturePhase phase;
  final String message;
  final int framesDone;
  final int framesTotal;

  double get progress {
    if (framesTotal <= 0) return 0;
    switch (phase) {
      case BlinkCapturePhase.starting:
        return 0.05;
      case BlinkCapturePhase.frameCaptured:
        return (framesDone / framesTotal).clamp(0.1, 0.85);
      case BlinkCapturePhase.checkingBlink:
        return 0.88;
      case BlinkCapturePhase.blinkDetected:
        return 0.92;
      case BlinkCapturePhase.selectingBestFrame:
        return 0.96;
      case BlinkCapturePhase.done:
        return 1.0;
      case BlinkCapturePhase.failedNoBlink:
      case BlinkCapturePhase.failedQuality:
        return framesDone / framesTotal;
    }
  }
}

typedef BlinkCaptureProgressCallback = void Function(BlinkCaptureStatus status);
