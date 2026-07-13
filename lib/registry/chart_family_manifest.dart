import '../core/chart_api_contract.dart';
import '../core/chart_registry.dart';
import '../core/chart_type.dart';
import 'chart_registration_bundle.dart';
import 'registry_tools.dart';

/// Public API surfaces that can expose chart family metadata.
enum ChartFamilyManifestSurface { config }

/// Describes one chart family in the public Tenun package surface.
class ChartFamilyManifestEntry {
  final ChartType type;
  final String typeString;
  final String displayName;
  final String description;
  final ChartFamilyManifestSurface surface;
  final List<String> bundleNames;
  final String primaryBundleName;
  final ChartSeriesDataShape dataShape;
  final ChartPayloadSeriesStrategy seriesStrategy;
  final List<String> dataFieldPriority;
  final String? namedCollectionField;
  final bool requiresSeries;
  final bool usesExternalDataModel;
  final ChartApiContract apiContract;
  final List<String> supportedFields;
  final List<String> recommendedFields;
  final bool isRegistered;
  final bool supportsSampling;
  final bool supportsZoom;
  final bool supportsDrilldown;
  final bool supportsLegend;
  final bool supportsTooltip;
  final bool supportsRuntimeSwitching;
  final List<String> aliases;
  final List<String> tags;
  final String publicExportPath;
  final String showcaseExampleKey;

  const ChartFamilyManifestEntry({
    required this.type,
    required this.typeString,
    required this.displayName,
    required this.description,
    required this.surface,
    required this.bundleNames,
    required this.primaryBundleName,
    required this.dataShape,
    required this.seriesStrategy,
    required this.dataFieldPriority,
    required this.requiresSeries,
    required this.usesExternalDataModel,
    required this.apiContract,
    required this.supportedFields,
    required this.recommendedFields,
    required this.isRegistered,
    required this.supportsSampling,
    required this.supportsZoom,
    required this.supportsDrilldown,
    required this.supportsLegend,
    required this.supportsTooltip,
    required this.supportsRuntimeSwitching,
    required this.aliases,
    required this.tags,
    required this.publicExportPath,
    required this.showcaseExampleKey,
    this.namedCollectionField,
  });

  String get normalizedTypeKey => normalizeChartTypeKey(typeString);

  bool get supportsShorthandCollections {
    return dataFieldPriority.isNotEmpty ||
        namedCollectionField != null ||
        seriesStrategy != ChartPayloadSeriesStrategy.dataFields;
  }

  bool belongsToBundle(String bundleName) {
    final normalized = _normalizeManifestKey(bundleName);
    return bundleNames.any((name) => _normalizeManifestKey(name) == normalized);
  }

  bool supportsApiField(String field) => apiContract.supports(field);

  Map<String, dynamic> toJson() => {
    'type': typeString,
    'displayName': displayName,
    'description': description,
    'surface': surface.name,
    'bundleNames': List<String>.from(bundleNames),
    'primaryBundleName': primaryBundleName,
    'dataShape': dataShape.name,
    'seriesStrategy': seriesStrategy.name,
    'dataFieldPriority': List<String>.from(dataFieldPriority),
    if (namedCollectionField != null)
      'namedCollectionField': namedCollectionField,
    'requiresSeries': requiresSeries,
    'usesExternalDataModel': usesExternalDataModel,
    'supportsShorthandCollections': supportsShorthandCollections,
    'apiContract': apiContract.name,
    'apiFamily': apiContract.family.name,
    'supportedFields': List<String>.from(supportedFields),
    'recommendedFields': List<String>.from(recommendedFields),
    'isRegistered': isRegistered,
    'supportsSampling': supportsSampling,
    'supportsZoom': supportsZoom,
    'supportsDrilldown': supportsDrilldown,
    'supportsLegend': supportsLegend,
    'supportsTooltip': supportsTooltip,
    'supportsRuntimeSwitching': supportsRuntimeSwitching,
    if (aliases.isNotEmpty) 'aliases': List<String>.from(aliases),
    if (tags.isNotEmpty) 'tags': List<String>.from(tags),
    'publicExportPath': publicExportPath,
    'showcaseExampleKey': showcaseExampleKey,
  };
}

