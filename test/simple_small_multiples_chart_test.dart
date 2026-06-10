import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/tenun.dart';

void main() {
  const panels = [
    SimpleSmallMultiplePanel(
      label: 'North',
      subtitle: '+18%',
      color: Color(0xFF2563EB),
      series: [
        SimpleTrendSeries(
          name: 'Revenue',
          points: [
            SimpleTrendPoint(label: 'Jan', value: 42),
            SimpleTrendPoint(label: 'Feb', value: 45),
            SimpleTrendPoint(label: 'Mar', value: 48),
            SimpleTrendPoint(label: 'Apr', value: 54),
            SimpleTrendPoint(label: 'May', value: 61),
            SimpleTrendPoint(label: 'Jun', value: 72),
          ],
        ),
      ],
    ),
    SimpleSmallMultiplePanel(
      label: 'South',
      subtitle: '+11%',
      color: Color(0xFF0D9488),
      series: [
        SimpleTrendSeries(
          name: 'Revenue',
          points: [
            SimpleTrendPoint(label: 'Jan', value: 36),
            SimpleTrendPoint(label: 'Feb', value: 39),
            SimpleTrendPoint(label: 'Mar', value: 43),
            SimpleTrendPoint(label: 'Apr', value: 45),
            SimpleTrendPoint(label: 'May', value: 49),
            SimpleTrendPoint(label: 'Jun', value: 54),
          ],
        ),
      ],
    ),
    SimpleSmallMultiplePanel(
      label: 'East',
      subtitle: '+24%',
      color: Color(0xFF7C3AED),
      series: [
        SimpleTrendSeries(
          name: 'Revenue',
          points: [
            SimpleTrendPoint(label: 'Jan', value: 30),
            SimpleTrendPoint(label: 'Feb', value: 34),
            SimpleTrendPoint(label: 'Mar', value: 41),
            SimpleTrendPoint(label: 'Apr', value: 48),
            SimpleTrendPoint(label: 'May', value: 58),
            SimpleTrendPoint(label: 'Jun', value: 66),
          ],
        ),
      ],
    ),
    SimpleSmallMultiplePanel(
      label: 'West',
      subtitle: '+8%',
      color: Color(0xFFF97316),
      series: [
        SimpleTrendSeries(
          name: 'Revenue',
          points: [
            SimpleTrendPoint(label: 'Jan', value: 51),
            SimpleTrendPoint(label: 'Feb', value: 49),
            SimpleTrendPoint(label: 'Mar', value: 53),
            SimpleTrendPoint(label: 'Apr', value: 57),
            SimpleTrendPoint(label: 'May', value: 60),
            SimpleTrendPoint(label: 'Jun', value: 65),
          ],
        ),
      ],
    ),
  ];

  testWidgets('renders small multiples styles without throwing', (
    tester,
  ) async {
    for (final style in SimpleTrendChartStyle.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 460,
              height: 300,
              child: SimpleSmallMultiplesChart(
                panels: panels,
                minValue: 0,
                maxValue: 80,
                style: style,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SimpleSmallMultiplesChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('renders small multiples with area and references', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 300,
            child: SimpleSmallMultiplesChart(
              panels: panels,
              minValue: 0,
              maxValue: 80,
              columns: 2,
              showArea: true,
              showValues: true,
              referenceLines: [
                SimpleChartReferenceLine(value: 60, label: 'Goal'),
              ],
              referenceBands: [
                SimpleChartReferenceBand(from: 55, to: 70, label: 'Target'),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SimpleSmallMultiplesChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows small multiples tooltip on tap', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 300,
            child: SimpleSmallMultiplesChart(
              panels: panels,
              minValue: 0,
              maxValue: 80,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(106, 82));
    await tester.pump();

    expect(find.text('Mar'), findsWidgets);
    expect(find.text('Revenue'), findsWidgets);
    expect(find.text('48'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invokes small multiples tap callback without tooltip', (
    tester,
  ) async {
    String? tappedPanel;
    String? tappedLabel;
    int? tappedPanelIndex;
    int? tappedPointIndex;
    List<SimpleTrendTooltipItem>? tappedItems;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 300,
            child: SimpleSmallMultiplesChart(
              panels: panels,
              minValue: 0,
              maxValue: 80,
              showTooltip: false,
              onPointTap: (panel, panelIndex, label, items, pointIndex) {
                tappedPanel = panel.label;
                tappedPanelIndex = panelIndex;
                tappedLabel = label;
                tappedItems = items;
                tappedPointIndex = pointIndex;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(106, 82));
    await tester.pump();

    expect(tappedPanel, 'North');
    expect(tappedPanelIndex, 0);
    expect(tappedLabel, 'Mar');
    expect(tappedPointIndex, 2);
    expect(tappedItems?.single.value, 48);
    expect(tester.takeException(), isNull);
  });

  testWidgets('exposes default small multiples semantics label', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 300,
            child: SimpleSmallMultiplesChart(panels: panels),
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(
        RegExp(
          r'Small multiples chart, 4 panels\. North from Jan 42 to Jun 72',
        ),
      ),
      findsOneWidget,
    );
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
}
