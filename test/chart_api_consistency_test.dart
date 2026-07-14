import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/registry/chart_family_manifests.dart';
import 'package:tenun/tenun.dart';

void main() {
  test('field schema keeps aliases canonical and unique', () {
    expect(
      ChartApiFields.canonicalFields,
      hasLength(ChartApiFields.fieldSpecs.length),
    );
    expect(ChartApiFields.canonicalFieldFor('enableTooltip'), 'showTooltip');
    expect(ChartApiFields.canonicalFieldFor('onCellTap'), 'onElementTap');
    expect(
      ChartApiFields.aliasesFor('semanticLabel'),
      contains('semanticsLabel'),
    );
    expect(
      ChartApiFields.schemaJson().first,
      containsPair('category', ChartApiFieldCategory.structure.name),
    );
    final schemaFieldJson = ChartApiFields.schemaJson().first;
    (schemaFieldJson['aliases'] as List).clear();
    expect(ChartApiFields.fieldSpecs.first.aliases, contains('type'));

    final semanticAliases = ChartApiFields.aliasesFor('semanticLabel');
    semanticAliases.clear();
    expect(
      ChartApiFields.aliasesFor('semanticLabel'),
      contains('semanticsLabel'),
    );

    final seen = <String>{};
    for (final spec in ChartApiFields.fieldSpecs) {
      expect(spec.aliases, contains(spec.canonicalField));
      for (final alias in spec.aliases) {
        expect(seen.add(alias), isTrue, reason: 'Duplicate API alias: $alias');
      }
    }
  });

  test('contracts cover config, widget, and domain chart families', () {
    expect(ChartApiContracts.optionConfig.supports('series'), isTrue);
    expect(ChartApiContracts.optionConfig.supports('samplingPolicy'), isTrue);
    expect(
      ChartApiContracts.simpleWidget.supports('emptyStateBuilder'),
      isTrue,
    );
    expect(ChartApiContracts.cartesian.supports('axisLabelsVisible'), isTrue);
    expect(ChartApiContracts.hierarchyFlow.supports('onNodeTap'), isTrue);
    expect(ChartApiContracts.densitySpatial.supports('colorPalette'), isTrue);
    expect(ChartApiContracts.financial.recommends('valueFormatter'), isTrue);
    expect(ChartApiContracts.supporting('showTooltip'), isNotEmpty);
    expect(
      ChartApiContracts.schemaJson(),
      hasLength(ChartApiContracts.all.length),
    );

    final contractJson = ChartApiContracts.optionConfig.toJson();
    (contractJson['supportedFields'] as List).clear();
    (contractJson['recommendedFields'] as List).clear();
    expect(ChartApiContracts.optionConfig.supportedFields, contains('series'));
    expect(
      ChartApiContracts.optionConfig.recommendedFields,
      contains('series'),
    );
  });

  test('chart family manifest aggregates registry metadata', () {
    final manifest = ChartFamilyManifests.available();
    final uniqueRegisteredTypes = {
      for (final registration in allChartsBundle.registrations)
        canonicalChartType(registration.type),
    };

    expect(manifest.count, uniqueRegisteredTypes.length);
    expect(manifest.typeStrings, contains('bar'));
    expect(
      manifest.bundleCounts['core'],
      coreChartsBundle.registrations.length,
    );
    expect(manifest.dataShapeCounts, containsPair('cartesian', isPositive));
    expect(manifest.apiContractCounts, containsPair('cartesian', isPositive));

    final bar = manifest.entryForType(ChartType.bar)!;
    expect(bar.typeString, 'bar');
    expect(bar.displayName, 'Bar');
    expect(bar.surface, ChartFamilyManifestSurface.config);
    expect(bar.primaryBundleName, 'core');
    expect(bar.bundleNames, containsAll(['core', 'all_core']));
    expect(bar.dataShape, ChartSeriesDataShape.cartesian);
    expect(bar.seriesStrategy, ChartPayloadSeriesStrategy.dataFields);
    expect(bar.dataFieldPriority, contains('data'));
    expect(bar.apiContract, ChartApiContracts.cartesian);
    expect(bar.supportsApiField('axisLabelsVisible'), isTrue);
    expect(bar.supportedFields, contains(ChartApiFields.showTooltip));
    expect(bar.publicExportPath, ChartFamilyManifests.publicExportPath);
    expect(bar.showcaseExampleKey, 'bar');
    expect(bar.toJson(), containsPair('displayName', 'Bar'));
    expect(
      bar.toJson(),
      containsPair('publicExportPath', 'package:tenun/tenun.dart'),
    );

    expect(
      manifest.entryForTypeString('stacked_horizontal_bar')?.type,
      ChartType.stackedHorizontalBar,
    );
    expect(
      manifest.forBundle('core').map((entry) => entry.type),
      contains(ChartType.bar),
    );
    expect(manifest.forDataShape(ChartSeriesDataShape.cartesian), isNotEmpty);
    expect(
      manifest.forApiContract('cartesian').map((entry) => entry.type),
      contains(ChartType.line),
    );
    expect(
      manifest.forTag('core').map((entry) => entry.type),
      contains(ChartType.bar),
    );

    final manifestJson = manifest.toJson();
    (manifestJson['entries'] as List).clear();
    expect(manifest.entries, isNotEmpty);
    expect(
      ChartFamilyManifests.schemaJson().first,
      containsPair('type', isA<String>()),
    );

    ChartRegistry.withRegistrations([barRegistration], () {
      final registeredManifest = ChartFamilyManifests.available(
        registeredOnly: true,
      );
      expect(registeredManifest.entries, hasLength(1));
      expect(registeredManifest.entries.single.type, ChartType.bar);
      expect(registeredManifest.entries.single.isRegistered, isTrue);
    }, clearBefore: true);
  });

  test('chart family manifest reports showcase coverage gaps', () {
    final manifest = ChartFamilyManifests.available(bundle: coreChartsBundle);
    final coverage = manifest.showcaseCoverage([
      'bar',
      'line',
      'scatter',
      'bubble',
      'stacked_bar',
      'unknown_chart',
      'bar',
    ]);

    expect(coverage.expectedCount, coreChartsBundle.registrations.length);
    expect(coverage.providedCount, 7);
    expect(coverage.coveredCount, 4);
    expect(coverage.missingCount, 8);
    expect(coverage.unknownExampleKeys, ['bubble', 'unknown_chart']);
    expect(coverage.duplicateExampleKeys, ['bar']);
    expect(coverage.coveredExampleKeys, [
      'bar',
      'stackedbar',
      'line',
      'scatter',
    ]);
    expect(coverage.missingExampleKeys, [
      'groupedbar',
      'horizontalbar',
      'stackedhorizontalbar',
      'linearea',
      'area',
      'stackedarea',
      'pie',
      'donut',
    ]);
    expect(coverage.isComplete, isFalse);
    expect(coverage.hasUnknownExamples, isTrue);
    expect(coverage.hasDuplicateExamples, isTrue);
    expect(coverage.coverageRatio, closeTo(4 / 12, 0.0001));
    expect(coverage.bundleCoverage['core'], {
      'expected': 12,
      'covered': 4,
      'missing': 8,
    });
    expect(coverage.dataShapeCoverage['cartesian'], {
      'expected': 10,
      'covered': 4,
      'missing': 6,
    });
    expect(coverage.dataShapeCoverage['pieLike'], {
      'expected': 2,
      'covered': 0,
      'missing': 2,
    });
    expect(
      coverage.toJson(),
      containsPair('missingExampleKeys', [
        'groupedbar',
        'horizontalbar',
        'stackedhorizontalbar',
        'linearea',
        'area',
        'stackedarea',
        'pie',
        'donut',
      ]),
    );

    final completeCoverage = ChartFamilyShowcaseCoverages.forManifest(
      manifest,
      manifest.entries.map((entry) => entry.showcaseExampleKey),
    );
    expect(completeCoverage.isComplete, isTrue);
    expect(completeCoverage.coverageRatio, 1);
    expect(completeCoverage.unknownExampleKeys, isEmpty);
    expect(completeCoverage.duplicateExampleKeys, isEmpty);
  });

  test('config-driven charts expose the shared API contract', () {
    final config = LineChartConfig(series: const []);

    expect(config.apiContract, ChartApiContracts.optionConfig);
    expect(config.supportsApiField('runtimePerformancePolicy'), isTrue);
    expect(config.supportsApiField('emptyStateBuilder'), isFalse);
  });

  test('simple widget charts expose the shared API contract', () {
    final chart = SimpleBarChart(data: const []);

    expect(chart.apiContract, ChartApiContracts.simpleWidget);
    expect(chart.supportsApiField('emptyStateBuilder'), isTrue);
    expect(chart.supportsApiField('series'), isFalse);
    expect(chart.recommendsApiField('semanticLabel'), isTrue);
    expect(
      ChartWidgetApiContracts.resolve(chart),
      ChartApiContracts.simpleWidget,
    );
    expect(const Text('Not a chart').apiContract, isNull);
  });

  test(
    'simple chart declarations are discoverable by widget contract resolver',
    () {
      final simpleChartClasses = [
        for (final declaration in _simpleChartDeclarations()) declaration.name,
      ];

      final undiscoverable = [
        for (final className in simpleChartClasses)
          if (ChartWidgetApiContracts.resolveTypeName(className) !=
              ChartApiContracts.simpleWidget)
            className,
      ];

      expect(simpleChartClasses, isNotEmpty);
      expect(undiscoverable, isEmpty);
    },
  );

  test('simple widget charts declare the standard shared API fields', () {
    final requiredPatterns = <String, RegExp>{
      'emptyBuilder field': RegExp(
        r'final\s+WidgetBuilder\?\s+emptyBuilder\s*;',
      ),
      'semanticLabel field': RegExp(r'final\s+String\?\s+semanticLabel\s*;'),
      'excludeFromSemantics field': RegExp(
        r'final\s+bool\s+excludeFromSemantics\s*;',
      ),
      'animationDuration field': RegExp(
        r'final\s+Duration\s+animationDuration\s*;',
      ),
      'animationCurve field': RegExp(r'final\s+Curve\s+animationCurve\s*;'),
      'emptyBuilder constructor parameter': RegExp(r'\bthis\.emptyBuilder\b'),
      'semanticLabel constructor parameter': RegExp(r'\bthis\.semanticLabel\b'),
      'excludeFromSemantics default': RegExp(
        r'\bthis\.excludeFromSemantics\s*=\s*false\b',
      ),
      'animationDuration default': RegExp(
        r'\bthis\.animationDuration\s*=\s*const\s+Duration\s*\(',
      ),
      'animationCurve default': RegExp(r'\bthis\.animationCurve\s*='),
    };
    final missing = <String>[];

    for (final declaration in _simpleChartDeclarations()) {
      for (final entry in requiredPatterns.entries) {
        if (!entry.value.hasMatch(declaration.source)) {
          missing.add('${declaration.location} missing ${entry.key}');
        }
      }
    }

    expect(
      missing,
      isEmpty,
      reason:
          'Every public Simple*Chart widget should expose the shared '
          'empty-state, accessibility, and animation API fields.',
    );
  });

  test(
    'simple widget charts route standard fields through ChartApiSurface',
    () {
      final requiredPatterns = <String, RegExp>{
        'ChartApiSurface usage': RegExp(r'\bChartApiSurface\s*\('),
        'ChartAccessibilityOptions usage': RegExp(
          r'\bChartAccessibilityOptions\s*\(',
        ),
        'semanticLabel handoff': RegExp(r'\bsemanticLabel:\s*semanticLabel\b'),
        'excludeFromSemantics handoff': RegExp(
          r'\bexcludeFromSemantics:\s*excludeFromSemantics\b',
        ),
      };
      final missing = <String>[];

      for (final declaration in _simpleChartDeclarations()) {
        for (final entry in requiredPatterns.entries) {
          if (!entry.value.hasMatch(declaration.source)) {
            missing.add('${declaration.location} missing ${entry.key}');
          }
        }
      }

      expect(
        missing,
        isEmpty,
        reason:
            'Every public Simple*Chart widget should route the shared '
            'accessibility API through ChartApiSurface.',
      );
    },
  );

  test('adapter simple charts keep delegated simple charts decorative', () {
    final offenders = <String>[];

    for (final declaration in _simpleChartDeclarations()) {
      for (final call in _simpleChartDelegateCalls(declaration)) {
        if (!RegExp(
          r'\bexcludeFromSemantics\s*:\s*true\b',
        ).hasMatch(call.source)) {
          offenders.add(
            '${call.location} delegates to ${call.name} without '
            'excludeFromSemantics: true',
          );
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Adapter Simple*Chart widgets should own the public semantics node '
          'and mark delegated Simple*Chart children as decorative.',
    );
  });

  test('chart widgets route accessibility through shared surfaces', () {
    final rawSemanticsCall = RegExp(
      r'\b(?:return\s+)?(?:ExcludeSemantics|Semantics)\s*\(',
    );
    final offenders = <String>[];

    for (final file in _chartDartFiles()) {
      final lines = file.readAsLinesSync();
      for (var index = 0; index < lines.length; index++) {
        if (rawSemanticsCall.hasMatch(lines[index])) {
          offenders.add('${file.path}:${index + 1}: ${lines[index].trim()}');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Chart widgets should use ChartApiSurface or '
          'ChartAccessibilityOptions for chart-level semantics.',
    );
  });

  test('option objects provide reusable defaults and copies', () {
    expect(ChartApiDefaults.interaction.showTooltip, isTrue);
    expect(ChartInteractionOptions.quiet.showActiveElement, isFalse);
    expect(
      const ChartVisibilityOptions().copyWith(showLegend: false).showLegend,
      isFalse,
    );
    expect(ChartAnimationOptions.disabled.isEnabled, isFalse);
    expect(
      ChartAnimationOptions.quick.copyWith(curve: Curves.linear).curve,
      Curves.linear,
    );
  });

  testWidgets('accessibility options wrap semantics consistently', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: const ChartAccessibilityOptions(
            semanticLabel: 'Revenue by month',
          ).wrap(const SizedBox(width: 10, height: 10)),
        ),
      );

      expect(find.bySemanticsLabel('Revenue by month'), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('accessibility options can hide decorative charts', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: ChartAccessibilityOptions.decorative.wrap(
            const SizedBox(width: 10, height: 10),
            fallbackLabel: 'Decorative chart',
          ),
        ),
      );

      expect(find.bySemanticsLabel('Decorative chart'), findsNothing);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('chart API surface standardizes empty state semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        const MaterialApp(
          home: ChartApiSurface(
            isEmpty: true,
            width: 120,
            height: 80,
            emptySemanticLabel: 'Example chart, no data.',
            child: SizedBox.shrink(),
          ),
        ),
      );

      expect(find.text('No data'), findsOneWidget);
      expect(find.bySemanticsLabel('Example chart, no data.'), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });
}

List<File> _chartDartFiles() {
  return Directory('lib/charts')
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
}

List<_SimpleChartDeclaration> _simpleChartDeclarations() {
  final declarations = <_SimpleChartDeclaration>[];
  final declaration = RegExp(
    r'class\s+(Simple\w*Chart)\s+extends\s+(?:StatelessWidget|StatefulWidget)',
  );

  for (final file in _chartDartFiles()) {
    final source = file.readAsStringSync();
    final matches = declaration.allMatches(source).toList();
    for (var index = 0; index < matches.length; index++) {
      final match = matches[index];
      final className = match.group(1)!;
      final end = index + 1 < matches.length
          ? matches[index + 1].start
          : source.length;
      final body = source.substring(match.start, end);
      declarations.add(
        _SimpleChartDeclaration(
          file.path,
          className,
          body,
          _lineForOffset(source, match.start),
        ),
      );
    }
  }

  return declarations;
}

List<_SimpleChartDelegateCall> _simpleChartDelegateCalls(
  _SimpleChartDeclaration declaration,
) {
  final calls = <_SimpleChartDelegateCall>[];
  final constructorCall = RegExp(r'\b(Simple\w*Chart)\s*\(');

  for (final match in constructorCall.allMatches(declaration.source)) {
    final targetName = match.group(1)!;
    if (targetName == declaration.name) continue;

    final openParen = declaration.source.indexOf('(', match.start);
    final closeParen = _matchingCloseParen(declaration.source, openParen);
    if (openParen < 0 || closeParen < 0) continue;

    calls.add(
      _SimpleChartDelegateCall(
        targetName,
        declaration.source.substring(match.start, closeParen + 1),
        '${declaration.path}:'
        '${declaration.line + _lineForOffset(declaration.source, match.start) - 1} '
        '${declaration.name}',
      ),
    );
  }

  return calls;
}

int _matchingCloseParen(String source, int openParen) {
  if (openParen < 0 || openParen >= source.length) return -1;
  var depth = 0;
  String? quote;
  var escaped = false;

  for (var index = openParen; index < source.length; index++) {
    final char = source[index];

    if (quote != null) {
      if (escaped) {
        escaped = false;
      } else if (char == '\\') {
        escaped = true;
      } else if (char == quote) {
        quote = null;
      }
      continue;
    }

    if (char == '"' || char == "'") {
      quote = char;
      continue;
    }

    if (char == '(') depth++;
    if (char == ')') {
      depth--;
      if (depth == 0) return index;
    }
  }

  return -1;
}

int _lineForOffset(String source, int offset) {
  return '\n'.allMatches(source.substring(0, offset)).length + 1;
}

class _SimpleChartDeclaration {
  final String path;
  final String name;
  final String source;
  final int line;

  const _SimpleChartDeclaration(this.path, this.name, this.source, this.line);

  String get location => '$path:$line $name';
}

class _SimpleChartDelegateCall {
  final String name;
  final String source;
  final String location;

  const _SimpleChartDelegateCall(this.name, this.source, this.location);
}