/// Immutable catalog of chart families available from a registration bundle.
class ChartFamilyManifest {
  final String name;
  final String description;
  final List<ChartFamilyManifestEntry> entries;

  const ChartFamilyManifest({
    required this.name,
    required this.description,
    required this.entries,
  });

  int get count => entries.length;

  List<String> get typeStrings {
    return [for (final entry in entries) entry.typeString];
  }

  ChartFamilyManifestEntry? entryForType(ChartType type) {
    final canonicalType = canonicalChartType(type);
    for (final entry in entries) {
      if (entry.type == canonicalType) return entry;
    }
    return null;
  }

  ChartFamilyManifestEntry? entryForTypeString(String typeString) {
    final normalized = normalizeChartTypeKey(typeString);
    for (final entry in entries) {
      if (entry.normalizedTypeKey == normalized) return entry;
      for (final alias in entry.aliases) {
        if (normalizeChartTypeKey(alias) == normalized) return entry;
      }
    }
    return null;
  }

  List<ChartFamilyManifestEntry> forBundle(String bundleName) {
    return [
      for (final entry in entries)
        if (entry.belongsToBundle(bundleName)) entry,
    ];
  }

  List<ChartFamilyManifestEntry> forDataShape(ChartSeriesDataShape shape) {
    return [
      for (final entry in entries)
        if (entry.dataShape == shape) entry,
    ];
  }

  List<ChartFamilyManifestEntry> forApiContract(String contractName) {
    final normalized = _normalizeManifestKey(contractName);
    return [
      for (final entry in entries)
        if (_normalizeManifestKey(entry.apiContract.name) == normalized) entry,
    ];
  }

  List<ChartFamilyManifestEntry> forTag(String tag) {
    final normalized = _normalizeManifestKey(tag);
    return [
      for (final entry in entries)
        if (entry.tags.any((tag) => _normalizeManifestKey(tag) == normalized))
          entry,
    ];
  }

  Map<String, int> get bundleCounts {
    final out = <String, int>{};
    for (final entry in entries) {
      for (final bundleName in entry.bundleNames) {
        out[bundleName] = (out[bundleName] ?? 0) + 1;
      }
    }
    return out;
  }

  Map<String, int> get dataShapeCounts {
    final out = <String, int>{};
    for (final entry in entries) {
      out[entry.dataShape.name] = (out[entry.dataShape.name] ?? 0) + 1;
    }
    return out;
  }

  Map<String, int> get apiContractCounts {
    final out = <String, int>{};
    for (final entry in entries) {
      final name = entry.apiContract.name;
      out[name] = (out[name] ?? 0) + 1;
    }
    return out;
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'description': description,
    'count': count,
    'bundleCounts': Map<String, int>.from(bundleCounts),
    'dataShapeCounts': Map<String, int>.from(dataShapeCounts),
    'apiContractCounts': Map<String, int>.from(apiContractCounts),
    'entries': [for (final entry in entries) entry.toJson()],
  };
}

/// Factory helpers for building public chart family manifests.
class ChartFamilyManifests {
  static const String publicExportPath = 'package:tenun/tenun.dart';

  const ChartFamilyManifests._();

