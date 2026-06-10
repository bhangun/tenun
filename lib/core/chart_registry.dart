// Chart type registry — the foundation for tree-shakeable chart inclusion.
//
// ## Problem with the current approach
//
// `helper.dart` contains a `getChartConfig()` switch that imports every
// chart config class directly:
// ```dart
// import 'bar/bar_chart_config.dart';
// import 'line/line_chart_config.dart';
// import 'sankey/sankey_config.dart';     // ← pulled in even if never used
// import 'treemap/treemap_chart.dart';    // ← same
// // ... 30+ more imports
// ```
// Because Dart's tree shaker can only eliminate code that is **never
// referenced**, and every config is referenced in the switch, **every chart
// type always ends up in the binary**, even when the app only uses bar + line.
//
// ## Solution — Registry pattern
//
// Each chart type registers a lightweight factory closure. The registry is
// the only file that needs to exist in the core library. Individual chart
// packages register themselves when their `init()` is called.
//
// Dart tree shaker will then drop any chart type whose `init()` is never
// called — its code is simply never referenced from a reachable code path.
//
// ## Usage
//
// ### App bootstrapping (registers only the charts you need):
// ```dart
// void main() {
//   // Register only the chart types your app uses.
//   ChartRegistry.register(CoreCharts.bar);
//   ChartRegistry.register(CoreCharts.line);
//   ChartRegistry.register(CoreCharts.pie);
//   // Advanced charts: only included if registered.
//   // ChartRegistry.register(AdvancedCharts.sankey);
//
//   runApp(const MyApp());
// }
// ```
//
// ### Registering a bundle:
// ```dart
// ChartRegistry.registerAll(CoreCharts.all);      // bar, line, pie, scatter
// ChartRegistry.registerAll(AdvancedCharts.all);  // sankey, treemap, etc.
// ```
//
// ### From JSON (unchanged API for consumers):
// ```dart
// TenunChart(jsonConfig: {'type': 'bar', 'series': [...] })
// // → internally calls ChartRegistry.resolve('bar', json)
// ```
//
// ## Defining a chart registration:
// ```dart
// // In bar_chart_config.dart (or a separate registration file):
// final barChartRegistration = ChartRegistration(
//   type: ChartType.bar,
//   typeString: 'bar',
//   aliases: ['vertical_bar'],
//   fromJson: BarChartConfig.fromJson,
// );
// ```

// ---------------------------------------------------------------------------
// ChartRegistration — metadata for one chart type
// ---------------------------------------------------------------------------

import 'base_config.dart';
import 'chart_type.dart';

/// Describes one registered chart type.
class ChartRegistration {
  /// The canonical [ChartType] enum value.
  final ChartType type;

  /// Primary string key (matches [chartTypeToString]).
  final String typeString;

  /// Optional aliases (e.g. `['vertical_bar', 'column']` for `ChartType.bar`).
  final List<String> aliases;

  /// Factory that deserialises a [BaseChartConfig] from JSON.
  final BaseChartConfig Function(Map<String, dynamic> json) fromJson;

  /// Human-readable description (used for tooling / documentation).
  final String description;

  /// Feature tags for discovery (e.g. `['statistical', 'timeseries']`).
  final List<String> tags;

  const ChartRegistration({
    required this.type,
    required this.typeString,
    required this.fromJson,
    this.aliases = const [],
    this.description = '',
    this.tags = const [],
  });
}

/// Immutable snapshot of the current [ChartRegistry] state.
///
/// Useful for tests, showcase stories, plugin previews, and temporary chart
/// bundles that should not leak into the app-wide registry.
class ChartRegistrySnapshot {
  final List<ChartRegistration> registrations;

  ChartRegistrySnapshot._(Iterable<ChartRegistration> registrations)
    : registrations = List<ChartRegistration>.unmodifiable(registrations);

  int get count => registrations.length;
}

// ---------------------------------------------------------------------------
// ChartRegistry
// ---------------------------------------------------------------------------

