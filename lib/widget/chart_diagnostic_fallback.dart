import 'package:flutter/material.dart';

import '../core/chart_config_validator.dart';
import '../core/chart_payload_doctor.dart';
import '../core/data_shape_adapter.dart';
import '../core/tenun_options.dart';
import 'chart_diagnostic_fallback_options.dart';

export 'chart_diagnostic_fallback_options.dart';

class TenunInvalidPayloadFallback extends StatelessWidget {
  final TenunOptionBuildResult result;
  final Map<String, dynamic> rawPayload;
  final bool requireRegisteredType;
  final int validationReportMaxIssues;
  final String title;
  final String? message;
  final List<Widget> footerChildren;
  final bool showDoctorSummary;
  final bool showValidationDetails;
  final bool showErrorDetails;
  final bool showQuickFixes;
  final int maxQuickFixes;
  final TenunDiagnosticFallbackOptions? options;

  const TenunInvalidPayloadFallback({
    super.key,
    required this.result,
    required this.rawPayload,
    required this.requireRegisteredType,
    required this.validationReportMaxIssues,
    this.title = 'Invalid chart payload',
    this.message,
    this.footerChildren = const [],
    this.showDoctorSummary = true,
    this.showValidationDetails = true,
    this.showErrorDetails = true,
    this.showQuickFixes = true,
    this.maxQuickFixes = 3,
    this.options,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveTitle = options?.title ?? title;
    final effectiveMessage = options?.message ?? message ?? result.message;
    final effectiveFooter = options?.footerChildren ?? footerChildren;
    final effectiveShowDoctorSummary =
        options?.showDoctorSummary ?? showDoctorSummary;
    final effectiveShowValidationDetails =
        options?.showValidationDetails ?? showValidationDetails;
    final effectiveShowErrorDetails =
        options?.showErrorDetails ?? showErrorDetails;
    final effectiveShowQuickFixes = options?.showQuickFixes ?? showQuickFixes;
    final effectiveMaxQuickFixes = options?.maxQuickFixes ?? maxQuickFixes;
    final report = result.validation.toReport(
      maxIssues: validationReportMaxIssues,
    );
    final doctor = ChartPayloadDoctor.inspect(
      rawPayload,
      requireRegisteredType: requireRegisteredType,
    );
    final quickFixes = effectiveShowQuickFixes
        ? _fallbackQuickFixes(doctor, maxQuickFixes: effectiveMaxQuickFixes)
        : const <String>[];

    return _DiagnosticFallbackPanel(
      title: effectiveTitle,
      children: [
        Text(effectiveMessage),
        if (effectiveShowDoctorSummary) ...[
          const SizedBox(height: 4),
          Text(_doctorLine(doctor)),
        ],
        if (effectiveShowValidationDetails && !result.validation.isValid)
          ..._validationReportWidgets(report),
        if (quickFixes.isNotEmpty) ..._quickFixWidgets(quickFixes),
        if (effectiveShowErrorDetails && result.error != null) ...[
          const SizedBox(height: 6),
          Text(result.error.toString()),
        ],
        if (effectiveFooter.isNotEmpty) ...[
          const SizedBox(height: 6),
          ...effectiveFooter,
        ],
      ],
    );
  }

  String _doctorLine(ChartPayloadDoctorReport doctor) {
    return 'Doctor: ${doctor.status.name} | '
        'expected ${_shapeLabel(doctor.expectedShape)} | '
        'inferred ${_shapeLabel(doctor.inferredShape)}';
  }
}

class TenunRenderErrorFallback extends StatelessWidget {
  final Object error;
  final StackTrace? stackTrace;
  final Map<String, dynamic>? rawPayload;
  final bool requireRegisteredType;
  final int validationReportMaxIssues;
  final String title;
  final String? message;
  final String? detailMessage;
  final List<Widget> footerChildren;
  final bool showDoctorSummary;
  final bool showValidationDetails;
  final bool showErrorDetails;
  final bool showQuickFixes;
  final int maxQuickFixes;
  final TenunDiagnosticFallbackOptions? options;

