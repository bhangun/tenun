import '../core/base_config.dart';
import '../core/chart_api_contract.dart';
import '../core/chart_type.dart';
import '../core/chart_registry.dart';
import '../core/json_value.dart';
import 'chart_api_contract_mapping.dart';
import 'chart_registration_bundle.dart';

/// Data-shape groups used to pick compatible chart families.
enum ChartSeriesDataShape {
  cartesian,
  pieLike,
  hierarchical,
  matrix,
  graph,
  flow,
  financial,
  radial,
  calendar,
  geospatial,
  unknown,
}

/// Strategy used to derive `series` from shorthand JSON payload fields.
enum ChartPayloadSeriesStrategy {
  dataFields,
  namedCollection,
  nodeLink,
  calendarDateValues,
  ringSlices,
  partitionPie,
}

/// Registry-owned payload contract for a chart type.
///
/// Keep JSON collection shortcuts here so validators, runtime switchers, and
/// developer tooling do not grow independent chart-type switch statements.
class ChartPayloadContract {
  final ChartType type;
  final ChartSeriesDataShape dataShape;
  final ChartPayloadSeriesStrategy seriesStrategy;
  final List<String> dataFieldPriority;
  final String? namedCollectionField;
  final bool requiresSeries;
  final bool usesExternalDataModel;

  const ChartPayloadContract({
    required this.type,
    required this.dataShape,
    required this.seriesStrategy,
    this.dataFieldPriority = const [],
    this.namedCollectionField,
    this.requiresSeries = true,
    this.usesExternalDataModel = false,
  });

  String get typeString => chartTypeToString(type);

  bool get supportsShorthandCollections =>
      dataFieldPriority.isNotEmpty ||
      namedCollectionField != null ||
      seriesStrategy != ChartPayloadSeriesStrategy.dataFields;

  Map<String, dynamic> toJson() => {
    'type': typeString,
    'dataShape': dataShape.name,
    'seriesStrategy': seriesStrategy.name,
    'dataFieldPriority': List<String>.from(dataFieldPriority),
    if (namedCollectionField != null)
      'namedCollectionField': namedCollectionField,
    'requiresSeries': requiresSeries,
    'usesExternalDataModel': usesExternalDataModel,
    'supportsShorthandCollections': supportsShorthandCollections,
  };
}

/// Grouped bundles keyed by inferred data shape.
final Map<ChartSeriesDataShape, RegistrationBundle> seriesShapeBundles =
    buildShapeBundles();

/// Capability metadata for a chart type.
///
/// This is intentionally derived from registration + data-shape groupings so
/// runtime switching, validation tooling, and showcase controls do not need
/// their own independent chart-family switch statements.
class ChartCapabilities {
  final ChartType type;
  final String typeString;
  final ChartSeriesDataShape dataShape;
  final bool isRegistered;
  final bool supportsSampling;
  final bool supportsZoom;
  final bool supportsDrilldown;
  final bool supportsLegend;
  final bool supportsTooltip;
  final bool supportsRuntimeSwitching;
  final ChartApiContract apiContract;
  final String description;
  final List<String> aliases;
  final List<String> tags;

  const ChartCapabilities({
    required this.type,
    required this.typeString,
    required this.dataShape,
    required this.isRegistered,
    required this.supportsSampling,
    required this.supportsZoom,
    required this.supportsDrilldown,
    required this.supportsLegend,
    required this.supportsTooltip,
    required this.supportsRuntimeSwitching,
    this.apiContract = ChartApiContracts.optionConfig,
    this.description = '',
    this.aliases = const [],
    this.tags = const [],
  });

  Map<String, dynamic> toJson() => {
    'type': typeString,
    'dataShape': dataShape.name,
    'isRegistered': isRegistered,
    'supportsSampling': supportsSampling,
    'supportsZoom': supportsZoom,
    'supportsDrilldown': supportsDrilldown,
    'supportsLegend': supportsLegend,
    'supportsTooltip': supportsTooltip,
    'supportsRuntimeSwitching': supportsRuntimeSwitching,
    'apiContract': apiContract.name,
    'apiFamily': apiContract.family.name,
    if (description.isNotEmpty) 'description': description,
    if (aliases.isNotEmpty) 'aliases': List<String>.from(aliases),
    if (tags.isNotEmpty) 'tags': List<String>.from(tags),
  };
}

/// Ranked runtime switch candidate for a JSON chart payload.
class ChartSwitchOption {
  final ChartType type;
  final int rank;
  final bool isCurrentType;
  final ChartSeriesDataShape sourceShape;
  final ChartCapabilities capabilities;
  final Map<String, dynamic> previewPayload;
  final String reason;

  const ChartSwitchOption({
    required this.type,
    required this.rank,
    required this.isCurrentType,
    required this.sourceShape,
    required this.capabilities,
    required this.previewPayload,
    required this.reason,
  });

  String get typeString => chartTypeToString(type);

  Map<String, dynamic> toJson({bool includePreviewPayload = false}) => {
    'type': typeString,
    'rank': rank,
    'isCurrentType': isCurrentType,
    'sourceShape': sourceShape.name,
    'capabilities': capabilities.toJson(),
    'reason': reason,
    if (includePreviewPayload)
      'previewPayload': JsonValue.cloneMap(previewPayload),
  };
}

/// Non-throwing compatibility result for a potential runtime chart switch.
class ChartSwitchCompatibility {
  final ChartType targetType;
  final ChartSeriesDataShape sourceShape;
  final ChartSeriesDataShape targetShape;
  final bool isCompatible;
  final bool forceConversionAvailable;
  final bool targetRegistered;
  final List<ChartType> compatibleTypes;
  final ChartCapabilities targetCapabilities;
  final String reason;

  const ChartSwitchCompatibility({
    required this.targetType,
    required this.sourceShape,
    required this.targetShape,
    required this.isCompatible,
    required this.forceConversionAvailable,
    required this.targetRegistered,
    required this.compatibleTypes,
    required this.targetCapabilities,
    required this.reason,
  });

  String get targetTypeString => chartTypeToString(targetType);
  bool get canSwitch => isCompatible || forceConversionAvailable;
  bool get requiresForce => !isCompatible && forceConversionAvailable;

  Map<String, dynamic> toJson() => {
    'targetType': targetTypeString,
    'sourceShape': sourceShape.name,
    'targetShape': targetShape.name,
    'isCompatible': isCompatible,
    'forceConversionAvailable': forceConversionAvailable,
    'canSwitch': canSwitch,
    'requiresForce': requiresForce,
    'targetRegistered': targetRegistered,
    'compatibleTypes': compatibleTypes
        .map(chartTypeToString)
        .toList(growable: false),
    'targetCapabilities': targetCapabilities.toJson(),
    'reason': reason,
  };
}

/// Non-throwing result for a requested chart-type switch.
///
/// Use this from UI/runtime code when a switch may be driven by user input.
/// It carries the same compatibility decision as [ChartSwitchCompatibility]
/// plus the adapted payload when switching is safe.
class ChartTypeSwitchResult {
  final bool success;
  final ChartType targetType;
  final ChartSwitchCompatibility compatibility;
  final Map<String, dynamic>? payload;
  final bool usedForceConversion;
  final List<String> preservedRuntimeKeys;
  final List<String> changedTopLevelKeys;
  final String message;

  const ChartTypeSwitchResult({
    required this.success,
    required this.targetType,
    required this.compatibility,
    required this.payload,
    required this.usedForceConversion,
    required this.preservedRuntimeKeys,
    required this.changedTopLevelKeys,
    required this.message,
  });

  String get targetTypeString => chartTypeToString(targetType);
  ChartSeriesDataShape get sourceShape => compatibility.sourceShape;
  ChartSeriesDataShape get targetShape => compatibility.targetShape;
  bool get isLossless => compatibility.isCompatible;
  bool get requiresForce => compatibility.requiresForce;

  Map<String, dynamic> toJson({bool includePayload = false}) => {
    'success': success,
    'targetType': targetTypeString,
    'sourceShape': sourceShape.name,
    'targetShape': targetShape.name,
    'isLossless': isLossless,
    'requiresForce': requiresForce,
    'usedForceConversion': usedForceConversion,
    'preservedRuntimeKeys': List<String>.from(preservedRuntimeKeys),
    'changedTopLevelKeys': List<String>.from(changedTopLevelKeys),
    'message': message,
    'compatibility': compatibility.toJson(),
    if (includePayload && payload != null)
      'payload': JsonValue.cloneMap(payload!),
  };
}

/// Non-throwing result for automatic chart-type switching.
class ChartAutoSwitchResult {
  final bool success;
  final ChartSeriesDataShape sourceShape;
  final ChartType? selectedType;
  final ChartSwitchOption? selectedOption;
  final List<ChartSwitchOption> options;
  final Map<String, dynamic>? payload;
  final bool keptCurrentType;
  final List<String> preservedRuntimeKeys;
  final List<String> changedTopLevelKeys;
  final String message;

  const ChartAutoSwitchResult({
    required this.success,
    required this.sourceShape,
    required this.selectedType,
    required this.selectedOption,
    required this.options,
    required this.payload,
    required this.keptCurrentType,
    required this.preservedRuntimeKeys,
    required this.changedTopLevelKeys,
    required this.message,
  });

  String? get selectedTypeString =>
      selectedType == null ? null : chartTypeToString(selectedType!);

  Map<String, dynamic> toJson({bool includePayload = false}) => {
    'success': success,
    'sourceShape': sourceShape.name,
    if (selectedTypeString != null) 'selectedType': selectedTypeString,
    'keptCurrentType': keptCurrentType,
    'optionCount': options.length,
    'options': options.map((option) => option.toJson()).toList(),
    'preservedRuntimeKeys': List<String>.from(preservedRuntimeKeys),
    'changedTopLevelKeys': List<String>.from(changedTopLevelKeys),
    'message': message,
    if (includePayload && payload != null)
      'payload': JsonValue.cloneMap(payload!),
  };
}