/// Global registry of chart types.
///
/// This is the **single** place that maps chart type strings → config
/// factories. The monolithic `getChartConfig` switch in `helper.dart`
/// is replaced by calls to [ChartRegistry.resolve].
class ChartRegistry {
  ChartRegistry._();

  /// Map from canonical type string → registration.
  static final Map<String, ChartRegistration> _byString = {};

  /// Map from normalized type string → registration.
  ///
  /// Normalization removes separators (`_`, `-`, whitespace) so JSON payloads
  /// can use common variants like `line-area` or `stacked horizontal bar`.
  static final Map<String, ChartRegistration> _byNormalizedString = {};

  /// Map from [ChartType] enum → registration.
  static final Map<ChartType, ChartRegistration> _byType = {};

  static int _generation = 0;

  /// Monotonic version for cache invalidation when registrations change.
  static int get generation => _generation;

  // ---------- Registration ----------

  /// Register a single chart type.
  ///
  /// Idempotent — re-registering the same type is a no-op.
  static void register(ChartRegistration reg) {
    if (identical(_byType[reg.type], reg)) return;

    _byType[reg.type] = reg;
    _rebuildStringIndexes();
    _bumpGeneration();
  }

  /// Register multiple chart types at once.
  static void registerAll(Iterable<ChartRegistration> registrations) {
    var didRegister = false;
    for (final reg in registrations) {
      if (identical(_byType[reg.type], reg)) continue;

      _byType[reg.type] = reg;
      didRegister = true;
    }
    if (didRegister) {
      _rebuildStringIndexes();
      _bumpGeneration();
    }
  }

  /// Remove a chart type from the registry (e.g. for testing).
  static void unregister(ChartType type) {
    if (_byType.remove(canonicalChartType(type)) != null) {
      _rebuildStringIndexes();
      _bumpGeneration();
    }
  }

  /// Clear all registrations (use in tests only).
  static void clear() {
    final wasNotEmpty =
        _byType.isNotEmpty ||
        _byString.isNotEmpty ||
        _byNormalizedString.isNotEmpty;
    _byType.clear();
    _byString.clear();
    _byNormalizedString.clear();
    if (wasNotEmpty) _bumpGeneration();
  }

  /// Captures the current registry state for later [restore].
  static ChartRegistrySnapshot snapshot() =>
      ChartRegistrySnapshot._(_byType.values);

  /// Restores a previously captured registry [snapshot].
  static void restore(ChartRegistrySnapshot snapshot) {
    _byType
      ..clear()
      ..addEntries(
        snapshot.registrations.map(
          (registration) => MapEntry(registration.type, registration),
        ),
      );
    _rebuildStringIndexes();
    _bumpGeneration();
  }

  /// Temporarily registers [registrations] while synchronous [body] runs, then
  /// restores the previous registry state even when [body] throws.
  ///
  /// Use [withRegistrationsAsync] for async work. Passing a [Future]-returning
  /// body here is rejected because the registry would otherwise restore before
  /// the async work completes.
  static T withRegistrations<T>(
    Iterable<ChartRegistration> registrations,
    T Function() body, {
    bool clearBefore = false,
  }) {
    final previous = snapshot();
    try {
      if (clearBefore) clear();
      registerAll(registrations);
      final result = body();
      if (result is Future) {
        throw StateError(
          'ChartRegistry.withRegistrations() received an async body. '
          'Use ChartRegistry.withRegistrationsAsync() for Future-returning '
          'work so temporary registrations remain active until completion.',
        );
      }
      return result;
    } finally {
      restore(previous);
    }
  }

  /// Async variant of [withRegistrations].
  static Future<T> withRegistrationsAsync<T>(
    Iterable<ChartRegistration> registrations,
    Future<T> Function() body, {
    bool clearBefore = false,
  }) async {
    final previous = snapshot();
    try {
      if (clearBefore) clear();
      registerAll(registrations);
      return await body();
    } finally {
      restore(previous);
    }
  }

  // ---------- Resolution ----------

