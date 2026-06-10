import 'chart_export.dart';
import 'chart_export_delivery.dart';

extension ChartExportBatchSummary on ChartExportBatchResult {
  List<String> get skippedUnavailableMessages => List.unmodifiable(
    skippedUnavailable.map(
      (capability) =>
          '${capability.format.name.toUpperCase()}: ${capability.disabledReason ?? 'Unavailable.'}',
    ),
  );

  String summaryText({bool includeSize = true}) {
    final parts = <String>[];

    if (hasFailures) {
      parts.add(
        '$failureCount of $requestedCount ${_plural('export', requestedCount)} failed',
      );
    } else if (successCount > 0) {
      final size = includeSize ? ' (${_formatBytes(totalSizeBytes)})' : '';
      parts.add('$successCount ${_plural('export', successCount)} ready$size');
    } else if (hasSkippedUnavailable) {
      parts.add('No exports produced');
    } else {
      parts.add('No exports requested');
    }

    if (skippedUnavailableCount > 0) {
      parts.add(
        '$skippedUnavailableCount unavailable ${_plural('format', skippedUnavailableCount)} skipped',
      );
    }
    if (notRunCount > 0) {
      parts.add('$notRunCount ${_plural('export', notRunCount)} not run');
    }

    return parts.join('; ');
  }
}

extension ChartExportDeliveryBatchSummary on ChartExportDeliveryBatchResult {
  String summaryText({bool includeSize = true}) {
    if (results.isEmpty) return 'No deliveries requested';
    if (hasFailures) {
      return '$failureCount of ${results.length} ${_plural('delivery', results.length)} failed';
    }

    final size = includeSize ? ' (${_formatBytes(totalSizeBytes)})' : '';
    return '$successCount ${_plural('file', successCount)} delivered$size';
  }
}

String _plural(String singular, int count) {
  if (count == 1) return singular;
  return switch (singular) {
    'delivery' => 'deliveries',
    _ => '${singular}s',
  };
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
