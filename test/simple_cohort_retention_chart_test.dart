import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/tenun.dart';

void main() {
  const periods = ['W0', 'W1', 'W2', 'W3', 'W4'];
  const rows = [
    SimpleCohortRetentionRow(
      label: 'Jan',
      size: 1200,
      values: [1, 0.62, 0.42, 0.30, 0.24],
    ),
    SimpleCohortRetentionRow(
      label: 'Feb',
      size: 1320,
      values: [1, 0.58, 0.37, 0.26, null],
    ),
    SimpleCohortRetentionRow(
      label: 'Mar',
      size: 1410,
      values: [1, 0.61, 0.39, null, null],
    ),
    SimpleCohortRetentionRow(
      label: 'Apr',
      size: 1500,
      values: [1, 0.66, null, null, null],
    ),
  ];

  testWidgets('renders cohort retention styles without throwing', (
    tester,
  ) async {
    for (final style in SimpleBarChartStyle.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 460,
              height: 280,
              child: SimpleCohortRetentionChart(
                rows: rows,
                periodLabels: periods,
                minValue: 0,
                maxValue: 1,
                style: style,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SimpleCohortRetentionChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('renders compact cohort retention without labels or legend', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            height: 220,
            child: SimpleCohortRetentionChart(
              rows: rows,
              showPeriodLabels: false,
              showCohortLabels: false,
              showCohortSize: false,
              showLegend: false,
              showValues: false,
              showEmptyCells: false,
              minValue: 0,
              maxValue: 1,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SimpleCohortRetentionChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows cohort retention tooltip on tap', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleCohortRetentionChart(
              rows: rows,
              periodLabels: periods,
              minValue: 0,
              maxValue: 1,
            ),
          ),
        ),
      ),
    );

    await tester.tapAt(const Offset(118, 55));
    await tester.pump();

    expect(find.text('Jan'), findsWidgets);
    expect(find.text('W0'), findsOneWidget);
    expect(find.text('100%'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invokes cohort retention tap callback without tooltip', (
    tester,
  ) async {
    String? tappedLabel;
    int? tappedRow;
    int? tappedPeriod;
    double? tappedValue;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleCohortRetentionChart(
              rows: rows,
              periodLabels: periods,
              minValue: 0,
              maxValue: 1,
              showTooltip: false,
              onCellTap: (row, rowIndex, periodIndex, value) {
                tappedLabel = row.label;
                tappedRow = rowIndex;
                tappedPeriod = periodIndex;
                tappedValue = value;
              },
            ),
          ),
        ),
      ),
    );

    await tester.tapAt(const Offset(118, 55));
    await tester.pump();

    expect(tappedLabel, 'Jan');
    expect(tappedRow, 0);
    expect(tappedPeriod, 0);
    expect(tappedValue, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('exposes default cohort retention semantics label', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleCohortRetentionChart(
              rows: rows,
              periodLabels: periods,
            ),
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(
        RegExp(
          r'Cohort retention chart, 4 cohorts and 5 periods\. '
          r'Jan 100% to 24%',
        ),
      ),
      findsOneWidget,
    );
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
}