  /// Resolve a [BaseChartConfig] from a JSON map.
  ///
  /// Looks up `json['type']` in the registry. Throws [UnregisteredChartTypeException]
  /// if the type has not been registered.
  ///
  /// This replaces the `getChartConfig()` switch in `helper.dart`.
  static BaseChartConfig resolve(Map<String, dynamic> json) {
    final typeStr = _typeKey(json['type']);
    final reg = _registrationForKey(typeStr);
    if (reg == null) {
      throw UnregisteredChartTypeException(
        typeStr,
        registeredTypes,
        suggestions: suggestTypeStrings(typeStr),
      );
    }
    return reg.fromJson(json);
  }

  /// Resolve by [ChartType] enum (convenience — avoids string lookup).
  static BaseChartConfig resolveByType(
    ChartType type,
    Map<String, dynamic> json,
  ) {
    final canonicalType = canonicalChartType(type);
    final reg = _byType[canonicalType];
    if (reg == null) {
      final requestedType = chartTypeToString(canonicalType);
      throw UnregisteredChartTypeException(
        requestedType,
        registeredTypes,
        suggestions: suggestTypeStrings(requestedType),
      );
    }
    return reg.fromJson(json);
  }

  // ---------- Introspection ----------

  /// True if [type] has been registered.
  static bool isRegistered(ChartType type) =>
      _byType.containsKey(canonicalChartType(type));

  /// True if type string [s] has been registered.
  static bool isRegisteredString(String s) => _registrationForKey(s) != null;

  /// Registration metadata for [type], or `null` when it is not registered.
  static ChartRegistration? registrationForType(ChartType type) =>
      _byType[canonicalChartType(type)];

  /// Registration metadata for type string [s], including aliases.
  static ChartRegistration? registrationForString(String s) =>
      _registrationForKey(s);

  /// Suggest registered type strings for a mistyped or unregistered [rawType].
  static List<String> suggestTypeStrings(String rawType, {int limit = 3}) {
    final query = _normalizedTypeKey(rawType);
    if (query.isEmpty || _byString.isEmpty || limit <= 0) return const [];

    final scored = <({String key, int distance})>[];
    for (final key in _byString.keys) {
      final normalizedKey = _normalizedTypeKey(key);
      final distance = _levenshteinDistance(query, normalizedKey);
      final prefixBonus =
          normalizedKey.startsWith(query) || query.startsWith(normalizedKey)
          ? -1
          : 0;
      scored.add((key: key, distance: distance + prefixBonus));
    }

    scored.sort((a, b) {
      final byDistance = a.distance.compareTo(b.distance);
      if (byDistance != 0) return byDistance;
      return a.key.compareTo(b.key);
    });

    final maxDistance = (query.length / 3).ceil().clamp(1, 4);
    final out = <String>[];
    for (final candidate in scored) {
      if (candidate.distance > maxDistance) continue;
      if (!out.contains(candidate.key)) out.add(candidate.key);
      if (out.length >= limit) break;
    }
    return out;
  }

  /// All currently registered type strings.
  static List<String> get registeredTypes =>
      _byString.keys.toList(growable: false);

  /// All registered [ChartType] enum values.
  static List<ChartType> get registeredEnums =>
      _byType.keys.toList(growable: false);

  /// All registrations with a given tag.
  static List<ChartRegistration> withTag(String tag) =>
      _byType.values.where((r) => r.tags.contains(tag)).toList();

  /// Number of registered chart types.
  static int get count => _byType.length;

  static ChartRegistration? _registrationForKey(Object? rawKey) {
    final key = _typeKey(rawKey);
    if (key.isEmpty) return null;
    return _byString[key] ?? _byNormalizedString[_normalizedTypeKey(key)];
  }

