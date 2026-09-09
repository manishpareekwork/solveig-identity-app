import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'identity_api_client.dart';

/// Formats and surfaces full API failure context for debugging.
class ApiErrorDetail {
  const ApiErrorDetail({
    required this.summary,
    required this.fullLog,
    this.correlationId,
    this.endpoint,
    this.statusCode,
    this.code,
  });

  final String summary;
  final String fullLog;
  final String? correlationId;
  final String? endpoint;
  final int? statusCode;
  final String? code;

  factory ApiErrorDetail.fromException(ApiException e) {
    final log = e.fullLog;
    if (kDebugMode) {
      debugPrint('=== In-house API error ===\n$log');
    }
    return ApiErrorDetail(
      summary: e.message,
      fullLog: log,
      correlationId: e.correlationId,
      endpoint: e.endpoint,
      statusCode: e.statusCode,
      code: e.code,
    );
  }

  factory ApiErrorDetail.fromUnknown(Object e, {String? context}) {
    final log = [
      if (context != null) 'Context: $context',
      'Type: ${e.runtimeType}',
      'Message: $e',
    ].join('\n');
    if (kDebugMode) {
      debugPrint('=== App error ===\n$log');
    }
    return ApiErrorDetail(summary: e.toString(), fullLog: log);
  }

  Future<void> copyToClipboard() => Clipboard.setData(ClipboardData(text: fullLog));
}
