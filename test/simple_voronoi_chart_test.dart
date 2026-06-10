import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/tenun.dart';

void main() {
  const sites = [
    SimpleVoronoiSite(
      label: 'Quick Win',
      x: 20,
      y: 82,
      value: 32,
      group: 'Growth',
    ),
    SimpleVoronoiSite(label: 'Scale', x: 52, y: 74, value: 44, group: 'Growth'),
    SimpleVoronoiSite(
      label: 'Platform',
      x: 72,
      y: 64,
      value: 36,
      group: 'Core',
    ),
    SimpleVoronoiSite(label: 'Cleanup', x: 38, y: 36, value: 20, group: 'Core'),
    SimpleVoronoiSite(
      label: 'Pilot',
      x: 76,
      y: 26,
      value: 24,
      group: 'Experiment',
    ),
  ];

  testWidgets('renders voronoi styles without throwing', (tester) async {
    for (final style in SimpleBarChartStyle.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 460,
              height: 280,
              child: SimpleVoronoiChart(
                sites: sites,
                minX: 0,
                maxX: 100,
                minY: 0,
                maxY: 100,
                style: style,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SimpleVoronoiChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('renders voronoi with values and visible regions', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleVoronoiChart(
              sites: sites,
              minX: 0,
              maxX: 100,
              minY: 0,
              maxY: 100,
              xAxisLabel: 'Reach',
              yAxisLabel: 'Demand',
              showValues: true,
              showBoundaries: true,
              regionOpacity: 0.36,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SimpleVoronoiChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows voronoi tooltip on tap', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleVoronoiChart(
              sites: sites,
              minX: 0,
              maxX: 100,
              minY: 0,
              maxY: 100,
              xAxisLabel: 'Reach',
              yAxisLabel: 'Demand',
            ),
          ),
        ),
      ),
    );

    await tester.tapAt(const Offset(129, 58));
    await tester.pump();

    expect(find.text('Quick Win'), findsWidgets);
    expect(find.text('Reach'), findsOneWidget);
    expect(find.text('Demand'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invokes voronoi site tap callback without tooltip', (
    tester,
  ) async {
    String? tappedLabel;
    int? tappedIndex;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleVoronoiChart(
              sites: sites,
              minX: 0,
              maxX: 100,
              minY: 0,
              maxY: 100,
              showTooltip: false,
              onSiteTap: (site, index) {
                tappedLabel = site.label;
                tappedIndex = index;
              },
            ),
          ),
        ),
      ),
    );

    await tester.tapAt(const Offset(129, 58));
    await tester.pump();

    expect(tappedLabel, 'Quick Win');
    expect(tappedIndex, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('exposes default voronoi semantics label', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleVoronoiChart(
              sites: sites,
              minX: 0,
              maxX: 100,
              minY: 0,
              maxY: 100,
            ),
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(
        RegExp(r'Voronoi chart, 5 sites\. Quick Win x 20, y 82, value 32'),
      ),
      findsOneWidget,
    );
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
}