/// Runtime switch compatibility group for a data shape.
class ChartSwitchGroup {
  final ChartSeriesDataShape dataShape;
  final List<ChartCapabilities> charts;

  const ChartSwitchGroup({required this.dataShape, required this.charts});

  int get count => charts.length;

  List<String> get typeStrings =>
      charts.map((capability) => capability.typeString).toList(growable: false);

  Map<String, dynamic> toJson() => {
    'dataShape': dataShape.name,
    'count': count,
    'types': typeStrings,
    'featureCounts': _featureCounts(charts),
  };
}

enum RegistrationAuditSeverity { error, warning }

/// Issue found while auditing a [RegistrationBundle].
class RegistrationAuditIssue {
  final RegistrationAuditSeverity severity;
  final String code;
  final String message;
  final String? key;
  final ChartType? firstType;
  final ChartType? secondType;

  const RegistrationAuditIssue({
    required this.severity,
    required this.code,
    required this.message,
    this.key,
    this.firstType,
    this.secondType,
  });

  bool get isError => severity == RegistrationAuditSeverity.error;
  bool get isWarning => severity == RegistrationAuditSeverity.warning;

  Map<String, dynamic> toJson() => {
    'severity': severity.name,
    'code': code,
    'message': message,
    if (key != null) 'key': key,
    if (firstType != null) 'firstType': chartTypeToString(firstType!),
    if (secondType != null) 'secondType': chartTypeToString(secondType!),
  };
}

/// Audit result for a chart registration bundle.
class RegistrationBundleAudit {
  final String bundleName;
  final int registrationCount;
  final List<RegistrationAuditIssue> issues;

  const RegistrationBundleAudit({
    required this.bundleName,
    required this.registrationCount,
    required this.issues,
  });

  List<RegistrationAuditIssue> get errors =>
      issues.where((issue) => issue.isError).toList(growable: false);

  List<RegistrationAuditIssue> get warnings =>
      issues.where((issue) => issue.isWarning).toList(growable: false);

  bool get isClean => issues.isEmpty;
  bool get hasErrors => errors.isNotEmpty;

  Map<String, dynamic> toJson() => {
    'bundleName': bundleName,
    'registrationCount': registrationCount,
    'isClean': isClean,
    'errorCount': errors.length,
    'warningCount': warnings.length,
    'issues': issues.map((issue) => issue.toJson()).toList(growable: false),
  };
}

/// Aggregated registry diagnostics for developer tooling and showcase views.
class ChartRegistryHealthReport {
  final RegistrationBundleAudit audit;
  final List<ChartCapabilities> capabilities;
  final List<ChartPayloadContract> payloadContracts;
  final List<ChartApiContract> apiContracts;
  final List<ChartSwitchGroup> switchGroups;
  final Map<ChartSeriesDataShape, int> shapeCounts;
  final Map<String, int> featureCounts;
  final Map<String, int> payloadStrategyCounts;
  final Map<String, int> payloadFeatureCounts;
  final Map<String, int> apiContractUsageCounts;
  final Map<String, int> apiFieldCategoryCounts;

  const ChartRegistryHealthReport({
    required this.audit,
    required this.capabilities,
    required this.payloadContracts,
    required this.apiContracts,
    required this.switchGroups,
    required this.shapeCounts,
    required this.featureCounts,
    required this.payloadStrategyCounts,
    required this.payloadFeatureCounts,
    required this.apiContractUsageCounts,
    required this.apiFieldCategoryCounts,
  });

  bool get isHealthy => !audit.hasErrors;

  int get capabilityCount => capabilities.length;
  int get payloadContractCount => payloadContracts.length;
  int get apiContractCount => apiContracts.length;

  Map<String, dynamic> toJson() => {
    'isHealthy': isHealthy,
    'audit': audit.toJson(),
    'capabilityCount': capabilityCount,
    'payloadContractCount': payloadContractCount,
    'apiContractCount': apiContractCount,
    'shapeCounts': {
      for (final entry in shapeCounts.entries) entry.key.name: entry.value,
    },
    'featureCounts': Map<String, int>.from(featureCounts),
    'payloadStrategyCounts': Map<String, int>.from(payloadStrategyCounts),
    'payloadFeatureCounts': Map<String, int>.from(payloadFeatureCounts),
    'apiContractUsageCounts': Map<String, int>.from(apiContractUsageCounts),
    'apiFieldCategoryCounts': Map<String, int>.from(apiFieldCategoryCounts),
    'switchGroups': switchGroups
        .map((group) => group.toJson())
        .toList(growable: false),
    'capabilities': capabilities
        .map((capability) => capability.toJson())
        .toList(growable: false),
    'payloadContracts': payloadContracts
        .map((contract) => contract.toJson())
        .toList(growable: false),
    'apiContracts': apiContracts
        .map((contract) => contract.toJson())
        .toList(growable: false),
  };
}

/// Returns a bundle with charts compatible to the provided data [shape].
RegistrationBundle? getBundleForSeriesShape(ChartSeriesDataShape shape) =>
    seriesShapeBundles[shape];

/// Returns the expected series-data shape for [type].
ChartSeriesDataShape targetSeriesDataShape(ChartType rawType) {
  final type = canonicalChartType(rawType);
  if (cartesianTypes.contains(type)) return ChartSeriesDataShape.cartesian;
  if (pieLikeTypes.contains(type)) return ChartSeriesDataShape.pieLike;
  if (hierarchicalTypes.contains(type)) {
    return ChartSeriesDataShape.hierarchical;
  }
  if (matrixTypes.contains(type)) return ChartSeriesDataShape.matrix;
  if (graphTypes.contains(type)) return ChartSeriesDataShape.graph;
  if (flowTypes.contains(type)) return ChartSeriesDataShape.flow;
  if (financialTypes.contains(type)) return ChartSeriesDataShape.financial;
  if (radialTypes.contains(type)) return ChartSeriesDataShape.radial;
  if (calendarTypes.contains(type)) return ChartSeriesDataShape.calendar;
  if (geoTypes.contains(type)) return ChartSeriesDataShape.geospatial;

  switch (type) {
    case ChartType.sparkline:
    case ChartType.boxPlot:
    case ChartType.violin:
    case ChartType.sCurve:
    case ChartType.pareto:
    case ChartType.rocCurve:
    case ChartType.lineRace:
    case ChartType.dualaxes:
    case ChartType.linestyleitem:
    case ChartType.bigdata:
      return ChartSeriesDataShape.cartesian;
    case ChartType.confusionMatrix:
      return ChartSeriesDataShape.matrix;
    case ChartType.parallel:
      return ChartSeriesDataShape.matrix;
    case ChartType.wordcloud:
      return ChartSeriesDataShape.pieLike;
    case ChartType.indicator:
      return ChartSeriesDataShape.radial;
    case ChartType.spiderline:
      return ChartSeriesDataShape.radial;
    case ChartType.alignedlabels:
    case ChartType.richlabelpie:
      return ChartSeriesDataShape.pieLike;
    default:
      return ChartSeriesDataShape.unknown;
  }
}

