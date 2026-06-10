import 'json_value.dart';

class ChartJsonOptionValueHint {
  final String? kind;
  final Object? value;
  final String jsonLiteral;
  final List<Object?> examples;

  const ChartJsonOptionValueHint({
    required this.kind,
    required this.value,
    required this.jsonLiteral,
    this.examples = const [],
  });

  factory ChartJsonOptionValueHint.forKind(
    String? kind, {
    String? canonicalField,
  }) {
    switch (kind) {
      case 'boolean':
        return const ChartJsonOptionValueHint(
          kind: 'boolean',
          value: true,
          jsonLiteral: 'true',
          examples: [true, false],
        );
      case 'dataMode':
        return const ChartJsonOptionValueHint(
          kind: 'dataMode',
          value: 'auto',
          jsonLiteral: '"auto"',
          examples: ['regular', 'auto', 'large'],
        );
      case 'nonNegativeInteger':
        return const ChartJsonOptionValueHint(
          kind: 'nonNegativeInteger',
          value: 3,
          jsonLiteral: '3',
          examples: [0, 3, 8],
        );
      case 'positiveInteger':
        final value = _positiveIntegerExample(canonicalField);
        return ChartJsonOptionValueHint(
          kind: 'positiveInteger',
          value: value,
          jsonLiteral: value.toString(),
          examples: const [20, 1200, 10000],
        );
      case 'preset':
        return const ChartJsonOptionValueHint(
          kind: 'preset',
          value: 'production',
          jsonLiteral: '"production"',
          examples: ['default', 'compact', 'quiet', 'production'],
        );
      case 'string':
        return ChartJsonOptionValueHint(
          kind: 'string',
          value: _stringExample(canonicalField),
          jsonLiteral: _quoted(_stringExample(canonicalField)),
          examples: const ['Chart unavailable'],
        );
      case 'unitRatio':
        return const ChartJsonOptionValueHint(
          kind: 'unitRatio',
          value: 0.8,
          jsonLiteral: '0.8',
          examples: [0.25, 0.8, 0.9],
        );
      default:
        return ChartJsonOptionValueHint(
          kind: kind,
          value: null,
          jsonLiteral: 'null',
        );
    }
  }

  Map<String, dynamic> toJson() => {
    if (kind != null) 'kind': kind,
    'value': JsonValue.clone(value),
    'jsonLiteral': jsonLiteral,
    if (examples.isNotEmpty) 'examples': examples.map(JsonValue.clone).toList(),
  };

  ChartJsonOptionValueValidation validate(
    Object? candidate, {
    String? canonicalField,
  }) {
    final valid = switch (kind) {
      'boolean' => candidate is bool,
      'dataMode' => candidate is String && _dataModeValues.contains(candidate),
      'nonNegativeInteger' => _isInteger(candidate) && (candidate as num) >= 0,
      'positiveInteger' => _isInteger(candidate) && (candidate as num) > 0,
      'preset' => candidate is String && _presetValues.contains(candidate),
      'string' => candidate is String,
      'unitRatio' =>
        candidate is num &&
            candidate.isFinite &&
            candidate >= 0 &&
            candidate <= 1,
      _ => true,
    };

    return ChartJsonOptionValueValidation(
      canonicalField: canonicalField,
      kind: kind,
      value: candidate,
      isValid: valid,
      message: valid ? null : _invalidMessage(kind, canonicalField),
    );
  }
}

class ChartJsonOptionValueValidation {
  final String? canonicalField;
  final String? kind;
  final Object? value;
  final bool isValid;
  final String? message;

  const ChartJsonOptionValueValidation({
    required this.canonicalField,
    required this.kind,
    required this.value,
    required this.isValid,
    this.message,
  });

  Map<String, dynamic> toJson() => {
    if (canonicalField != null) 'canonicalField': canonicalField,
    if (kind != null) 'kind': kind,
    'value': JsonValue.clone(value),
    'isValid': isValid,
    if (message != null) 'message': message,
  };
}

int _positiveIntegerExample(String? canonicalField) {
  switch (canonicalField) {
    case 'defaultThreshold':
      return 1200;
    case 'largeDatasetPointThreshold':
      return 10000;
    case 'lowRenderCacheMinRequests':
      return 20;
    case 'maxInlineLength':
      return 120;
    default:
      return 100;
  }
}

String _stringExample(String? canonicalField) {
  switch (canonicalField) {
    case 'title':
      return 'Chart unavailable';
    case 'message':
      return 'Review this payload before publishing.';
    case 'detailMessage':
      return 'Try validating the chart configuration.';
    default:
      return 'Text';
  }
}

String _quoted(String value) {
  final escaped = value
      .replaceAll(r'\', r'\\')
      .replaceAll('"', r'\"')
      .replaceAll('\n', r'\n');
  return '"$escaped"';
}

const _dataModeValues = {
  'regular',
  'simple',
  'auto',
  'large',
  'largedataset',
  'performance',
};

const _presetValues = {'default', 'defaults', 'compact', 'quiet', 'production'};

bool _isInteger(Object? value) {
  if (value is int) return true;
  if (value is num) return value.isFinite && value % 1 == 0;
  return false;
}

String _invalidMessage(String? kind, String? canonicalField) {
  final field = canonicalField == null
      ? 'Value'
      : 'Value for "$canonicalField"';
  return switch (kind) {
    'boolean' => '$field must be a boolean.',
    'dataMode' => '$field must be one of: regular, auto, or large.',
    'nonNegativeInteger' => '$field must be a non-negative integer.',
    'positiveInteger' => '$field must be a positive integer.',
    'preset' =>
      '$field must be one of: default, compact, quiet, or production.',
    'string' => '$field must be a string.',
    'unitRatio' => '$field must be a number between 0 and 1.',
    _ => '$field is not valid for this option.',
  };
}
