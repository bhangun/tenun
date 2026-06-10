import 'package:flutter/widgets.dart';

import 'base_config.dart';
import 'chart_export_format.dart';

class ChartExportCapability {
  const ChartExportCapability({
    required this.format,
    required this.canExport,
    this.disabledReason,
  });

  factory ChartExportCapability.available(ChartExportFormat format) {
    return ChartExportCapability(format: format, canExport: true);
  }

  factory ChartExportCapability.unavailable(
    ChartExportFormat format,
    String disabledReason,
  ) {
    return ChartExportCapability(
      format: format,
      canExport: false,
      disabledReason: disabledReason,
    );
  }

  final ChartExportFormat format;
  final bool canExport;
  final String? disabledReason;

  bool get isUnavailable => !canExport;

  Map<String, Object?> toMetadataJson() {
    return {
      'format': format.name,
      'canExport': canExport,
      if (disabledReason != null) 'disabledReason': disabledReason,
    };
  }
}

class ChartExportCapabilities {
  ChartExportCapabilities(Iterable<ChartExportCapability> capabilities)
    : capabilities = List.unmodifiable(capabilities),
      _byFormat = Map.unmodifiable({
        for (final capability in capabilities) capability.format: capability,
      });

  factory ChartExportCapabilities.evaluate({
    Iterable<ChartExportFormat> formats = ChartExportFormat.values,
    BaseChartConfig? config,
    Map<String, dynamic>? jsonConfig,
    List<List<Object?>>? rows,
    GlobalKey? boundaryKey,
  }) {
    final uniqueFormats = <ChartExportFormat>[];
    for (final format in formats) {
      if (!uniqueFormats.contains(format)) uniqueFormats.add(format);
    }

    final hasDataSource = config != null || jsonConfig != null || rows != null;
    final hasBoundaryKey = boundaryKey != null;
    return ChartExportCapabilities(
      uniqueFormats.map(
        (format) => evaluateFormat(
          format,
          hasDataSource: hasDataSource,
          hasBoundaryKey: hasBoundaryKey,
        ),
      ),
    );
  }

  final List<ChartExportCapability> capabilities;
  final Map<ChartExportFormat, ChartExportCapability> _byFormat;

  List<ChartExportFormat> get formats =>
      List.unmodifiable(capabilities.map((capability) => capability.format));

  List<ChartExportFormat> get exportableFormats => List.unmodifiable(
    capabilities
        .where((capability) => capability.canExport)
        .map((capability) => capability.format),
  );

  List<ChartExportFormat> get unavailableFormats => List.unmodifiable(
    capabilities
        .where((capability) => capability.isUnavailable)
        .map((capability) => capability.format),
  );

  bool get hasExportableFormats => exportableFormats.isNotEmpty;

  bool canExport(ChartExportFormat format) {
    return _byFormat[format]?.canExport ?? false;
  }

  String? disabledReason(ChartExportFormat format) {
    return _byFormat[format]?.disabledReason;
  }

  ChartExportCapability capabilityFor(ChartExportFormat format) {
    return _byFormat[format] ??
        ChartExportCapability.unavailable(
          format,
          'Format ${format.name} was not included in this export capability set.',
        );
  }

  Map<String, Object?> toMetadataJson() {
    return {
      'formats': [for (final format in formats) format.name],
      'exportableFormats': [
        for (final format in exportableFormats) format.name,
      ],
      'unavailableFormats': [
        for (final format in unavailableFormats) format.name,
      ],
      'capabilities': [
        for (final capability in capabilities) capability.toMetadataJson(),
      ],
    };
  }

  static ChartExportCapability evaluateFormat(
    ChartExportFormat format, {
    required bool hasDataSource,
    required bool hasBoundaryKey,
  }) {
    final reason = disabledReasonFor(
      format,
      hasDataSource: hasDataSource,
      hasBoundaryKey: hasBoundaryKey,
    );
    return reason == null
        ? ChartExportCapability.available(format)
        : ChartExportCapability.unavailable(format, reason);
  }

  static String? disabledReasonFor(
    ChartExportFormat format, {
    required bool hasDataSource,
    required bool hasBoundaryKey,
  }) {
    return switch (format) {
      ChartExportFormat.csv when !hasDataSource =>
        'CSV export requires a chart config, JSON payload, or rows.',
      ChartExportFormat.xlsx when !hasDataSource =>
        'XLSX export requires a chart config, JSON payload, or rows.',
      ChartExportFormat.png when !hasBoundaryKey =>
        'PNG export requires a repaint boundary key.',
      ChartExportFormat.jpeg when !hasBoundaryKey =>
        'JPEG export requires a repaint boundary key.',
      _ => null,
    };
  }
}
