import 'package:flutter/widgets.dart';

import '../core/chart_diagnostic_fallback_fields.dart';

class TenunDiagnosticFallbackOptions {
  final String? title;
  final String? message;
  final String? detailMessage;
  final List<Widget> footerChildren;
  final bool showDoctorSummary;
  final bool showValidationDetails;
  final bool showErrorDetails;
  final bool showQuickFixes;
  final int maxQuickFixes;

  static const defaults = TenunDiagnosticFallbackOptions();

  static const compact = TenunDiagnosticFallbackOptions(maxQuickFixes: 1);

  static const quiet = TenunDiagnosticFallbackOptions(showQuickFixes: false);

  static const production = TenunDiagnosticFallbackOptions(
    showDoctorSummary: false,
    showValidationDetails: false,
    showErrorDetails: false,
    showQuickFixes: false,
    maxQuickFixes: 0,
  );

  const TenunDiagnosticFallbackOptions({
    this.title,
    this.message,
    this.detailMessage,
    this.footerChildren = const [],
    this.showDoctorSummary = true,
    this.showValidationDetails = true,
    this.showErrorDetails = true,
    this.showQuickFixes = true,
    this.maxQuickFixes = 3,
  });

  factory TenunDiagnosticFallbackOptions.fromJson(
    Object? raw, {
    TenunDiagnosticFallbackOptions fallback = defaults,
  }) {
    if (raw is String) return _preset(raw) ?? fallback;
    if (raw is! Map) return fallback;

    final json = Map<Object?, Object?>.from(raw);
    final preset = _stringValue(json[ChartDiagnosticFallbackFields.preset]);
    final base = preset == null ? fallback : _preset(preset) ?? fallback;

    return base.copyWith(
      title: _stringValue(json[ChartDiagnosticFallbackFields.title]),
      message: _stringValue(json[ChartDiagnosticFallbackFields.message]),
      detailMessage: _stringValue(
        json[ChartDiagnosticFallbackFields.detailMessage],
      ),
      showDoctorSummary: ChartDiagnosticFallbackFields.parseBool(
        json[ChartDiagnosticFallbackFields.showDoctorSummary],
      ),
      showValidationDetails: ChartDiagnosticFallbackFields.parseBool(
        json[ChartDiagnosticFallbackFields.showValidationDetails],
      ),
      showErrorDetails: ChartDiagnosticFallbackFields.parseBool(
        json[ChartDiagnosticFallbackFields.showErrorDetails],
      ),
      showQuickFixes: ChartDiagnosticFallbackFields.parseBool(
        json[ChartDiagnosticFallbackFields.showQuickFixes],
      ),
      maxQuickFixes: ChartDiagnosticFallbackFields.parseNonNegativeInt(
        json[ChartDiagnosticFallbackFields.maxQuickFixes],
      ),
    );
  }

  /// Resolve fallback options from either a direct options payload or a full
  /// chart JSON payload.
  ///
  /// Accepted chart payload locations:
  /// - `diagnosticFallbackOptions`
  /// - `diagnosticFallback`
  /// - `fallbackOptions`
  /// - `diagnostics.diagnosticFallbackOptions`
  /// - `diagnostics.diagnosticFallback`
  /// - `diagnostics.fallbackOptions`
  /// - `diagnostics.fallback`
  static TenunDiagnosticFallbackOptions resolve(
    Object? raw, {
    TenunDiagnosticFallbackOptions fallback = defaults,
  }) {
    final match = _optionsMatch(raw);
    if (match != null) {
      return TenunDiagnosticFallbackOptions.fromJson(match, fallback: fallback);
    }
    return TenunDiagnosticFallbackOptions.fromJson(raw, fallback: fallback);
  }