/// Returns the payload contract for [type].
ChartPayloadContract chartPayloadContractForType(ChartType rawType) {
  final type = canonicalChartType(rawType);
  final shape = targetSeriesDataShape(type);
  final requiresSeries =
      type != ChartType.gauge &&
      type != ChartType.barRace &&
      type != ChartType.indicator &&
      type != ChartType.halfDonut;
  final usesExternalDataModel = chartUsesExternalDataModel(type);

  switch (type) {
    case ChartType.treemap:
    case ChartType.sunburst:
      return ChartPayloadContract(
        type: type,
        dataShape: shape,
        seriesStrategy: ChartPayloadSeriesStrategy.dataFields,
        dataFieldPriority: const ['nodes', 'data'],
        requiresSeries: requiresSeries,
        usesExternalDataModel: usesExternalDataModel,
      );
    case ChartType.sankey:
    case ChartType.network:
      return ChartPayloadContract(
        type: type,
        dataShape: shape,
        seriesStrategy: ChartPayloadSeriesStrategy.nodeLink,
        requiresSeries: requiresSeries,
        usesExternalDataModel: usesExternalDataModel,
      );
    case ChartType.choropleth:
      return ChartPayloadContract(
        type: type,
        dataShape: shape,
        seriesStrategy: ChartPayloadSeriesStrategy.namedCollection,
        namedCollectionField: 'regions',
        requiresSeries: requiresSeries,
        usesExternalDataModel: usesExternalDataModel,
      );
    case ChartType.funnel:
    case ChartType.waterfall:
    case ChartType.bullet:
      return ChartPayloadContract(
        type: type,
        dataShape: shape,
        seriesStrategy: ChartPayloadSeriesStrategy.dataFields,
        dataFieldPriority: const ['items', 'data'],
        requiresSeries: requiresSeries,
        usesExternalDataModel: usesExternalDataModel,
      );
    case ChartType.gantt:
      return ChartPayloadContract(
        type: type,
        dataShape: shape,
        seriesStrategy: ChartPayloadSeriesStrategy.dataFields,
        dataFieldPriority: const ['tasks', 'data'],
        requiresSeries: requiresSeries,
        usesExternalDataModel: usesExternalDataModel,
      );
    case ChartType.radial:
      return ChartPayloadContract(
        type: type,
        dataShape: shape,
        seriesStrategy: ChartPayloadSeriesStrategy.dataFields,
        dataFieldPriority: const ['rings', 'data'],
        requiresSeries: requiresSeries,
        usesExternalDataModel: usesExternalDataModel,
      );
    case ChartType.timeline:
      return ChartPayloadContract(
        type: type,
        dataShape: shape,
        seriesStrategy: ChartPayloadSeriesStrategy.dataFields,
        dataFieldPriority: const ['events', 'data'],
        requiresSeries: requiresSeries,
        usesExternalDataModel: usesExternalDataModel,
      );
    case ChartType.wordcloud:
      return ChartPayloadContract(
        type: type,
        dataShape: shape,
        seriesStrategy: ChartPayloadSeriesStrategy.dataFields,
        dataFieldPriority: const ['words', 'data'],
        requiresSeries: requiresSeries,
        usesExternalDataModel: usesExternalDataModel,
      );
    case ChartType.calendar:
      return ChartPayloadContract(
        type: type,
        dataShape: shape,
        seriesStrategy: ChartPayloadSeriesStrategy.calendarDateValues,
        dataFieldPriority: const ['data'],
        requiresSeries: requiresSeries,
        usesExternalDataModel: usesExternalDataModel,
      );
    case ChartType.kagi:
    case ChartType.renko:
    case ChartType.macd:
      return ChartPayloadContract(
        type: type,
        dataShape: shape,
        seriesStrategy: ChartPayloadSeriesStrategy.dataFields,
        dataFieldPriority: const ['prices', 'data'],
        requiresSeries: requiresSeries,
        usesExternalDataModel: usesExternalDataModel,
      );
    case ChartType.heatmap:
    case ChartType.boxPlot:
    case ChartType.errorBar:
    case ChartType.violin:
    case ChartType.sparklineMatrix:
    case ChartType.areaTimeAxis:
    case ChartType.intradayLine:
      return ChartPayloadContract(
        type: type,
        dataShape: shape,
        seriesStrategy: ChartPayloadSeriesStrategy.dataFields,
        dataFieldPriority: const ['data', 'cells', 'points'],
        requiresSeries: requiresSeries,
        usesExternalDataModel: usesExternalDataModel,
      );
    case ChartType.nestedPie:
      return ChartPayloadContract(
        type: type,
        dataShape: shape,
        seriesStrategy: ChartPayloadSeriesStrategy.ringSlices,
        requiresSeries: requiresSeries,
        usesExternalDataModel: usesExternalDataModel,
      );
    case ChartType.partitionPie:
      return ChartPayloadContract(
        type: type,
        dataShape: shape,
        seriesStrategy: ChartPayloadSeriesStrategy.partitionPie,
        requiresSeries: requiresSeries,
        usesExternalDataModel: usesExternalDataModel,
      );
    case ChartType.calendarPie:
      return ChartPayloadContract(
        type: type,
        dataShape: shape,
        seriesStrategy: ChartPayloadSeriesStrategy.dataFields,
        dataFieldPriority: const ['days', 'data'],
        requiresSeries: requiresSeries,
        usesExternalDataModel: usesExternalDataModel,
      );
    case ChartType.pie:
    case ChartType.donut:
    case ChartType.halfDonut:
    case ChartType.paddedPie:
    case ChartType.nightingale:
    case ChartType.customizedPie:
    case ChartType.pieLabelAlign:
    case ChartType.pieSpecialLabel:
      return ChartPayloadContract(
        type: type,
        dataShape: shape,
        seriesStrategy: ChartPayloadSeriesStrategy.dataFields,
        dataFieldPriority: const ['slices', 'data'],
        requiresSeries: requiresSeries,
        usesExternalDataModel: usesExternalDataModel,
      );
    case ChartType.indicator:
      return ChartPayloadContract(
        type: type,
        dataShape: shape,
        seriesStrategy: ChartPayloadSeriesStrategy.dataFields,
        dataFieldPriority: const ['value'],
        requiresSeries: requiresSeries,
        usesExternalDataModel: usesExternalDataModel,
      );
    default:
      return ChartPayloadContract(
        type: type,
        dataShape: shape,
        seriesStrategy: ChartPayloadSeriesStrategy.dataFields,
        dataFieldPriority: const ['data'],
        requiresSeries: requiresSeries,
        usesExternalDataModel: usesExternalDataModel,
      );
  }
}

/// Returns true when [type] is parsed by a chart-specific data model instead
/// of generic series validation.
bool chartUsesExternalDataModel(ChartType type) =>
    _externalDataModelTypes.contains(canonicalChartType(type));

/// Returns capability metadata for [type].
ChartCapabilities chartCapabilitiesForType(ChartType rawType) {
  final type = canonicalChartType(rawType);
  final reg =
      ChartRegistry.registrationForType(type) ??
      _registrationForTypeInBundle(type, allChartsBundle);
  return _chartCapabilitiesFromRegistration(type, reg);
}

/// Returns capability metadata for a concrete [ChartRegistration].
ChartCapabilities chartCapabilitiesForRegistration(ChartRegistration reg) =>
    _chartCapabilitiesFromRegistration(reg.type, reg);

ChartCapabilities _chartCapabilitiesFromRegistration(
  ChartType type,
  ChartRegistration? reg,
) {
  final shape = targetSeriesDataShape(type);
  final tags = reg?.tags ?? const <String>[];

  return ChartCapabilities(
    type: type,
    typeString: reg?.typeString ?? chartTypeToString(type),
    dataShape: shape,
    isRegistered: ChartRegistry.isRegistered(type),
    supportsSampling: _supportsSampling(type, shape),
    supportsZoom: _supportsZoom(type, shape),
    supportsDrilldown: _supportsDrilldown(type, shape),
    supportsLegend: _supportsLegend(type),
    supportsTooltip: _supportsTooltip(type),
    supportsRuntimeSwitching:
        shape != ChartSeriesDataShape.unknown && type != ChartType.custom,
    apiContract: chartApiContractForType(type),
    description: reg?.description ?? '',
    aliases: reg?.aliases ?? const <String>[],
    tags: tags,
  );
}

/// Capability metadata for chart types known to the current registry.
List<ChartCapabilities> registeredChartCapabilities() => ChartRegistry
    .registeredEnums
    .map(chartCapabilitiesForType)
    .toList(growable: false);

/// Capability metadata for all compiled-in chart registrations.
List<ChartCapabilities> availableChartCapabilities({
  bool registeredOnly = true,
}) {
  if (registeredOnly) return registeredChartCapabilities();
  return _capabilitiesForBundle(allChartsBundle, registeredOnly: false);
}

/// Audits [bundle] for duplicate types, duplicate keys, canonical drift, and
/// missing shape data.
RegistrationBundleAudit auditRegistrationBundle(
  RegistrationBundle bundle, {
  bool includeUnknownShapeWarnings = false,
}) {
  final issues = <RegistrationAuditIssue>[];
  final typeOwners = <ChartType, ChartRegistration>{};
  final canonicalTypeOwners = <ChartType, ChartRegistration>{};
  final keyOwners = <String, ChartRegistration>{};
  final normalizedKeyOwners = <String, _RegistrationKeyOwner>{};

  for (final reg in bundle.registrations) {
    final canonicalType = canonicalChartType(reg.type);
    if (canonicalType != reg.type) {
      issues.add(
        RegistrationAuditIssue(
          severity: RegistrationAuditSeverity.error,
          code: 'LEGACY_REGISTRATION_TYPE',
          message:
              'Registration ${reg.type.name} in ${bundle.name} should use '
              'canonical chart type ${canonicalType.name}.',
          firstType: canonicalType,
          secondType: reg.type,
        ),
      );
    }

    final existingType = typeOwners[reg.type];
    if (existingType != null) {
      issues.add(
        RegistrationAuditIssue(
          severity: RegistrationAuditSeverity.error,
          code: 'DUPLICATE_TYPE',
          message:
              'Chart type ${chartTypeToString(reg.type)} is registered more than once in ${bundle.name}.',
          firstType: existingType.type,
          secondType: reg.type,
        ),
      );
    } else {
      typeOwners[reg.type] = reg;
    }

    final existingCanonicalType = canonicalTypeOwners[canonicalType];
    if (existingCanonicalType != null &&
        existingCanonicalType.type != reg.type) {
      issues.add(
        RegistrationAuditIssue(
          severity: RegistrationAuditSeverity.error,
          code: 'DUPLICATE_CANONICAL_TYPE',
          message:
              'Canonical chart type ${chartTypeToString(canonicalType)} is '
              'owned by both ${existingCanonicalType.type.name} and '
              '${reg.type.name} in ${bundle.name}.',
          firstType: existingCanonicalType.type,
          secondType: reg.type,
        ),
      );
    } else {
      canonicalTypeOwners[canonicalType] = reg;
    }

    final typeStringKey = normalizeChartTypeKey(reg.typeString);
    final canonicalTypeStringKey = normalizeChartTypeKey(
      chartTypeToString(canonicalType),
    );
    if (typeStringKey.isEmpty) {
      issues.add(
        RegistrationAuditIssue(
          severity: RegistrationAuditSeverity.error,
          code: 'EMPTY_TYPE_STRING',
          message:
              'Chart type ${chartTypeToString(canonicalType)} in '
              '${bundle.name} has an empty registration typeString.',
          secondType: reg.type,
        ),
      );
    } else if (typeStringKey != canonicalTypeStringKey) {
      issues.add(
        RegistrationAuditIssue(
          severity: RegistrationAuditSeverity.error,
          code: 'TYPE_STRING_MISMATCH',
          message:
              'Registration typeString "${reg.typeString}" does not match '
              'canonical chart type ${chartTypeToString(canonicalType)}.',
          key: reg.typeString,
          secondType: reg.type,
        ),
      );
    }

    for (final entry in _registrationKeyEntries(reg)) {
      final key = entry.rawKey;
      final existingKeyOwner = keyOwners[key];
      if (existingKeyOwner != null) {
        final severity = existingKeyOwner.type == reg.type
            ? RegistrationAuditSeverity.error
            : RegistrationAuditSeverity.warning;
        issues.add(
          RegistrationAuditIssue(
            severity: severity,
            code: existingKeyOwner.type == reg.type
                ? 'DUPLICATE_KEY'
                : 'KEY_COLLISION',
            message:
                'Registration key "$key" is used by ${chartTypeToString(existingKeyOwner.type)} and ${chartTypeToString(reg.type)}.',
            key: key,
            firstType: existingKeyOwner.type,
            secondType: reg.type,
          ),
        );
      } else {
        keyOwners[key] = reg;
      }

      final existingNormalizedOwner = normalizedKeyOwners[entry.normalizedKey];
      if (existingNormalizedOwner != null &&
          existingNormalizedOwner.rawKey != entry.rawKey) {
        final sameType = existingNormalizedOwner.registration.type == reg.type;
        issues.add(
          RegistrationAuditIssue(
            severity: RegistrationAuditSeverity.warning,
            code: sameType
                ? 'REDUNDANT_NORMALIZED_ALIAS'
                : 'NORMALIZED_KEY_COLLISION',
            message: sameType
                ? 'Registration key "${entry.rawKey}" normalizes to the same '
                      'lookup key as "${existingNormalizedOwner.rawKey}" for '
                      '${chartTypeToString(reg.type)}.'
                : 'Registration key "${entry.rawKey}" normalizes to the same '
                      'lookup key as "${existingNormalizedOwner.rawKey}", used '
                      'by ${chartTypeToString(existingNormalizedOwner.registration.type)} '
                      'and ${chartTypeToString(reg.type)}.',
            key: entry.normalizedKey,
            firstType: existingNormalizedOwner.registration.type,
            secondType: reg.type,
          ),
        );
      } else {
        normalizedKeyOwners[entry.normalizedKey] = _RegistrationKeyOwner(
          registration: reg,
          rawKey: entry.rawKey,
        );
      }
    }

    if (includeUnknownShapeWarnings &&
        targetSeriesDataShape(reg.type) == ChartSeriesDataShape.unknown) {
      issues.add(
        RegistrationAuditIssue(
          severity: RegistrationAuditSeverity.warning,
          code: 'UNKNOWN_DATA_SHAPE',
          message:
              'Chart type ${chartTypeToString(reg.type)} has no data-shape capability mapping.',
          secondType: reg.type,
        ),
      );
    }
  }

  return RegistrationBundleAudit(
    bundleName: bundle.name,
    registrationCount: bundle.registrations.length,
    issues: issues,
  );
}

