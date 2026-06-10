import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/tenun.dart';

void main() {
  const data = [
    SimpleSlopeChartData(label: 'Onboarding', start: 62, end: 82),
    SimpleSlopeChartData(label: 'Activation', start: 54, end: 76),
    SimpleSlopeChartData(label: 'Retention', start: 70, end: 84),
    SimpleSlopeChartData(label: 'Risk', start: 48, end: 32),
  ];

  testWidgets('renders slope styles without throwing', (tester) async {
    for (final style in SimpleTrendChartStyle.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 460,
              height: 280,
              child: SimpleSlopeChart(data: data, style: style),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SimpleSlopeChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('renders slope with bounded value range and compact labels', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleSlopeChart(
              data: data,
              minValue: 0,
              maxValue: 100,
              includeZero: true,
              showDelta: false,
              showEndLabels: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SimpleSlopeChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows slope tooltip on tap', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleSlopeChart(
              data: data,
              startLabel: 'Before',
              endLabel: 'After',
              minValue: 0,
              maxValue: 100,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(230, 90));
    await tester.pump();

    expect(find.text('Onboarding'), findsWidgets);
    expect(find.text('62'), findsOneWidget);
    expect(find.text('82'), findsOneWidget);
    expect(find.text('+20'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invokes slope line tap callback without tooltip', (
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
            child: SimpleSlopeChart(
              data: data,
              minValue: 0,
              maxValue: 100,
              showTooltip: false,
              onLineTap: (item, index) {
                tappedLabel = item.label;
                tappedIndex = index;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(230, 90));
    await tester.pump();

    expect(tappedLabel, 'Onboarding');
    expect(tappedIndex, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('exposes default slope semantics label', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleSlopeChart(
              data: data,
              startLabel: 'Before',
              endLabel: 'After',
            ),
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(
        RegExp(
          r'Slope chart, 4 items\. Onboarding Before 62, After 82, change \+20',
        ),
      ),
      findsOneWidget,
    );
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
}
