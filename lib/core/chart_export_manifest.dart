import 'dart:convert';
import 'dart:typed_data';

import 'chart_export.dart';
import 'chart_export_delivery.dart';
import 'chart_export_filename.dart';

class ChartExportManifest {
  const ChartExportManifest._();

  static const String mimeType = 'application/json';
  static const String schemaVersion = '1.0';
  static const String defaultExportFilename = 'chart_export_manifest';
  static const String defaultDeliveryFilename = 'chart_delivery_manifest';

  static Map<String, Object?> exportBatchMetadata(
    ChartExportBatchResult batch, {
    DateTime? createdAt,
    bool includePayload = false,
  }) {
    return {
      'kind': 'chartExportBatch',
      'schemaVersion': schemaVersion,
      'createdAt': _timestamp(createdAt),
      'batch': batch.toMetadataJson(includePayload: includePayload),
    };
  }

  static String exportBatchJson(
    ChartExportBatchResult batch, {
    DateTime? createdAt,
    bool includePayload = false,
    bool pretty = true,
  }) {
    return _encode(
      exportBatchMetadata(
        batch,
        createdAt: createdAt,
        includePayload: includePayload,
      ),
      pretty: pretty,
    );
  }

  static ChartExportFile exportBatchFile(
    ChartExportBatchResult batch, {
    String filename = defaultExportFilename,
    DateTime? createdAt,
    bool includePayload = false,
    bool pretty = true,
  }) {
    final resolvedCreatedAt = createdAt ?? DateTime.now();
    final metadata = exportBatchMetadata(
      batch,
      createdAt: resolvedCreatedAt,
      includePayload: includePayload,
    );
    final fileMetadata = includePayload
        ? exportBatchMetadata(batch, createdAt: resolvedCreatedAt)
        : metadata;
    final text = _encode(metadata, pretty: pretty);
    return _file(filename: filename, text: text, metadata: fileMetadata);
  }

  static Map<String, Object?> deliveryBatchMetadata(
    ChartExportDeliveryBatchResult batch, {
    DateTime? createdAt,
    bool includePayload = false,
  }) {
    return {
      'kind': 'chartExportDeliveryBatch',
      'schemaVersion': schemaVersion,
      'createdAt': _timestamp(createdAt),
      'batch': batch.toMetadataJson(includePayload: includePayload),
    };
  }

  static String deliveryBatchJson(
    ChartExportDeliveryBatchResult batch, {
    DateTime? createdAt,
    bool includePayload = false,
    bool pretty = true,
  }) {
    return _encode(
      deliveryBatchMetadata(
        batch,
        createdAt: createdAt,
        includePayload: includePayload,
      ),
      pretty: pretty,
    );
  }

  static ChartExportFile deliveryBatchFile(
    ChartExportDeliveryBatchResult batch, {
    String filename = defaultDeliveryFilename,
    DateTime? createdAt,
    bool includePayload = false,
    bool pretty = true,
  }) {
    final resolvedCreatedAt = createdAt ?? DateTime.now();
    final metadata = deliveryBatchMetadata(
      batch,
      createdAt: resolvedCreatedAt,
      includePayload: includePayload,
    );
    final fileMetadata = includePayload
        ? deliveryBatchMetadata(batch, createdAt: resolvedCreatedAt)
        : metadata;
    final text = _encode(metadata, pretty: pretty);
    return _file(filename: filename, text: text, metadata: fileMetadata);
  }

  static ChartExportFile _file({
    required String filename,
    required String text,
    required Map<String, Object?> metadata,
  }) {
    return ChartExportFile(
      filename: ChartExportFilename.withExtension(filename, 'json'),
      mimeType: mimeType,
      bytes: Uint8List.fromList(utf8.encode(text)),
      text: text,
      metadata: metadata,
    );
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
