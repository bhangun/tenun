import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/tenun.dart';

void main() {
  const data = [
    SimpleTileMapData(label: 'North', code: 'N', value: 72, row: 0, column: 0),
    SimpleTileMapData(
      label: 'Central',
      code: 'C',
      value: 88,
      row: 0,
      column: 1,
    ),
    SimpleTileMapData(label: 'East', code: 'E', value: 64, row: 0, column: 2),
    SimpleTileMapData(label: 'West', code: 'W', value: 51, row: 1, column: 0),
    SimpleTileMapData(label: 'South', code: 'S', value: 79, row: 1, column: 1),
    SimpleTileMapData(label: 'Coast', code: 'CO', value: 58, row: 1, column: 2),
  ];

  testWidgets('renders tile map styles without throwing', (tester) async {
    for (final style in SimpleBarChartStyle.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 460,
              height: 280,
              child: SimpleTileMapChart(
                data: data,
                rows: 3,
                columns: 4,
                style: style,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SimpleTileMapChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('renders tile map shapes without labels or legend', (
    tester,
  ) async {
    for (final shape in SimpleTileMapShape.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 460,
              height: 280,
              child: SimpleTileMapChart(
                data: data,
                shape: shape,
                rows: 3,
                columns: 4,
                showLabels: false,
                showValues: false,
                showLegend: false,
                showEmptyTiles: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SimpleTileMapChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('shows tile map tooltip on tap', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleTileMapChart(data: data, rows: 3, columns: 4),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(86, 59));
    await tester.pump();

    expect(find.text('North'), findsWidgets);
    expect(find.text('N'), findsWidgets);
    expect(find.text('Value'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invokes tile map tap callback without tooltip', (tester) async {
    String? tappedLabel;
    int? tappedIndex;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleTileMapChart(
              data: data,
              rows: 3,
              columns: 4,
              showTooltip: false,
              onTileTap: (tile, index) {
                tappedLabel = tile.label;
                tappedIndex = index;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(86, 59));
    await tester.pump();

    expect(tappedLabel, 'North');
    expect(tappedIndex, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('exposes default tile map semantics label', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleTileMapChart(data: data, rows: 3, columns: 4),
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(RegExp(r'Tile map, 6 tiles\. North 72')),
      findsOneWidget,
    );
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
}