/// Builds a consolidated health report for [bundle].
ChartRegistryHealthReport chartRegistryHealthReport({
  RegistrationBundle? bundle,
  bool registeredOnly = false,
  bool includeUnknownShapeWarnings = false,
}) {
  final targetBundle = bundle ?? allChartsBundle;
  final audit = auditRegistrationBundle(
    targetBundle,
    includeUnknownShapeWarnings: includeUnknownShapeWarnings,
  );
  final capabilities = _capabilitiesForBundle(
    targetBundle,
    registeredOnly: registeredOnly,
  );
  final payloadContracts = _payloadContractsForCapabilities(capabilities);
  const apiContracts = ChartApiContracts.all;

  return ChartRegistryHealthReport(
    audit: audit,
    capabilities: capabilities,
    payloadContracts: payloadContracts,
    apiContracts: apiContracts,
    switchGroups: _switchGroups(capabilities),
    shapeCounts: _shapeCounts(capabilities),
    featureCounts: _featureCounts(capabilities),
    payloadStrategyCounts: _payloadStrategyCounts(payloadContracts),
    payloadFeatureCounts: _payloadFeatureCounts(payloadContracts),
    apiContractUsageCounts: _apiContractUsageCounts(capabilities),
    apiFieldCategoryCounts: _apiFieldCategoryCounts(apiContracts),
  );
}

/// Returns true when [type] can consume a series with [shape].
bool chartTypeSupportsSeriesShape(ChartType type, ChartSeriesDataShape shape) =>
    shape != ChartSeriesDataShape.unknown &&
    targetSeriesDataShape(type) == shape;

/// Suggest chart types that can consume a series with [shape].
List<ChartType> compatibleChartTypesForShape(
  ChartSeriesDataShape shape, {
  bool registeredOnly = true,
}) {
  if (shape == ChartSeriesDataShape.unknown) return const [];

  final out = <ChartType>[];
  for (final type in _candidateChartTypes(registeredOnly: registeredOnly)) {
    if (!chartTypeSupportsSeriesShape(type, shape)) continue;
    if (!out.contains(type)) out.add(type);
  }
  return out;
}

List<ChartType> _candidateChartTypes({required bool registeredOnly}) {
  final rawTypes = registeredOnly
      ? ChartRegistry.registeredEnums
      : ChartType.values;
  final candidates = <ChartType>[];
  for (final rawType in rawTypes) {
    final type = canonicalChartType(rawType);
    if (!candidates.contains(type)) candidates.add(type);
  }
  return candidates;
}

/// Detect the dominant data shape from JSON chart config.
ChartSeriesDataShape inferSeriesDataShape(Map<String, dynamic> json) {
  final declaredType = _tryParseCanonicalType(json['type']);
  final declaredShape = declaredType == null
      ? null
      : targetSeriesDataShape(declaredType);
  if (declaredShape != null &&
      declaredShape != ChartSeriesDataShape.unknown &&
      _dataCanRepresentDeclaredShape(json, declaredShape)) {
    return declaredShape;
  }

  if (_hasHierarchicalData(json)) return ChartSeriesDataShape.hierarchical;
  if (_hasGraphData(json)) return ChartSeriesDataShape.graph;
  if (_hasFlowData(json)) return ChartSeriesDataShape.flow;
  if (_hasFinancialData(json)) return ChartSeriesDataShape.financial;
  if (_hasGeospatialData(json)) return ChartSeriesDataShape.geospatial;
  if (_hasCalendarData(json)) return ChartSeriesDataShape.calendar;
  if (_hasMatrixData(json)) return ChartSeriesDataShape.matrix;
  if (_hasPieLikeData(json)) return ChartSeriesDataShape.pieLike;
  if (_hasCartesianData(json)) return ChartSeriesDataShape.cartesian;
  return ChartSeriesDataShape.unknown;
}

/// Suggest chart types that can consume [json] based on series-data shape.
List<ChartType> compatibleChartTypesForJson(
  Map<String, dynamic> json, {
  bool registeredOnly = true,
}) {
  final shape = inferSeriesDataShape(json);
  return compatibleChartTypesForShape(shape, registeredOnly: registeredOnly);
}

/// Checks whether [targetType] can safely consume [source] without throwing.
///
/// [isCompatible] means the target accepts the inferred source data shape
/// directly. [forceConversionAvailable] means Tenun can perform a supported
/// cross-shape conversion when `force: true` is used with
/// [switchChartTypeForSeriesShape].
ChartSwitchCompatibility chartSwitchCompatibilityForJson(
  Map<String, dynamic> source, {
  required ChartType targetType,
  bool registeredOnly = true,
}) {
  final sourceShape = inferSeriesDataShape(source);
  final targetShape = targetSeriesDataShape(targetType);
  final targetCapabilities = chartCapabilitiesForType(targetType);
  final targetRegistered =
      !registeredOnly || ChartRegistry.isRegistered(targetType);
  final compatibleTypes = compatibleChartTypesForShape(
    sourceShape,
    registeredOnly: registeredOnly,
  );
  final canonicalTargetType = canonicalChartType(targetType);
  final isCompatible =
      targetRegistered && compatibleTypes.contains(canonicalTargetType);
  final forceConversionAvailable =
      targetRegistered &&
      !isCompatible &&
      _hasSupportedForceConversion(source, targetType);

  return ChartSwitchCompatibility(
    targetType: targetType,
    sourceShape: sourceShape,
    targetShape: targetShape,
    isCompatible: isCompatible,
    forceConversionAvailable: forceConversionAvailable,
    targetRegistered: targetRegistered,
    compatibleTypes: compatibleTypes,
    targetCapabilities: targetCapabilities,
    reason: _switchCompatibilityReason(
      targetType: targetType,
      sourceShape: sourceShape,
      targetShape: targetShape,
      isCompatible: isCompatible,
      forceConversionAvailable: forceConversionAvailable,
      targetRegistered: targetRegistered,
      compatibleTypes: compatibleTypes,
    ),
  );
}

/// Suggest chart types that can consume [config] based on series-data shape.
List<ChartType> compatibleChartTypesForConfig(
  BaseChartConfig config, {
  bool registeredOnly = true,
}) {
  final probe = Map<String, dynamic>.from(config.toJson());
  probe['type'] = chartTypeToString(config.type);
  if ((probe['series'] is! List) || (probe['series'] as List).isEmpty) {
    probe['series'] = config.series.map((s) => s.toJson()).toList();
  }
  if (config.xAxisConfig?.categories != null &&
      config.xAxisConfig!.categories!.isNotEmpty) {
    final existingXAxis = _stringKeyedMapOrEmpty(probe['xAxis']);
    probe['xAxis'] = {...existingXAxis, 'data': config.xAxisConfig!.categories};
  }
  return compatibleChartTypesForJson(probe, registeredOnly: registeredOnly);
}

/// Switch chart type while preserving/normalizing data where possible.
///
/// Throws [StateError] when target type is not compatible (unless [force]).
Map<String, dynamic> switchChartTypeForSeriesShape(
  Map<String, dynamic> source, {
  required ChartType targetType,
  bool force = false,
}) {
  final compatibility = chartSwitchCompatibilityForJson(
    source,
    targetType: targetType,
    registeredOnly: false,
  );
  final canSwitch =
      compatibility.isCompatible ||
      (force && compatibility.forceConversionAvailable);
  if (!canSwitch) {
    throw StateError(compatibility.reason);
  }

  final normalized = _normalizeDataForTarget(source, targetType);
  normalized['type'] = chartTypeToString(targetType);
  return normalized;
}