  static void _rebuildStringIndexes() {
    _byString.clear();
    _byNormalizedString.clear();

    // Canonical keys are indexed first so aliases can never steal a real type
    // string, regardless of registration order.
    for (final reg in _byType.values) {
      final canonicalKey = _typeKey(reg.typeString);
      if (canonicalKey.isEmpty) continue;
      _byString[canonicalKey] = reg;
      _byNormalizedString[_normalizedTypeKey(canonicalKey)] = reg;
    }

    for (final reg in _byType.values) {
      for (final alias in reg.aliases) {
        final aliasKey = _typeKey(alias);
        if (aliasKey.isEmpty) continue;
        _byString.putIfAbsent(aliasKey, () => reg);
        _byNormalizedString.putIfAbsent(
          _normalizedTypeKey(aliasKey),
          () => reg,
        );
      }
    }
  }

  static void _bumpGeneration() {
    _generation++;
  }
}

// ---------------------------------------------------------------------------
// UnregisteredChartTypeException
// ---------------------------------------------------------------------------

class UnregisteredChartTypeException implements Exception {
  final String requestedType;
  final List<String> availableTypes;
  final List<String> suggestions;

  const UnregisteredChartTypeException(
    this.requestedType,
    this.availableTypes, {
    this.suggestions = const [],
  });

  @override
  String toString() {
    final requested = requestedType.isEmpty ? '<missing>' : requestedType;
    final suggestionText = suggestions.isEmpty
        ? ''
        : '\nDid you mean: ${suggestions.join(', ')}?';
    return 'UnregisteredChartTypeException: Chart type "$requested" is not '
        'registered. Did you forget to call ChartRegistry.register() in main()?'
        '$suggestionText\nRegistered types: ${availableTypes.join(', ')}';
  }
}

String _typeKey(Object? raw) => raw?.toString().trim().toLowerCase() ?? '';

String _normalizedTypeKey(Object? raw) => normalizeChartTypeKey(raw);

int _levenshteinDistance(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;

  var previous = List<int>.generate(b.length + 1, (index) => index);
  for (var i = 0; i < a.length; i++) {
    final current = List<int>.filled(b.length + 1, 0);
    current[0] = i + 1;
    for (var j = 0; j < b.length; j++) {
      final cost = a.codeUnitAt(i) == b.codeUnitAt(j) ? 0 : 1;
      current[j + 1] = [
        current[j] + 1,
        previous[j + 1] + 1,
        previous[j] + cost,
      ].reduce((value, element) => value < element ? value : element);
    }
    previous = current;
  }
  return previous.last;
}

// ---------------------------------------------------------------------------
// RegistrationBundle — groups related chart registrations
// ---------------------------------------------------------------------------

/// A named group of [ChartRegistration] objects.
///
/// Bundles are the unit of optional inclusion — register a whole bundle
/// to pull in a category of charts:
/// ```dart
/// ChartRegistry.registerAll(CoreCharts.bundle);
/// ChartRegistry.registerAll(TradingCharts.bundle);
/// ```
class RegistrationBundle {
  final String name;
  final String description;
  final List<ChartRegistration> registrations;

  const RegistrationBundle({
    required this.name,
    required this.description,
    required this.registrations,
  });

  /// Register all charts in this bundle.
  void register() => ChartRegistry.registerAll(registrations);
}

// ---------------------------------------------------------------------------
// Built-in bundle definitions (no imports — registration files import these)
// ---------------------------------------------------------------------------

// NOTE: The actual ChartRegistration instances are defined alongside their
// chart configs (e.g. `bar_chart_config.dart` exports `barChartRegistration`).
// Bundle files just collect them:
//
//   // lib/charts/core/core_charts_bundle.dart
//   import '../bar/bar_chart_config.dart' show barChartRegistration;
//   import '../line/line_chart_config.dart' show lineChartRegistration;
//   ...
//
//   const coreChartsBundle = RegistrationBundle(
//     name: 'core',
//     description: 'Bar, line, area, pie, donut, scatter',
//     registrations: [
//       barChartRegistration,
//       lineChartRegistration,
//       areaChartRegistration,
//       pieChartRegistration,
//       donutChartRegistration,
//       scatterChartRegistration,
//     ],
//   );
//
// The app then only imports the bundle files it needs, and Dart tree-shakes
// everything else.