  const TenunRenderErrorFallback({
    super.key,
    required this.error,
    this.stackTrace,
    this.rawPayload,
    this.requireRegisteredType = false,
    this.validationReportMaxIssues = 3,
    this.title = 'Chart render error',
    this.message = 'The chart could not be rendered.',
    this.detailMessage,
    this.footerChildren = const [],
    this.showDoctorSummary = true,
    this.showValidationDetails = true,
    this.showErrorDetails = true,
    this.showQuickFixes = true,
    this.maxQuickFixes = 3,
    this.options,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveTitle = options?.title ?? title;
    final effectiveMessage = options?.message ?? message;
    final effectiveDetailMessage =
        options?.detailMessage ?? detailMessage ?? error.toString();
    final effectiveFooter = options?.footerChildren ?? footerChildren;
    final effectiveShowDoctorSummary =
        options?.showDoctorSummary ?? showDoctorSummary;
    final effectiveShowValidationDetails =
        options?.showValidationDetails ?? showValidationDetails;
    final effectiveShowErrorDetails =
        options?.showErrorDetails ?? showErrorDetails;
    final effectiveShowQuickFixes = options?.showQuickFixes ?? showQuickFixes;
    final effectiveMaxQuickFixes = options?.maxQuickFixes ?? maxQuickFixes;
    final payload = rawPayload;
    final doctor = payload == null
        ? null
        : ChartPayloadDoctor.inspect(
            payload,
            requireRegisteredType: requireRegisteredType,
          );
    final validation = payload == null
        ? null
        : ChartConfigValidator.validateJsonPayload(
            payload,
            deep: true,
            requireRegisteredType: requireRegisteredType,
          );
    final quickFixes = doctor == null || !effectiveShowQuickFixes
        ? const <String>[]
        : _fallbackQuickFixes(doctor, maxQuickFixes: effectiveMaxQuickFixes);

    return _DiagnosticFallbackPanel(
      title: effectiveTitle,
      children: [
        if (_hasText(effectiveMessage)) Text(effectiveMessage!),
        if (doctor != null && effectiveShowDoctorSummary) ...[
          if (_hasText(effectiveMessage)) const SizedBox(height: 4),
          Text(_renderDoctorLine(doctor)),
        ],
        if (validation != null &&
            effectiveShowValidationDetails &&
            !validation.isValid)
          ..._validationReportWidgets(
            validation.toReport(maxIssues: validationReportMaxIssues),
          ),
        if (quickFixes.isNotEmpty) ..._quickFixWidgets(quickFixes),
        if (effectiveShowErrorDetails && _hasText(effectiveDetailMessage)) ...[
          if (_hasText(effectiveMessage)) const SizedBox(height: 4),
          Text(effectiveDetailMessage),
        ],
        if (effectiveFooter.isNotEmpty) ...[
          const SizedBox(height: 6),
          ...effectiveFooter,
        ],
      ],
    );
  }

  String _renderDoctorLine(ChartPayloadDoctorReport doctor) {
    return 'Render Doctor: ${doctor.status.name} | '
        'expected ${_shapeLabel(doctor.expectedShape)} | '
        'inferred ${_shapeLabel(doctor.inferredShape)}';
  }
}

class TenunValidationReportFallback extends StatelessWidget {
  final ValidationResult result;
  final Map<String, dynamic>? rawPayload;
  final bool requireRegisteredType;
  final int validationReportMaxIssues;
  final String title;
  final String? message;
  final List<Widget> footerChildren;
  final bool showDoctorSummary;
  final bool showValidationDetails;
  final bool showQuickFixes;
  final int maxQuickFixes;
  final TenunDiagnosticFallbackOptions? options;