/// Attempts to switch [source] to [targetType] without throwing.
///
/// Direct same-shape switches succeed without [force]. Cross-shape conversions
/// such as cartesian -> treemap/pie/candlestick require `force: true`.
ChartTypeSwitchResult trySwitchChartTypeForSeriesShape(
  Map<String, dynamic> source, {
  required ChartType targetType,
  bool force = false,
  bool registeredOnly = true,
}) {
  final compatibility = chartSwitchCompatibilityForJson(
    source,
    targetType: targetType,
    registeredOnly: registeredOnly,
  );
  final canSwitch =
      compatibility.isCompatible ||
      (force && compatibility.forceConversionAvailable);

  if (!canSwitch) {
    return ChartTypeSwitchResult(
      success: false,
      targetType: targetType,
      compatibility: compatibility,
      payload: null,
      usedForceConversion: false,
      preservedRuntimeKeys: const [],
      changedTopLevelKeys: const [],
      message: compatibility.reason,
    );
  }

  final payload = switchChartTypeForSeriesShape(
    source,
    targetType: targetType,
    force: force,
  );

  return ChartTypeSwitchResult(
    success: true,
    targetType: targetType,
    compatibility: compatibility,
    payload: payload,
    usedForceConversion: !compatibility.isCompatible,
    preservedRuntimeKeys: _preservedRuntimeKeys(source, payload),
    changedTopLevelKeys: _changedTopLevelKeys(source, payload),
    message: compatibility.isCompatible
        ? 'Switched to ${chartTypeToString(targetType)} without data conversion.'
        : 'Switched to ${chartTypeToString(targetType)} using force conversion.',
  );
}

/// Returns compatible target chart types ranked by [preferredOrder].
///
/// By default, current type is excluded so the first result is a true
/// alternative for runtime switching.
List<ChartType> rankedCompatibleChartTypesForJson(
  Map<String, dynamic> source, {
  List<ChartType>? preferredOrder,
  bool includeCurrentType = false,
  bool registeredOnly = true,
}) {
  final compatible = compatibleChartTypesForJson(
    source,
    registeredOnly: registeredOnly,
  );
  if (compatible.isEmpty) return const [];

  final ranked = <ChartType>[];
  for (final t in preferredOrder ?? const <ChartType>[]) {
    if (compatible.contains(t) && !ranked.contains(t)) {
      ranked.add(t);
    }
  }
  for (final t in compatible) {
    if (!ranked.contains(t)) {
      ranked.add(t);
    }
  }

  if (!includeCurrentType) {
    final current = _tryParseCanonicalType(source['type']);
    if (current != null) {
      ranked.remove(current);
    }
  }
  return ranked;
}

/// Returns ranked switch candidates with capabilities and preview payloads.
List<ChartSwitchOption> chartSwitchOptionsForJson(
  Map<String, dynamic> source, {
  List<ChartType>? preferredOrder,
  bool includeCurrentType = false,
  bool registeredOnly = true,
}) {
  final sourceShape = inferSeriesDataShape(source);
  final current = _tryParseCanonicalType(source['type']);
  final ranked = rankedCompatibleChartTypesForJson(
    source,
    preferredOrder: preferredOrder,
    includeCurrentType: includeCurrentType,
    registeredOnly: registeredOnly,
  );

  final options = <ChartSwitchOption>[];
  for (int i = 0; i < ranked.length; i++) {
    final type = ranked[i];
    final capabilities = chartCapabilitiesForType(type);
    final previewPayload = switchChartTypeForSeriesShape(
      source,
      targetType: type,
    );
    options.add(
      ChartSwitchOption(
        type: type,
        rank: i + 1,
        isCurrentType: current == type,
        sourceShape: sourceShape,
        capabilities: capabilities,
        previewPayload: previewPayload,
        reason: _switchReason(type, sourceShape, capabilities, current == type),
      ),
    );
  }
  return options;
}

/// Automatically switches [source] to the highest-ranked compatible chart
/// type for its inferred data shape.
Map<String, dynamic> switchChartTypeForSeriesShapeAuto(
  Map<String, dynamic> source, {
  List<ChartType>? preferredOrder,
  bool includeCurrentType = false,
  bool registeredOnly = true,
}) {
  final result = trySwitchChartTypeForSeriesShapeAuto(
    source,
    preferredOrder: preferredOrder,
    includeCurrentType: includeCurrentType,
    registeredOnly: registeredOnly,
  );
  if (!result.success || result.payload == null) {
    throw StateError(result.message);
  }
  return result.payload!;
}

/// Attempts to automatically switch [source] to the highest-ranked compatible
/// chart type without throwing.
ChartAutoSwitchResult trySwitchChartTypeForSeriesShapeAuto(
  Map<String, dynamic> source, {
  List<ChartType>? preferredOrder,
  bool includeCurrentType = false,
  bool registeredOnly = true,
}) {
  final sourceShape = inferSeriesDataShape(source);
  final options = chartSwitchOptionsForJson(
    source,
    preferredOrder: preferredOrder,
    includeCurrentType: includeCurrentType,
    registeredOnly: registeredOnly,
  );
  if (options.isEmpty) {
    return ChartAutoSwitchResult(
      success: false,
      sourceShape: sourceShape,
      selectedType: null,
      selectedOption: null,
      options: const [],
      payload: null,
      keptCurrentType: false,
      preservedRuntimeKeys: const [],
      changedTopLevelKeys: const [],
      message:
          'No compatible chart type found for data shape '
          '${sourceShape.name}.',
    );
  }

  final selected = options.first;
  final payload = selected.previewPayload;
  return ChartAutoSwitchResult(
    success: true,
    sourceShape: sourceShape,
    selectedType: selected.type,
    selectedOption: selected,
    options: options,
    payload: payload,
    keptCurrentType: selected.isCurrentType,
    preservedRuntimeKeys: _preservedRuntimeKeys(source, payload),
    changedTopLevelKeys: _changedTopLevelKeys(source, payload),
    message: selected.isCurrentType
        ? 'Kept current chart type ${selected.typeString}.'
        : 'Auto-switched to ${selected.typeString}.',
  );
}

const Set<ChartType> _externalDataModelTypes = {
  ChartType.gauge,
  ChartType.candlestick,
  ChartType.ohlc,
  ChartType.treemap,
  ChartType.sunburst,
  ChartType.sankey,
  ChartType.funnel,
  ChartType.waterfall,
  ChartType.network,
  ChartType.radial,
  ChartType.timeline,
  ChartType.wordcloud,
  ChartType.heatmap,
  ChartType.choropleth,
  ChartType.calendar,
  ChartType.calendarPie,
  ChartType.customizedPie,
  ChartType.pieLabelAlign,
  ChartType.pieSpecialLabel,
  ChartType.nestedPie,
  ChartType.halfDonut,
  ChartType.paddedPie,
  ChartType.nightingale,
  ChartType.partitionPie,
  ChartType.boxPlot,
  ChartType.errorBar,
  ChartType.bubble,
  ChartType.bullet,
  ChartType.functionPlot,
  ChartType.intradayLine,
  ChartType.lineClickAdd,
  ChartType.dynamicTimeSeries,
  ChartType.lineConfidenceBand,
  ChartType.largeScaleArea,
  ChartType.areaTimeAxis,
  ChartType.barRace,
  ChartType.areaBump,
  ChartType.gantt,
  ChartType.custom,
  ChartType.kagi,
  ChartType.renko,
  ChartType.macd,
};

const Set<ChartType> _priceOnlyFinancialTypes = {
  ChartType.kagi,
  ChartType.renko,
  ChartType.macd,
};

Map<String, dynamic> _normalizeDataForTarget(
  Map<String, dynamic> source,
  ChartType targetType,
) {
  final out = Map<String, dynamic>.from(source);

  if (hierarchicalTypes.contains(targetType)) {
    final nodes =
        _extractHierarchicalNodes(source) ??
        _buildHierarchyNodesFromFlatSeries(source);
    if (nodes != null) {
      out['series'] = [
        {'data': nodes},
      ];
      out.remove('xAxis');
      out.remove('yAxis');
      out.remove('categories');
    }
    return out;
  }

  if (pieLikeTypes.contains(targetType)) {
    final pieData =
        _extractPieData(source) ?? _buildPieDataFromFlatSeries(source);
    if (pieData != null) {
      out['series'] = [
        {'data': pieData},
      ];
    }
    return out;
  }

  if (financialTypes.contains(targetType)) {
    if (_priceOnlyFinancialTypes.contains(targetType)) {
      final prices =
          _extractFinancialCloseSeries(source) ?? _extractFlatSeries(source);
      if (prices != null) {
        out['series'] = prices.$1;
        if (prices.$2.isNotEmpty) {
          out['xAxis'] = {
            ..._stringKeyedMapOrEmpty(out['xAxis']),
            'data': prices.$2,
          };
        }
      }
      return out;
    }

    final ohlc =
        _extractOhlcSeries(source) ?? _buildOhlcSeriesFromFlatSeries(source);
    if (ohlc != null) {
      out['series'] = ohlc.$1;
      if (ohlc.$2.isNotEmpty) {
        out['xAxis'] = {
          ..._stringKeyedMapOrEmpty(out['xAxis']),
          'data': ohlc.$2,
        };
      }
    }
    return out;
  }

  if (cartesianTypes.contains(targetType)) {
    final flat = _extractFlatSeries(source);
    if (flat != null) {
      out['series'] = flat.$1;
      if (flat.$2.isNotEmpty) {
        out['xAxis'] = {
          ..._stringKeyedMapOrEmpty(out['xAxis']),
          'data': flat.$2,
        };
      }
    }
    return out;
  }

  return out;
}