  TenunDiagnosticFallbackOptions copyWith({
    String? title,
    bool clearTitle = false,
    String? message,
    bool clearMessage = false,
    String? detailMessage,
    bool clearDetailMessage = false,
    List<Widget>? footerChildren,
    bool? showDoctorSummary,
    bool? showValidationDetails,
    bool? showErrorDetails,
    bool? showQuickFixes,
    int? maxQuickFixes,
  }) {
    return TenunDiagnosticFallbackOptions(
      title: clearTitle ? null : title ?? this.title,
      message: clearMessage ? null : message ?? this.message,
      detailMessage: clearDetailMessage
          ? null
          : detailMessage ?? this.detailMessage,
      footerChildren: footerChildren ?? this.footerChildren,
      showDoctorSummary: showDoctorSummary ?? this.showDoctorSummary,
      showValidationDetails:
          showValidationDetails ?? this.showValidationDetails,
      showErrorDetails: showErrorDetails ?? this.showErrorDetails,
      showQuickFixes: showQuickFixes ?? this.showQuickFixes,
      maxQuickFixes: maxQuickFixes ?? this.maxQuickFixes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (title != null) ChartDiagnosticFallbackFields.title: title,
      if (message != null) ChartDiagnosticFallbackFields.message: message,
      if (detailMessage != null)
        ChartDiagnosticFallbackFields.detailMessage: detailMessage,
      'footerChildCount': footerChildren.length,
      ChartDiagnosticFallbackFields.showDoctorSummary: showDoctorSummary,
      ChartDiagnosticFallbackFields.showValidationDetails:
          showValidationDetails,
      ChartDiagnosticFallbackFields.showErrorDetails: showErrorDetails,
      ChartDiagnosticFallbackFields.showQuickFixes: showQuickFixes,
      ChartDiagnosticFallbackFields.maxQuickFixes: maxQuickFixes,
    };
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is TenunDiagnosticFallbackOptions &&
            title == other.title &&
            message == other.message &&
            detailMessage == other.detailMessage &&
            _listEquals(footerChildren, other.footerChildren) &&
            showDoctorSummary == other.showDoctorSummary &&
            showValidationDetails == other.showValidationDetails &&
            showErrorDetails == other.showErrorDetails &&
            showQuickFixes == other.showQuickFixes &&
            maxQuickFixes == other.maxQuickFixes;
  }

  @override
  int get hashCode => Object.hash(
    title,
    message,
    detailMessage,
    Object.hashAll(footerChildren),
    showDoctorSummary,
    showValidationDetails,
    showErrorDetails,
    showQuickFixes,
    maxQuickFixes,
  );

  @override
  String toString() {
    return 'TenunDiagnosticFallbackOptions('
        'title: $title, '
        'message: $message, '
        'detailMessage: $detailMessage, '
        'footerChildren: ${footerChildren.length}, '
        'showDoctorSummary: $showDoctorSummary, '
        'showValidationDetails: $showValidationDetails, '
        'showErrorDetails: $showErrorDetails, '
        'showQuickFixes: $showQuickFixes, '
        'maxQuickFixes: $maxQuickFixes'
        ')';
  }
}

Object? _optionsMatch(Object? raw) {
  if (raw is! Map) return null;
  final json = Map<Object?, Object?>.from(raw);

  for (final key in ChartDiagnosticFallbackFields.topLevelContainerFields) {
    if (json.containsKey(key)) return json[key];
  }

  final diagnostics = json[ChartDiagnosticFallbackFields.diagnostics];
  if (diagnostics is! Map) return null;
  final diagnosticsJson = Map<Object?, Object?>.from(diagnostics);
  for (final key in ChartDiagnosticFallbackFields.diagnosticsContainerFields) {
    if (diagnosticsJson.containsKey(key)) return diagnosticsJson[key];
  }

  return null;
}

TenunDiagnosticFallbackOptions? _preset(String value) {
  switch (value.trim().toLowerCase()) {
    case 'default':
    case 'defaults':
      return TenunDiagnosticFallbackOptions.defaults;
    case 'compact':
      return TenunDiagnosticFallbackOptions.compact;
    case 'quiet':
      return TenunDiagnosticFallbackOptions.quiet;
    case 'production':
      return TenunDiagnosticFallbackOptions.production;
    default:
      return null;
  }
}

String? _stringValue(Object? raw) {
  if (raw is! String) return null;
  final value = raw.trim();
  return value.isEmpty ? null : value;
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var index = 0; index < a.length; index += 1) {
    if (a[index] != b[index]) return false;
  }
  return true;
}
