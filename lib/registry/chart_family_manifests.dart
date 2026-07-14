import 'package:tenun_core/tenun_core.dart';

import 'bundle_core.dart';
import 'chart_registration_bundle.dart';
import 'registry_tools.dart';

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

final List<RegistrationBundle> _manifestBundles = [
  coreChartsBundle,
  allChartsBundle,
];

const Set<String> _upperCaseManifestWords = {'roc', 'kpi', 'ai', 'ml', 'ohlc'};