bool _supportsSampling(ChartType type, ChartSeriesDataShape shape) {
  if (shape == ChartSeriesDataShape.cartesian ||
      shape == ChartSeriesDataShape.financial) {
    return true;
  }
  return switch (type) {
    ChartType.heatmap ||
    ChartType.sparklineMatrix ||
    ChartType.calendar ||
    ChartType.calendarPie => true,
    _ => false,
  };
}

bool _supportsZoom(ChartType type, ChartSeriesDataShape shape) {
  if (type == ChartType.sparkline ||
      type == ChartType.gauge ||
      type == ChartType.indicator ||
      type == ChartType.custom) {
    return false;
  }
  return switch (shape) {
    ChartSeriesDataShape.cartesian ||
    ChartSeriesDataShape.financial ||
    ChartSeriesDataShape.matrix ||
    ChartSeriesDataShape.calendar ||
    ChartSeriesDataShape.geospatial ||
    ChartSeriesDataShape.graph => true,
    _ => false,
  };
}

bool _supportsDrilldown(ChartType type, ChartSeriesDataShape shape) {
  if (shape == ChartSeriesDataShape.hierarchical ||
      shape == ChartSeriesDataShape.pieLike ||
      shape == ChartSeriesDataShape.flow ||
      shape == ChartSeriesDataShape.graph ||
      shape == ChartSeriesDataShape.calendar ||
      shape == ChartSeriesDataShape.geospatial) {
    return true;
  }
  return switch (type) {
    ChartType.bar ||
    ChartType.stackedBar ||
    ChartType.groupedBar ||
    ChartType.horizontalBar ||
    ChartType.stackedHorizontalBar ||
    ChartType.barBackground ||
    ChartType.barGradient ||
    ChartType.barRounded ||
    ChartType.barNormalized ||
    ChartType.negativeBar ||
    ChartType.rainfall ||
    ChartType.pareto => true,
    _ => false,
  };
}

bool _supportsLegend(ChartType type) {
  return switch (type) {
    ChartType.sparkline ||
    ChartType.gauge ||
    ChartType.indicator ||
    ChartType.wordcloud ||
    ChartType.custom => false,
    _ => true,
  };
}

bool _supportsTooltip(ChartType type) {
  return switch (type) {
    ChartType.custom => false,
    _ => true,
  };
}

String _switchReason(
  ChartType type,
  ChartSeriesDataShape sourceShape,
  ChartCapabilities capabilities,
  bool isCurrentType,
) {
  if (isCurrentType) {
    return 'Current ${capabilities.dataShape.name} chart type.';
  }

  final features = <String>[];
  if (capabilities.supportsSampling) features.add('sampling');
  if (capabilities.supportsZoom) features.add('zoom');
  if (capabilities.supportsDrilldown) features.add('drilldown');
  final suffix = features.isEmpty ? '' : ' with ${features.join(', ')}';
  return 'Compatible ${capabilities.dataShape.name} target for '
      '${sourceShape.name} data$suffix.';
}

String _switchCompatibilityReason({
  required ChartType targetType,
  required ChartSeriesDataShape sourceShape,
  required ChartSeriesDataShape targetShape,
  required bool isCompatible,
  required bool forceConversionAvailable,
  required bool targetRegistered,
  required List<ChartType> compatibleTypes,
}) {
  final target = chartTypeToString(targetType);
  if (!targetRegistered) {
    return 'Target "$target" is not registered in the active registry.';
  }
  if (sourceShape == ChartSeriesDataShape.unknown) {
    return 'Cannot infer source data shape, so "$target" cannot be switched safely.';
  }
  if (isCompatible) {
    return '"$target" accepts ${sourceShape.name} data directly.';
  }
  if (forceConversionAvailable) {
    return '"$target" requires force conversion from ${sourceShape.name} to ${targetShape.name}.';
  }
  final compatible = compatibleTypes.isEmpty
      ? 'none'
      : compatibleTypes.map(chartTypeToString).join(', ');
  return '"$target" expects ${targetShape.name} data, but source is ${sourceShape.name}. Compatible targets: $compatible.';
}

class _RegistrationKeyEntry {
  final String rawKey;
  final String normalizedKey;

  const _RegistrationKeyEntry({
    required this.rawKey,
    required this.normalizedKey,
  });
}

class _RegistrationKeyOwner {
  final ChartRegistration registration;
  final String rawKey;

  const _RegistrationKeyOwner({
    required this.registration,
    required this.rawKey,
  });
}

Iterable<_RegistrationKeyEntry> _registrationKeyEntries(
  ChartRegistration reg,
) sync* {
  final typeString = _registrationRawKey(reg.typeString);
  if (typeString != null) yield _registrationKeyEntry(typeString);
  for (final alias in reg.aliases) {
    final key = _registrationRawKey(alias);
    if (key != null) yield _registrationKeyEntry(key);
  }
}

String? _registrationRawKey(String key) {
  final trimmed = key.trim().toLowerCase();
  return trimmed.isEmpty ? null : trimmed;
}

_RegistrationKeyEntry _registrationKeyEntry(String rawKey) =>
    _RegistrationKeyEntry(
      rawKey: rawKey,
      normalizedKey: normalizeChartTypeKey(rawKey),
    );

List<ChartCapabilities> _capabilitiesForBundle(
  RegistrationBundle bundle, {
  required bool registeredOnly,
}) {
  final seen = <ChartType>{};
  final out = <ChartCapabilities>[];
  for (final reg in bundle.registrations) {
    if (registeredOnly && !ChartRegistry.isRegistered(reg.type)) continue;
    if (!seen.add(reg.type)) continue;
    out.add(chartCapabilitiesForRegistration(reg));
  }
  return out;
}

ChartRegistration? _registrationForTypeInBundle(
  ChartType type,
  RegistrationBundle bundle,
) {
  for (final reg in bundle.registrations) {
    if (reg.type == type) return reg;
  }
  return null;
}

Map<ChartSeriesDataShape, int> _shapeCounts(
  List<ChartCapabilities> capabilities,
) {
  final out = <ChartSeriesDataShape, int>{};
  for (final capability in capabilities) {
    out[capability.dataShape] = (out[capability.dataShape] ?? 0) + 1;
  }
  final entries = out.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return Map.fromEntries(entries);
}

Map<String, int> _featureCounts(List<ChartCapabilities> capabilities) {
  int count(bool Function(ChartCapabilities capability) test) =>
      capabilities.where(test).length;

  return {
    'sampling': count((capability) => capability.supportsSampling),
    'zoom': count((capability) => capability.supportsZoom),
    'drilldown': count((capability) => capability.supportsDrilldown),
    'legend': count((capability) => capability.supportsLegend),
    'tooltip': count((capability) => capability.supportsTooltip),
    'switchable': count((capability) => capability.supportsRuntimeSwitching),
  };
}

List<ChartSwitchGroup> _switchGroups(List<ChartCapabilities> capabilities) {
  final grouped = <ChartSeriesDataShape, List<ChartCapabilities>>{};
  for (final capability in capabilities) {
    if (!capability.supportsRuntimeSwitching ||
        capability.dataShape == ChartSeriesDataShape.unknown) {
      continue;
    }
    grouped.putIfAbsent(capability.dataShape, () => []).add(capability);
  }

  final groups = grouped.entries.where((entry) => entry.value.length > 1).map((
    entry,
  ) {
    final charts = entry.value.toList()
      ..sort((a, b) => a.typeString.compareTo(b.typeString));
    return ChartSwitchGroup(dataShape: entry.key, charts: charts);
  }).toList();
  groups.sort((a, b) {
    final count = b.count.compareTo(a.count);
    if (count != 0) return count;
    return a.dataShape.name.compareTo(b.dataShape.name);
  });
  return groups;
}

List<ChartPayloadContract> _payloadContractsForCapabilities(
  List<ChartCapabilities> capabilities,
) {
  final seen = <ChartType>{};
  final out = <ChartPayloadContract>[];
  for (final capability in capabilities) {
    if (!seen.add(capability.type)) continue;
    out.add(chartPayloadContractForType(capability.type));
  }
  return out;
}

Map<String, int> _payloadStrategyCounts(List<ChartPayloadContract> contracts) {
  final out = <String, int>{};
  for (final contract in contracts) {
    final key = contract.seriesStrategy.name;
    out[key] = (out[key] ?? 0) + 1;
  }
  final entries = out.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return Map.fromEntries(entries);
}

Map<String, int> _payloadFeatureCounts(List<ChartPayloadContract> contracts) {
  int count(bool Function(ChartPayloadContract contract) test) =>
      contracts.where(test).length;

  return {
    'shorthandCollections': count((contract) {
      if (contract.seriesStrategy != ChartPayloadSeriesStrategy.dataFields) {
        return true;
      }
      return contract.dataFieldPriority.length > 1 ||
          (contract.dataFieldPriority.isNotEmpty &&
              contract.dataFieldPriority.first != 'data');
    }),
    'externalDataModel': count((contract) => contract.usesExternalDataModel),
    'requiresSeries': count((contract) => contract.requiresSeries),
    'optionalSeries': count((contract) => !contract.requiresSeries),
  };
}

Map<String, int> _apiContractUsageCounts(List<ChartCapabilities> capabilities) {
  final out = <String, int>{};
  for (final capability in capabilities) {
    final key = capability.apiContract.name;
    out[key] = (out[key] ?? 0) + 1;
  }
  final entries = out.entries.toList()
    ..sort((a, b) {
      final count = b.value.compareTo(a.value);
      if (count != 0) return count;
      return a.key.compareTo(b.key);
    });
  return Map.fromEntries(entries);
}

Map<String, int> _apiFieldCategoryCounts(List<ChartApiContract> contracts) {
  final out = <String, int>{};
  for (final contract in contracts) {
    for (final spec in contract.supportedSpecs) {
      final key = spec.category.name;
      out[key] = (out[key] ?? 0) + 1;
    }
  }
  final entries = out.entries.toList()
    ..sort((a, b) {
      final count = b.value.compareTo(a.value);
      if (count != 0) return count;
      return a.key.compareTo(b.key);
    });
  return Map.fromEntries(entries);
}