  const TenunValidationReportFallback({
    super.key,
    required this.result,
    this.rawPayload,
    this.requireRegisteredType = false,
    required this.validationReportMaxIssues,
    this.title = 'Invalid chart payload',
    this.message,
    this.footerChildren = const [],
    this.showDoctorSummary = true,
    this.showValidationDetails = true,
    this.showQuickFixes = true,
    this.maxQuickFixes = 3,
    this.options,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveTitle = options?.title ?? title;
    final effectiveMessage = options?.message ?? message;
    final effectiveFooter = options?.footerChildren ?? footerChildren;
    final effectiveShowDoctorSummary =
        options?.showDoctorSummary ?? showDoctorSummary;
    final effectiveShowValidationDetails =
        options?.showValidationDetails ?? showValidationDetails;
    final effectiveShowQuickFixes = options?.showQuickFixes ?? showQuickFixes;
    final effectiveMaxQuickFixes = options?.maxQuickFixes ?? maxQuickFixes;
    final report = result.toReport(maxIssues: validationReportMaxIssues);
    final payload = rawPayload;
    final doctor = payload == null
        ? null
        : ChartPayloadDoctor.inspect(
            payload,
            requireRegisteredType: requireRegisteredType,
          );
    final quickFixes = doctor == null || !effectiveShowQuickFixes
        ? const <String>[]
        : _fallbackQuickFixes(doctor, maxQuickFixes: effectiveMaxQuickFixes);

    return _DiagnosticFallbackPanel(
      title: effectiveTitle,
      children: [
        if (_hasText(effectiveMessage)) ...[
          Text(effectiveMessage!),
          const SizedBox(height: 4),
        ],
        if (doctor != null && effectiveShowDoctorSummary) ...[
          Text(_doctorLine(doctor)),
          const SizedBox(height: 6),
        ],
        if (effectiveShowValidationDetails) ..._validationReportWidgets(report),
        if (quickFixes.isNotEmpty) ..._quickFixWidgets(quickFixes),
        if (effectiveFooter.isNotEmpty) ...[
          const SizedBox(height: 6),
          ...effectiveFooter,
        ],
      ],
    );
  }

  String _doctorLine(ChartPayloadDoctorReport doctor) {
    return 'Doctor: ${doctor.status.name} | '
        'expected ${_shapeLabel(doctor.expectedShape)} | '
        'inferred ${_shapeLabel(doctor.inferredShape)}';
  }
}

class TenunSwitchBlockedFallback extends StatelessWidget {
  final ValidatedChartTypeSwitchResult result;
  final Map<String, dynamic> rawPayload;
  final bool requireRegisteredType;
  final int validationReportMaxIssues;
  final String title;
  final String? message;
  final String? detailMessage;
  final List<Widget> footerChildren;
  final bool showDoctorSummary;
  final bool showValidationDetails;
  final bool showQuickFixes;
  final int maxQuickFixes;
  final TenunDiagnosticFallbackOptions? options;

