import 'dart:convert';
import 'dart:typed_data';

import 'chart_export_delivery.dart';
import 'chart_export_filename.dart';
import 'chart_export_job.dart';
import 'chart_export_manifest.dart';

class ChartExportJobManifest {
  const ChartExportJobManifest._();

  static const String mimeType = ChartExportManifest.mimeType;
  static const String kind = 'chartExportJob';
  static const String defaultFilename = 'chart_export_job_manifest';

  static Map<String, Object?> metadata(
    ChartExportJobResult job, {
    DateTime? createdAt,
    bool includePayload = false,
    bool includeOutputFiles = true,
  }) {
    return {
      'kind': kind,
      'schemaVersion': ChartExportManifest.schemaVersion,
      'createdAt': _timestamp(createdAt),
      'summary': _summary(job),
      'job': job.toMetadataJson(includePayload: includePayload),
      if (includeOutputFiles)
        'outputs': [
          for (final file in job.outputFiles)
            file.toMetadataJson(includePayload: includePayload),
        ],
    };
  }

  static String json(
    ChartExportJobResult job, {
    DateTime? createdAt,
    bool includePayload = false,
    bool includeOutputFiles = true,
    bool pretty = true,
  }) {
    return _encode(
      metadata(
        job,
        createdAt: createdAt,
        includePayload: includePayload,
        includeOutputFiles: includeOutputFiles,
      ),
      pretty: pretty,
    );
  }

  static ChartExportFile file(
    ChartExportJobResult job, {
    String filename = defaultFilename,
    DateTime? createdAt,
    bool includePayload = false,
    bool includeOutputFiles = true,
    bool pretty = true,
  }) {
    final resolvedCreatedAt = createdAt ?? DateTime.now();
    final fullMetadata = metadata(
      job,
      createdAt: resolvedCreatedAt,
      includePayload: includePayload,
      includeOutputFiles: includeOutputFiles,
    );
    final fileMetadata = includePayload
        ? metadata(
            job,
            createdAt: resolvedCreatedAt,
            includeOutputFiles: includeOutputFiles,
          )
        : fullMetadata;
    final text = _encode(fullMetadata, pretty: pretty);
    return ChartExportFile(
      filename: ChartExportFilename.withExtension(filename, 'json'),
      mimeType: mimeType,
      bytes: Uint8List.fromList(utf8.encode(text)),
      text: text,
      metadata: fileMetadata,
    );
  }

  static Map<String, Object?> _summary(ChartExportJobResult job) {
    return {
      'success': job.success,
      'status': job.status.name,
      'statusText': job.statusText,
      'completed': job.completed,
      'preflightBlocked': job.preflightBlocked,
      'cancelled': job.isCancelled,
      'hasOutput': job.hasOutput,
      'outputCount': job.outputCount,
      'outputFilenames': job.outputFilenames,
      'hasIssues': job.hasIssues,
      'issueCount': job.issueCount,
      if (job.primaryIssue != null) 'primaryIssue': job.primaryIssue,
      'totalSizeBytes': job.totalSizeBytes,
      if (job.duration != null) 'durationMicros': job.duration!.inMicroseconds,
      if (job.duration != null)
        'durationMs': job.duration!.inMicroseconds / 1000,
    };
  }

  static String _encode(Map<String, Object?> metadata, {required bool pretty}) {
    final JsonEncoder encoder = pretty
        ? const JsonEncoder.withIndent('  ')
        : const JsonEncoder();
    return encoder.convert(metadata);
  }

  static String _timestamp(DateTime? value) {
    return (value ?? DateTime.now()).toUtc().toIso8601String();
  }
}