bool _hasSupportedForceConversion(
  Map<String, dynamic> source,
  ChartType targetType,
) {
  if (hierarchicalTypes.contains(targetType)) {
    return _extractHierarchicalNodes(source) != null ||
        _buildHierarchyNodesFromFlatSeries(source) != null;
  }
  if (pieLikeTypes.contains(targetType)) {
    return _extractPieData(source) != null ||
        _buildPieDataFromFlatSeries(source) != null;
  }
  if (financialTypes.contains(targetType)) {
    if (_priceOnlyFinancialTypes.contains(targetType)) {
      return _extractFinancialCloseSeries(source) != null ||
          _extractFlatSeries(source) != null;
    }
    return _extractOhlcSeries(source) != null ||
        _buildOhlcSeriesFromFlatSeries(source) != null;
  }
  if (cartesianTypes.contains(targetType)) {
    return _extractFlatSeries(source) != null;
  }
  return false;
}

bool _hasCartesianData(Map<String, dynamic> json) {
  final series = _seriesList(json);
  if (series.isEmpty) return false;
  final first = series.first['data'];
  if (first is! List || first.isEmpty) return false;
  final item = first.first;
  return _numericValue(item) != null || item is List || item is Map;
}

bool _hasPieLikeData(Map<String, dynamic> json) {
  final series = _seriesList(json);
  if (series.isEmpty) return false;
  final data = series.first['data'];
  if (data is! List || data.isEmpty) return false;
  final item = data.first;
  return item is Map &&
      !item.containsKey('children') &&
      (item.containsKey('value') ||
          item.containsKey('name') ||
          (item.containsKey('text') && item.containsKey('weight')));
}

bool _hasHierarchicalData(Map<String, dynamic> json) =>
    _extractHierarchicalNodes(json) != null;

bool _dataCanRepresentDeclaredShape(
  Map<String, dynamic> json,
  ChartSeriesDataShape shape,
) {
  return switch (shape) {
    ChartSeriesDataShape.cartesian =>
      _hasCartesianData(json) &&
          !_hasHierarchicalData(json) &&
          !_hasPieLikeData(json) &&
          !_hasMatrixData(json) &&
          !_hasGraphData(json) &&
          !_hasFlowData(json) &&
          !_hasFinancialData(json) &&
          !_hasGeospatialData(json) &&
          !_hasCalendarData(json),
    ChartSeriesDataShape.pieLike =>
      _hasPieLikeData(json) && !_hasHierarchicalData(json),
    ChartSeriesDataShape.hierarchical => _hasHierarchicalData(json),
    ChartSeriesDataShape.matrix =>
      _hasMatrixData(json) || _hasParallelTableData(json),
    ChartSeriesDataShape.graph => _hasGraphData(json),
    ChartSeriesDataShape.flow => _hasFlowData(json),
    ChartSeriesDataShape.financial => _hasFinancialData(json),
    ChartSeriesDataShape.radial =>
      _hasRadialData(json) || _hasCartesianData(json) || _hasPieLikeData(json),
    ChartSeriesDataShape.calendar => _hasCalendarData(json),
    ChartSeriesDataShape.geospatial => _hasGeospatialData(json),
    ChartSeriesDataShape.unknown => false,
  };
}

bool _hasMatrixData(Map<String, dynamic> json) {
  final series = _seriesList(json);
  if (series.isEmpty) return false;
  final data = series.first['data'];
  if (data is! List || data.isEmpty) return false;
  final item = data.first;
  if (item is List && item.length == 3 && _numericValue(item[2]) != null) {
    return true;
  }
  return item is Map &&
      (item.containsKey('x') || item.containsKey('row')) &&
      (item.containsKey('y') || item.containsKey('col')) &&
      item.containsKey('value');
}

bool _hasParallelTableData(Map<String, dynamic> json) {
  if (json['axes'] is! List) return false;
  final series = _seriesList(json);
  if (series.isEmpty) return false;
  final data = series.first['data'];
  if (data is! List || data.isEmpty) return false;
  final item = data.first;
  if (item is! List || item.length < 2) return false;
  return item.any((value) => _numericValue(value) != null);
}

bool _hasRadialData(Map<String, dynamic> json) {
  final declaredType = _tryParseCanonicalType(json['type']);
  final declaredRadial =
      declaredType != null &&
      targetSeriesDataShape(declaredType) == ChartSeriesDataShape.radial;
  if (declaredRadial && _numericValue(json['value']) != null) return true;
  if (_numericValue(json['value']) != null &&
      (json.containsKey('min') ||
          json.containsKey('max') ||
          json.containsKey('unit') ||
          json.containsKey('bands') ||
          json.containsKey('previousValue'))) {
    return true;
  }
  return false;
}

bool _hasGraphData(Map<String, dynamic> json) {
  if (json['nodes'] is List && json['links'] is List) return true;
  final series = _seriesList(json);
  if (series.isEmpty) return false;
  final data = series.first['data'];
  if (data is! List || data.isEmpty) return false;
  final item = data.first;
  return item is Map &&
      (item.containsKey('source') || item.containsKey('target'));
}

bool _hasFlowData(Map<String, dynamic> json) {
  final type = normalizeChartTypeKey(json['type']);
  if (type == 'sankey' || type == 'funnel' || type == 'waterfall') return true;
  final series = _seriesList(json);
  if (series.isEmpty) return false;
  final data = series.first['data'];
  if (data is! List || data.isEmpty) return false;
  final item = data.first;
  return item is Map &&
      item.containsKey('source') &&
      item.containsKey('target');
}

bool _hasFinancialData(Map<String, dynamic> json) {
  final type = normalizeChartTypeKey(json['type']);
  if (type == 'candlestick' ||
      type == 'ohlc' ||
      type == 'kagi' ||
      type == 'renko' ||
      type == 'macd') {
    return true;
  }
  final series = _seriesList(json);
  if (series.isEmpty) return false;
  final data = series.first['data'];
  if (data is! List || data.isEmpty) return false;
  final item = data.first;
  if (item is List && item.length >= 4) return true;
  return item is Map &&
      item.containsKey('open') &&
      item.containsKey('high') &&
      item.containsKey('low') &&
      item.containsKey('close');
}

bool _hasGeospatialData(Map<String, dynamic> json) {
  final type = normalizeChartTypeKey(json['type']);
  if (type == 'choropleth') return true;
  if (json['features'] is List || json['geoJson'] != null) return true;
  final series = _seriesList(json);
  if (series.isEmpty) return false;
  final data = series.first['data'];
  if (data is! List || data.isEmpty) return false;
  final item = data.first;
  return item is Map &&
      (item.containsKey('region') ||
          item.containsKey('iso') ||
          item.containsKey('geometry'));
}

bool _hasCalendarData(Map<String, dynamic> json) {
  final type = normalizeChartTypeKey(json['type']);
  if (type == 'calendar' || type == 'calendarpie') return true;
  final series = _seriesList(json);
  if (series.isEmpty) return false;
  final data = series.first['data'];
  if (data is! List || data.isEmpty) return false;
  final item = data.first;
  return item is Map &&
      (item.containsKey('date') ||
          item.containsKey('day') ||
          item.containsKey('time'));
}

List<Map<String, dynamic>> _seriesList(Map<String, dynamic> json) {
  final rawSeries = json['series'];
  if (rawSeries is List) {
    final mapped = _stringKeyedMapList(rawSeries);
    if (mapped.isNotEmpty) return mapped;
    if (rawSeries.isNotEmpty) {
      return [
        {'data': List<dynamic>.from(rawSeries)},
      ];
    }
  }
  if (rawSeries is Map) {
    final mapped = _stringKeyedMap(rawSeries);
    if (mapped.containsKey('data')) return [mapped];
  }

  final shorthand = _seriesFromTopLevelData(json);
  return shorthand == null ? const [] : [shorthand];
}

Map<String, dynamic>? _seriesFromTopLevelData(Map<String, dynamic> json) {
  final declaredType = _tryParseCanonicalType(json['type']);
  if (declaredType != null) {
    final contract = chartPayloadContractForType(declaredType);
    for (final field in contract.dataFieldPriority) {
      final value = json[field];
      if (value is List && value.isNotEmpty) return {'data': value};
    }
    final namedField = contract.namedCollectionField;
    if (namedField != null) {
      final value = json[namedField];
      if (value is List && value.isNotEmpty) return {'data': value};
    }
  }

  for (final field in const ['data', 'values', 'points', 'items']) {
    final value = json[field];
    if (value is List && value.isNotEmpty) return {'data': value};
  }
  return null;
}

List<Map<String, dynamic>> _stringKeyedMapList(Iterable<dynamic> values) {
  final out = <Map<String, dynamic>>[];
  for (final value in values) {
    if (value is Map) out.add(_stringKeyedMap(value));
  }
  return out;
}

Map<String, dynamic> _stringKeyedMap(Map value) {
  return <String, dynamic>{
    for (final entry in value.entries) entry.key.toString(): entry.value,
  };
}

Map<String, dynamic> _stringKeyedMapOrEmpty(Object? value) =>
    value is Map ? _stringKeyedMap(value) : <String, dynamic>{};

ChartType? _tryParseCanonicalType(dynamic rawType) {
  if (rawType is! String || rawType.trim().isEmpty) return null;
  final registered = ChartRegistry.registrationForString(rawType);
  if (registered != null) return registered.type;

  final normalized = _normalizeTypeToken(rawType);
  for (final type in ChartType.values) {
    if (_normalizeTypeToken(chartTypeToString(type)) == normalized) {
      return type;
    }
  }
  final fallback = getChartType(rawType);
  if (fallback != ChartType.line || normalized == 'line') {
    return fallback;
  }
  return null;
}

