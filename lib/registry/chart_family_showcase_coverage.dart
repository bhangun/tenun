import '../core/chart_type.dart';
import 'chart_family_manifest.dart';

class ChartFamilyShowcaseCoverageReport {
  final ChartFamilyManifest manifest;
  final List<String> providedExampleKeys;
  final List<ChartFamilyManifestEntry> coveredEntries;
  final List<ChartFamilyManifestEntry> missingEntries;
  final List<String> unknownExampleKeys;
  final List<String> duplicateExampleKeys;

  const ChartFamilyShowcaseCoverageReport({
    required this.manifest,
    required this.providedExampleKeys,
    required this.coveredEntries,
    required this.missingEntries,
    required this.unknownExampleKeys,
    required this.duplicateExampleKeys,
  });

  int get expectedCount => manifest.count;
  int get providedCount => providedExampleKeys.length;
  int get coveredCount => coveredEntries.length;
  int get missingCount => missingEntries.length;
  int get unknownCount => unknownExampleKeys.length;
  int get duplicateCount => duplicateExampleKeys.length;

  bool get isComplete {
    return missingEntries.isEmpty && unknownExampleKeys.isEmpty;
  }

  bool get hasUnknownExamples => unknownExampleKeys.isNotEmpty;

  bool get hasDuplicateExamples => duplicateExampleKeys.isNotEmpty;

  double get coverageRatio {
    if (expectedCount == 0) return 1;
    return coveredCount / expectedCount;
  }

  List<String> get coveredExampleKeys {
    return [for (final entry in coveredEntries) entry.showcaseExampleKey];
  }

  List<String> get missingExampleKeys {
    return [for (final entry in missingEntries) entry.showcaseExampleKey];
  }

  Map<String, Map<String, int>> get bundleCoverage {
    final out = <String, Map<String, int>>{};
    for (final entry in manifest.entries) {
      final isCovered = coveredEntries.contains(entry);
      for (final bundleName in entry.bundleNames) {
        final counts = out.putIfAbsent(bundleName, () {
          return {'expected': 0, 'covered': 0, 'missing': 0};
        });
        counts['expected'] = counts['expected']! + 1;
        counts[isCovered ? 'covered' : 'missing'] =
            counts[isCovered ? 'covered' : 'missing']! + 1;
      }
    }
    return out;
  }

  Map<String, Map<String, int>> get dataShapeCoverage {
    final out = <String, Map<String, int>>{};
    for (final entry in manifest.entries) {
      final isCovered = coveredEntries.contains(entry);
      final counts = out.putIfAbsent(entry.dataShape.name, () {
        return {'expected': 0, 'covered': 0, 'missing': 0};
      });
      counts['expected'] = counts['expected']! + 1;
      counts[isCovered ? 'covered' : 'missing'] =
          counts[isCovered ? 'covered' : 'missing']! + 1;
    }
    return out;
  }

  Map<String, dynamic> toJson() => {
    'manifestName': manifest.name,
    'expectedCount': expectedCount,
    'providedCount': providedCount,
    'coveredCount': coveredCount,
    'missingCount': missingCount,
    'unknownCount': unknownCount,
    'duplicateCount': duplicateCount,
    'coverageRatio': coverageRatio,
    'isComplete': isComplete,
    'hasUnknownExamples': hasUnknownExamples,
    'hasDuplicateExamples': hasDuplicateExamples,
    'coveredExampleKeys': coveredExampleKeys,
    'missingExampleKeys': missingExampleKeys,
    'unknownExampleKeys': List<String>.from(unknownExampleKeys),
    'duplicateExampleKeys': List<String>.from(duplicateExampleKeys),
    'bundleCoverage': _cloneNestedCounts(bundleCoverage),
    'dataShapeCoverage': _cloneNestedCounts(dataShapeCoverage),
  };
}

extension ChartFamilyShowcaseCoverageManifestExtension on ChartFamilyManifest {
  ChartFamilyShowcaseCoverageReport showcaseCoverage(
    Iterable<String> exampleKeys,
  ) {
    return ChartFamilyShowcaseCoverages.forManifest(this, exampleKeys);
  }
}

class ChartFamilyShowcaseCoverages {
  const ChartFamilyShowcaseCoverages._();

  static ChartFamilyShowcaseCoverageReport forManifest(
    ChartFamilyManifest manifest,
    Iterable<String> exampleKeys,
  ) {
    final provided = [
      for (final key in exampleKeys)
        if (key.trim().isNotEmpty) key.trim(),
    ];
    final lookup = _entryLookupFor(manifest);
    final seenKeys = <String>{};
    final coveredTypes = <ChartType>{};
    final unknown = <String>[];
    final duplicate = <String>[];

    for (final key in provided) {
      final normalized = normalizeChartTypeKey(key);
      if (!seenKeys.add(normalized)) {
        duplicate.add(key);
        continue;
      }

      final entry = lookup[normalized];
      if (entry == null) {
        unknown.add(key);
      } else {
        coveredTypes.add(entry.type);
      }
    }

    final coveredEntries = [
      for (final entry in manifest.entries)
        if (coveredTypes.contains(entry.type)) entry,
    ];
    final missingEntries = [
      for (final entry in manifest.entries)
        if (!coveredTypes.contains(entry.type)) entry,
    ];

    return ChartFamilyShowcaseCoverageReport(
      manifest: manifest,
      providedExampleKeys: List<String>.unmodifiable(provided),
      coveredEntries: List<ChartFamilyManifestEntry>.unmodifiable(
        coveredEntries,
      ),
      missingEntries: List<ChartFamilyManifestEntry>.unmodifiable(
        missingEntries,
      ),
      unknownExampleKeys: List<String>.unmodifiable(unknown),
      duplicateExampleKeys: List<String>.unmodifiable(duplicate),
    );
  }
}

Map<String, ChartFamilyManifestEntry> _entryLookupFor(
  ChartFamilyManifest manifest,
) {
  final out = <String, ChartFamilyManifestEntry>{};
  for (final entry in manifest.entries) {
    for (final key in [
      entry.showcaseExampleKey,
      entry.typeString,
      ...entry.aliases,
    ]) {
      final normalized = normalizeChartTypeKey(key);
      if (normalized.isNotEmpty) out.putIfAbsent(normalized, () => entry);
    }
  }
  return out;
}

Map<String, Map<String, int>> _cloneNestedCounts(
  Map<String, Map<String, int>> value,
) {
  return {
    for (final entry in value.entries)
      entry.key: Map<String, int>.from(entry.value),
  };
}