  const TenunSwitchBlockedFallback({
    super.key,
    required this.result,
    required this.rawPayload,
    required this.requireRegisteredType,
    required this.validationReportMaxIssues,
    this.title = 'Chart type switch blocked',
    this.message,
    this.detailMessage,
    this.footerChildren = const [],
    this.showDoctorSummary = true,
    this.showValidationDetails = true,
    this.showQuickFixes = true,
    this.maxQuickFixes = 3,
    this.options,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveTitle = options?.title ?? title;
    final effectiveMessage = options?.message ?? message;
    final effectiveDetailMessage = options?.detailMessage ?? detailMessage;
    final effectiveFooter = options?.footerChildren ?? footerChildren;
    final effectiveShowDoctorSummary =
        options?.showDoctorSummary ?? showDoctorSummary;
    final effectiveShowValidationDetails =
        options?.showValidationDetails ?? showValidationDetails;
    final effectiveShowQuickFixes = options?.showQuickFixes ?? showQuickFixes;
    final effectiveMaxQuickFixes = options?.maxQuickFixes ?? maxQuickFixes;
    final validation = result.validation;
    final report = validation?.toReport(maxIssues: validationReportMaxIssues);
    final safetyMessage = effectiveMessage ?? result.renderSafetyMessage;
    final detail = effectiveDetailMessage ?? result.message;
    final doctor = ChartPayloadDoctor.inspect(
      _switchDoctorPayload(result),
      requireRegisteredType: requireRegisteredType,
    );
    final quickFixes = effectiveShowQuickFixes
        ? _fallbackQuickFixes(doctor, maxQuickFixes: effectiveMaxQuickFixes)
        : const <String>[];

    return _DiagnosticFallbackPanel(
      title: effectiveTitle,
      children: [
        Text(safetyMessage),
        if (detail != safetyMessage) ...[
          const SizedBox(height: 4),
          Text(detail),
        ],
        if (effectiveShowDoctorSummary) ...[
          const SizedBox(height: 4),
          Text(_switchDoctorLine(doctor)),
        ],
        if (effectiveShowValidationDetails &&
            validation != null &&
            report != null &&
            !validation.isValid)
          ..._validationReportWidgets(report),
        if (quickFixes.isNotEmpty) ..._quickFixWidgets(quickFixes),
        if (effectiveFooter.isNotEmpty) ...[
          const SizedBox(height: 6),
          ...effectiveFooter,
        ],
      ],
    );
  }

  Map<String, dynamic> _switchDoctorPayload(
    ValidatedChartTypeSwitchResult result,
  ) {
    final payload = result.payload;
    if (payload != null) return payload;
    return {...rawPayload, 'type': result.targetTypeString};
  }

  String _switchDoctorLine(ChartPayloadDoctorReport doctor) {
    return 'Switch Doctor: ${doctor.status.name} | '
        'source ${_shapeLabel(result.switchResult.sourceShape)} -> '
        'target ${_shapeLabel(result.switchResult.targetShape)} | '
        'inferred ${_shapeLabel(doctor.inferredShape)}';
  }
}

class _DiagnosticFallbackPanel extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _DiagnosticFallbackPanel({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final bodyStyle =
        theme.textTheme.bodySmall?.copyWith(color: colors.error) ??
        TextStyle(color: colors.error, fontSize: 12);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.errorContainer.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.error.withValues(alpha: 0.32)),
      ),
      child: _overflowSafeFallbackBody(
        DefaultTextStyle(
          style: bodyStyle,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: colors.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

List<String> _fallbackQuickFixes(
  ChartPayloadDoctorReport doctor, {
  required int maxQuickFixes,
}) {
  if (maxQuickFixes <= 0) return const [];
  final fixes = doctor.quickFixes;
  final ordered = <String>[];

  void addMatching(bool Function(String fix) matches) {
    for (final fix in fixes) {
      if (matches(fix) && !ordered.contains(fix)) {
        ordered.add(fix);
      }
    }
  }

  addMatching((fix) => fix.startsWith('Enable autoNormalizePayload'));
  addMatching((fix) => fix.startsWith('Apply normalization'));
  addMatching((fix) => fix.startsWith('Review changed paths'));
  addMatching((fix) => true);

  return ordered.take(maxQuickFixes).toList(growable: false);
}

bool _hasText(String? value) => value != null && value.trim().isNotEmpty;

List<Widget> _validationReportWidgets(ValidationReport report) {
  return [
    const SizedBox(height: 6),
    Text(report.compactMessage),
    const SizedBox(height: 6),
    for (final issue in report.visibleReportIssues) ...[
      Text('${issue.index + 1}. ${issue.displayText}'),
      Text('   ${issue.suggestionText}'),
    ],
    if (report.hasMoreIssues)
      Text('${report.counts['hidden']} more issue(s) hidden.'),
  ];
}

List<Widget> _quickFixWidgets(List<String> quickFixes) {
  return [
    const SizedBox(height: 6),
    const Text('Quick fixes:'),
    for (final fix in quickFixes) Text('- $fix'),
  ];
}

String _shapeLabel(ChartSeriesDataShape shape) {
  switch (shape) {
    case ChartSeriesDataShape.pieLike:
      return 'pie-like';
    case ChartSeriesDataShape.hierarchical:
      return 'hierarchy';
    case ChartSeriesDataShape.geospatial:
      return 'geospatial';
    default:
      return shape.name;
  }
}

Widget _overflowSafeFallbackBody(Widget child) {
  return LayoutBuilder(
    builder: (context, constraints) {
      if (!constraints.hasBoundedHeight || !constraints.maxHeight.isFinite) {
        return child;
      }
      return ClipRect(
        child: SingleChildScrollView(padding: EdgeInsets.zero, child: child),
      );
    },
  );
}