String _normalizeTypeToken(String type) => normalizeChartTypeKey(type);

List<Map<String, dynamic>>? _extractHierarchicalNodes(
  Map<String, dynamic> json,
) {
  final declaredType = _tryParseCanonicalType(json['type']);
  final declaredHierarchical =
      declaredType != null && hierarchicalTypes.contains(declaredType);
  final series = _seriesList(json);
  if (series.isEmpty) return null;
  final data = series.first['data'];
  if (data is! List || data.isEmpty) return null;
  final nodes = _stringKeyedMapList(data);
  if (nodes.isEmpty) return null;
  final hasTreeMarkers =
      nodes.any((node) => node.containsKey('children')) ||
      (declaredHierarchical &&
          (nodes.first.containsKey('name') ||
              nodes.first.containsKey('value')));
  return hasTreeMarkers ? nodes : null;
}

List<Map<String, dynamic>>? _buildHierarchyNodesFromFlatSeries(
  Map<String, dynamic> json,
) {
  final flat = _extractFlatSeries(json);
  if (flat == null || flat.$1.isEmpty) return null;
  final firstData = (flat.$1.first['data'] as List?) ?? const [];
  final labels = flat.$2;
  if (firstData.isEmpty) return null;
  return List.generate(firstData.length, (i) {
    final raw = firstData[i];
    final value =
        _numericValue(raw) ??
        (raw is Map ? _numericValue(raw['value']) : null) ??
        0.0;
    final name = i < labels.length ? labels[i] : 'Item ${i + 1}';
    return {'name': name, 'value': value};
  });
}

List<Map<String, dynamic>>? _extractPieData(Map<String, dynamic> json) {
  final series = _seriesList(json);
  if (series.isEmpty) return null;
  final data = series.first['data'];
  if (data is! List || data.isEmpty) return null;
  final mapped = _stringKeyedMapList(data);
  if (mapped.isEmpty) return null;
  return mapped.map(_normalizePieDatum).toList(growable: false);
}

Map<String, dynamic> _normalizePieDatum(Map<String, dynamic> item) {
  final out = Map<String, dynamic>.from(item);
  out['name'] ??= out['label'] ?? out['text'];
  out['value'] ??= out['weight'] ?? out['count'] ?? out['size'];
  return out;
}

List<Map<String, dynamic>>? _buildPieDataFromFlatSeries(
  Map<String, dynamic> json,
) {
  final flat = _extractFlatSeries(json);
  if (flat == null || flat.$1.isEmpty) return null;
  final firstData = (flat.$1.first['data'] as List?) ?? const [];
  final labels = flat.$2;
  if (firstData.isEmpty) return null;
  return List.generate(firstData.length, (i) {
    final raw = firstData[i];
    final value =
        _numericValue(raw) ??
        (raw is Map ? _numericValue(raw['value']) : null) ??
        0.0;
    return {
      'name': i < labels.length ? labels[i] : 'Item ${i + 1}',
      'value': value,
    };
  });
}

/// Returns `(series, labels)` with each data item in OHLC tuple shape.
(List<Map<String, dynamic>>, List<String>)? _extractOhlcSeries(
  Map<String, dynamic> json,
) {
  final series = _seriesList(json);
  if (series.isEmpty) return null;

  final labels = _xAxisLabels(json);
  final out = <Map<String, dynamic>>[];
  for (final s in series) {
    final rawData = s['data'];
    if (rawData is! List || rawData.isEmpty) continue;
    if (!_isOhlcLike(rawData.first)) return null;
    out.add({...s, 'data': List<dynamic>.from(rawData)});
  }
  return out.isEmpty ? null : (out, labels);
}

/// Builds simple synthetic OHLC tuples from flat numeric series.
(List<Map<String, dynamic>>, List<String>)? _buildOhlcSeriesFromFlatSeries(
  Map<String, dynamic> json,
) {
  final flat = _extractFlatSeries(json);
  if (flat == null || flat.$1.isEmpty) return null;

  final out = <Map<String, dynamic>>[];
  for (final s in flat.$1) {
    final rawData = s['data'];
    if (rawData is! List || rawData.isEmpty) continue;
    final tuples = <List<double>>[];
    for (final item in rawData) {
      final price = _numericValue(item);
      if (price == null) continue;
      tuples.add([price, price * 1.02, price * 0.98, price]);
    }
    if (tuples.isNotEmpty) {
      out.add({...s, 'data': tuples});
    }
  }

  return out.isEmpty ? null : (out, flat.$2);
}

/// Returns `(series, labels)` with OHLC data flattened to close prices.
(List<Map<String, dynamic>>, List<String>)? _extractFinancialCloseSeries(
  Map<String, dynamic> json,
) {
  if (!_hasFinancialData(json)) return null;

  final series = _seriesList(json);
  if (series.isEmpty) return null;

  var labels = _xAxisLabels(json);
  final inferredLabels = <String>[];
  final out = <Map<String, dynamic>>[];

  for (final s in series) {
    final rawData = s['data'];
    if (rawData is! List || rawData.isEmpty) continue;
    final values = <double>[];
    for (var i = 0; i < rawData.length; i++) {
      final item = rawData[i];
      final close = _closeValue(item);
      if (close == null) continue;
      values.add(close);
      if (labels.isEmpty) {
        inferredLabels.add(_financialLabel(item, i));
      }
    }
    if (values.isNotEmpty) {
      out.add({...s, 'data': values});
    }
  }

  if (labels.isEmpty) labels = inferredLabels;
  return out.isEmpty ? null : (out, labels);
}

/// Returns `(series, labels)` in cartesian-friendly shape.
(List<Map<String, dynamic>>, List<String>)? _extractFlatSeries(
  Map<String, dynamic> json,
) {
  final financial = _extractFinancialCloseSeries(json);
  if (financial != null) return financial;

  final series = _seriesList(json);
  if (series.isEmpty) return null;

  var labels = _xAxisLabels(json);

  // Pie/hierarchical -> flatten first series to numeric list
  final firstData = series.first['data'];
  if (firstData is List && firstData.isNotEmpty && firstData.first is Map) {
    final mapped = firstData.whereType<Map>().toList();
    if (mapped.isNotEmpty) {
      final values = mapped
          .map((m) => _numericValue(m['value'] ?? m['weight']) ?? 0.0)
          .toList();
      final names = mapped.map((m) {
        return (m['name'] ?? m['label'] ?? m['text'] ?? 'Item').toString();
      }).toList();
      if (labels.isEmpty) labels = names;
      return (
        [
          {'name': series.first['name'] ?? 'Series 1', 'data': values},
        ],
        labels,
      );
    }
  }

  return (series, labels);
}

List<String> _xAxisLabels(Map<String, dynamic> json) {
  final xAxis = (json['xAxis'] is Map) ? (json['xAxis'] as Map) : null;
  final xData = xAxis?['data'];
  if (xData is List) {
    return xData.map((e) => e.toString()).toList();
  }
  final categories = json['categories'] ?? json['labels'];
  if (categories is List) {
    return categories.map((e) => e.toString()).toList();
  }
  return <String>[];
}

bool _isOhlcLike(Object? item) {
  if (item is Map) {
    return item.containsKey('open') &&
        item.containsKey('high') &&
        item.containsKey('low') &&
        item.containsKey('close');
  }
  if (item is List && item.length >= 4) {
    return _closeValue(item) != null;
  }
  return false;
}

double? _closeValue(Object? item) {
  if (item is num) return item.toDouble();
  if (item is Map) {
    return _numericValue(item['close'] ?? item['value'] ?? item['price']);
  }
  if (item is List) {
    if (item.length >= 5 && item.first is! num) {
      return _numericValue(item[4]);
    }
    if (item.length >= 4) return _numericValue(item[3]);
  }
  return null;
}

double? _numericValue(Object? raw) {
  if (raw is num && raw.isFinite) return raw.toDouble();
  if (raw is String) {
    final value = double.tryParse(raw.trim());
    if (value != null && value.isFinite) return value;
  }
  if (raw is Map) {
    return _numericValue(
      raw['value'] ?? raw['y'] ?? raw['size'] ?? raw['weight'],
    );
  }
  if (raw is List && raw.isNotEmpty) {
    for (final item in raw.reversed) {
      final value = _numericValue(item);
      if (value != null) return value;
    }
  }
  return null;
}

List<String> _preservedRuntimeKeys(
  Map<String, dynamic> source,
  Map<String, dynamic> target,
) {
  return _runtimeStateKeys
      .where((key) => source.containsKey(key) && target.containsKey(key))
      .where(
        (key) =>
            identical(source[key], target[key]) || source[key] == target[key],
      )
      .toList(growable: false);
}

List<String> _changedTopLevelKeys(
  Map<String, dynamic> source,
  Map<String, dynamic> target,
) {
  final keys = <String>{...source.keys, ...target.keys}.toList()..sort();
  return keys
      .where((key) => source[key] != target[key])
      .toList(growable: false);
}

const Set<String> _runtimeStateKeys = {
  'title',
  'legend',
  'tooltip',
  'grid',
  'toolbox',
  'theme',
  'sampling',
  'dataMode',
  'datasetMode',
  'largeData',
  'largeDataMode',
  'animation',
  'interaction',
  'zoom',
  'dataZoom',
  'viewport',
  'drilldown',
  'selected',
  'selectedData',
  'visibleSeries',
  'controllerState',
  'runtime',
};

String _financialLabel(Object? item, int index) {
  if (item is Map) {
    final label = item['date'] ?? item['time'] ?? item['name'];
    if (label != null) return label.toString();
  }
  if (item is List && item.length >= 5 && item.first is! num) {
    return item.first.toString();
  }
  return 'Item ${index + 1}';
}