  static ChartFamilyManifest available({
    RegistrationBundle? bundle,
    bool registeredOnly = false,
  }) {
    final targetBundle = bundle ?? allChartsBundle;
    final membership = _bundleMemberships();
    final entries = <ChartFamilyManifestEntry>[];
    final seen = <ChartType>{};

    for (final registration in targetBundle.registrations) {
      final type = canonicalChartType(registration.type);
      if (registeredOnly && !ChartRegistry.isRegistered(type)) continue;
      if (!seen.add(type)) continue;

      final capabilities = chartCapabilitiesForRegistration(registration);
      final payloadContract = chartPayloadContractForType(type);
      final bundleNames = membership[type] ?? const <String>[];

      entries.add(
        ChartFamilyManifestEntry(
          type: type,
          typeString: registration.typeString,
          displayName: _displayNameFor(registration.typeString),
          description: registration.description,
          surface: ChartFamilyManifestSurface.config,
          bundleNames: bundleNames.isEmpty
              ? [targetBundle.name]
              : List<String>.from(bundleNames),
          primaryBundleName: bundleNames.isEmpty
              ? targetBundle.name
              : bundleNames.first,
          dataShape: payloadContract.dataShape,
          seriesStrategy: payloadContract.seriesStrategy,
          dataFieldPriority: payloadContract.dataFieldPriority,
          namedCollectionField: payloadContract.namedCollectionField,
          requiresSeries: payloadContract.requiresSeries,
          usesExternalDataModel: payloadContract.usesExternalDataModel,
          apiContract: capabilities.apiContract,
          supportedFields: capabilities.apiContract.supportedFields,
          recommendedFields: capabilities.apiContract.recommendedFields,
          isRegistered: capabilities.isRegistered,
          supportsSampling: capabilities.supportsSampling,
          supportsZoom: capabilities.supportsZoom,
          supportsDrilldown: capabilities.supportsDrilldown,
          supportsLegend: capabilities.supportsLegend,
          supportsTooltip: capabilities.supportsTooltip,
          supportsRuntimeSwitching: capabilities.supportsRuntimeSwitching,
          aliases: registration.aliases,
          tags: registration.tags,
          publicExportPath: publicExportPath,
          showcaseExampleKey: registration.typeString,
        ),
      );
    }

    return ChartFamilyManifest(
      name: targetBundle.name,
      description: targetBundle.description,
      entries: List<ChartFamilyManifestEntry>.unmodifiable(entries),
    );
  }

  static List<Map<String, dynamic>> schemaJson({
    RegistrationBundle? bundle,
    bool registeredOnly = false,
  }) {
    return [
      for (final entry in available(
        bundle: bundle,
        registeredOnly: registeredOnly,
      ).entries)
        entry.toJson(),
    ];
  }
}

Map<ChartType, List<String>> _bundleMemberships() {
  final membership = <ChartType, List<String>>{};
  for (final bundle in _manifestBundles) {
    for (final registration in bundle.registrations) {
      final type = canonicalChartType(registration.type);
      final names = membership.putIfAbsent(type, () => <String>[]);
      if (!names.contains(bundle.name)) names.add(bundle.name);
    }
  }
  return membership;
}

String _displayNameFor(String typeString) {
  final withSpaces = typeString
      .replaceAll('_', ' ')
      .replaceAll('-', ' ')
      .replaceAllMapped(RegExp(r'(?<=[a-z0-9])(?=[A-Z])'), (_) => ' ');
  final words = [
    for (final word in withSpaces.trim().split(RegExp(r'\s+')))
      if (word.isNotEmpty) word,
  ];
  return words.map(_capitalizeManifestWord).join(' ');
}

String _capitalizeManifestWord(String word) {
  final lower = word.toLowerCase();
  if (_upperCaseManifestWords.contains(lower)) return lower.toUpperCase();
  return lower.substring(0, 1).toUpperCase() + lower.substring(1);
}

String _normalizeManifestKey(String value) {
  return value.trim().toLowerCase().replaceAll(RegExp(r'[\s_\-]+'), '');
}

final List<RegistrationBundle> _manifestBundles = [
  coreChartsBundle,
  allChartsBundle,
];

const Set<String> _upperCaseManifestWords = {'roc', 'kpi', 'ai', 'ml', 'ohlc'};
