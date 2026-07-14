import 'package:tenun_core/tenun_core.dart';

import 'chart_registration_bundle.dart';

/// Grouped bundles keyed by inferred data shape.
final Map<ChartSeriesDataShape, RegistrationBundle> seriesShapeBundles =
    buildShapeBundles();

/// Returns a bundle with charts compatible to the provided data [shape].
RegistrationBundle? getBundleForSeriesShape(ChartSeriesDataShape shape) =>
    seriesShapeBundles[shape];

/// Returns capability metadata for a concrete [ChartRegistration].
ChartCapabilities chartCapabilitiesForRegistration(ChartRegistration reg) {
  final base = chartCapabilitiesForType(reg.type);
  return ChartCapabilities(
    type: base.type,
    typeString: reg.typeString,
    dataShape: base.dataShape,
    isRegistered: base.isRegistered,
    supportsSampling: base.supportsSampling,
    supportsZoom: base.supportsZoom,
    supportsDrilldown: base.supportsDrilldown,
    supportsLegend: base.supportsLegend,
    supportsTooltip: base.supportsTooltip,
    supportsRuntimeSwitching: base.supportsRuntimeSwitching,
    apiContract: base.apiContract,
    description: reg.description,
    aliases: reg.aliases,
    tags: reg.tags,
  );
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
///
/// When [registeredOnly] is `true` and no explicit [bundle] is given the report
/// is built from the live [ChartRegistry] snapshot instead of from
/// [allChartsBundle], so [ChartRegistryHealthReport.capabilityCount] always
/// equals [ChartRegistry.registeredEnums.length].
ChartRegistryHealthReport chartRegistryHealthReport({
  RegistrationBundle? bundle,
  bool registeredOnly = false,
  bool includeUnknownShapeWarnings = false,
}) {
  // When the caller wants registered-only results and hasn't pinned a specific
  // bundle, synthesise a bundle from whatever is in the live registry so that
  // the report reflects the actual installed surface rather than only the
  // free-tier core bundle.
  final targetBundle = bundle ?? (
    registeredOnly
      ? RegistrationBundle(
          name: 'registry_snapshot',
          description: 'Live ChartRegistry snapshot',
          registrations: ChartRegistry.registeredEnums
              .map((type) => ChartRegistry.registrationForType(type))
              .whereType<ChartRegistration>()
              .toList(growable: false),
        )
      : allChartsBundle
  );
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
    featureCounts: featureCounts(capabilities),
    payloadStrategyCounts: _payloadStrategyCounts(payloadContracts),
    payloadFeatureCounts: _payloadFeatureCounts(payloadContracts),
    apiContractUsageCounts: _apiContractUsageCounts(capabilities),
    apiFieldCategoryCounts: _apiFieldCategoryCounts(apiContracts),
  );
}





/// Capability metadata for all compiled-in chart registrations.
List<ChartCapabilities> availableChartCapabilities({
  bool registeredOnly = true,
}) {
  if (registeredOnly) return registeredChartCapabilities();
  return _capabilitiesForBundle(allChartsBundle, registeredOnly: false);
}

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
