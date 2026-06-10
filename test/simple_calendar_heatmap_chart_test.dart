import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/tenun.dart';

void main() {
  final start = DateTime(2026, 1, 1);
  final end = DateTime(2026, 1, 31);
  final data = [
    SimpleCalendarHeatmapData(
      date: DateTime(2026, 1, 5),
      value: 8,
      label: 'Study Day',
    ),
    SimpleCalendarHeatmapData(date: DateTime(2026, 1, 6), value: 12),
    SimpleCalendarHeatmapData(date: DateTime(2026, 1, 7), value: 16),
    SimpleCalendarHeatmapData(date: DateTime(2026, 1, 12), value: 22),
    SimpleCalendarHeatmapData(date: DateTime(2026, 1, 15), value: 30),
    SimpleCalendarHeatmapData(date: DateTime(2026, 1, 20), value: 18),
    SimpleCalendarHeatmapData(date: DateTime(2026, 1, 29), value: 26),
  ];

  testWidgets('renders calendar heatmap styles without throwing', (
    tester,
  ) async {
    for (final style in SimpleBarChartStyle.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 460,
              height: 260,
              child: SimpleCalendarHeatmapChart(
                data: data,
                startDate: start,
                endDate: end,
                style: style,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SimpleCalendarHeatmapChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('renders compact calendar heatmap with values', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            height: 220,
            child: SimpleCalendarHeatmapChart(
              data: data,
              startDate: start,
              endDate: DateTime(2026, 1, 18),
              showMonthLabels: false,
              showWeekdayLabels: false,
              showLegend: false,
              showValues: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SimpleCalendarHeatmapChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows calendar heatmap tooltip on tap', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 260,
            child: SimpleCalendarHeatmapChart(
              data: data,
              startDate: start,
              endDate: end,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(232, 48));
    await tester.pump();

    expect(find.text('Study Day'), findsOneWidget);
    expect(find.text('2026-01-05'), findsWidgets);
    expect(find.text('8'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invokes calendar heatmap tap callback without tooltip', (
    tester,
  ) async {
    DateTime? tappedDate;
    double? tappedValue;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 260,
            child: SimpleCalendarHeatmapChart(
              data: data,
              startDate: start,
              endDate: end,
              showTooltip: false,
              onDayTap: (item, date, value) {
                tappedDate = date;
                tappedValue = value;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(232, 48));
    await tester.pump();

    expect(tappedDate, DateTime(2026, 1, 5));
    expect(tappedValue, 8);
    expect(tester.takeException(), isNull);
  });

  testWidgets('exposes default calendar heatmap semantics label', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 260,
            child: SimpleCalendarHeatmapChart(
              data: data,
              startDate: start,
              endDate: end,
            ),
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(
        RegExp(
          r'Calendar heatmap, 7 days from 2026-01-01 to 2026-01-31\. 2026-01-05 8',
        ),
      ),
      findsOneWidget,
    );
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
}
