import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/tenun.dart';

void main() {
  const points = [
    SimpleBlandAltmanPoint(label: 'P1', measurementA: 10, measurementB: 12),
    SimpleBlandAltmanPoint(label: 'P2', measurementA: 20, measurementB: 23),
    SimpleBlandAltmanPoint(label: 'P3', measurementA: 30, measurementB: 31),
    SimpleBlandAltmanPoint(label: 'P4', measurementA: 40, measurementB: 43),
    SimpleBlandAltmanPoint(label: 'P5', measurementA: 50, measurementB: 54),
  ];

  testWidgets('renders Bland-Altman styles without throwing', (tester) async {
    for (final style in SimpleBarChartStyle.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 460,
              height: 280,
              child: SimpleBlandAltmanChart(
                points: points,
                style: style,
                minMean: 0,
                maxMean: 60,
                minDifference: 0,
                maxDifference: 6,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SimpleBlandAltmanChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('renders compact Bland-Altman chart without labels or band', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 260,
            height: 220,
            child: SimpleBlandAltmanChart(
              points: points,
              showAxisLabels: false,
              showLegend: false,
              showValues: true,
              showAgreementBand: false,
              showAgreementLimits: false,
              agreementMultiplier: 1,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SimpleBlandAltmanChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows Bland-Altman tooltip on tap', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleBlandAltmanChart(
              points: points,
              minMean: 0,
              maxMean: 60,
              minDifference: 0,
              maxDifference: 6,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(247, 201));
    await tester.pump();

    expect(find.text('P3'), findsOneWidget);
    expect(find.text('+1'), findsOneWidget);
    expect(find.text('+2.6'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invokes Bland-Altman tap callback without tooltip', (
    tester,
  ) async {
    String? tappedLabel;
    int? tappedIndex;
    double? tappedMean;
    double? tappedDifference;
    double? tappedBias;
    bool? tappedOutsideLimits;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleBlandAltmanChart(
              points: points,
              minMean: 0,
              maxMean: 60,
              minDifference: 0,
              maxDifference: 6,
              showTooltip: false,
              onPointTap: (point, index, stats, outsideLimits) {
                tappedLabel = point.label;
                tappedIndex = index;
                tappedMean = point.mean;
                tappedDifference = point.difference;
                tappedBias = stats.bias;
                tappedOutsideLimits = outsideLimits;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(247, 201));
    await tester.pump();

    expect(tappedLabel, 'P3');
    expect(tappedIndex, 2);
    expect(tappedMean, closeTo(30.5, 0.001));
    expect(tappedDifference, closeTo(1, 0.001));
    expect(tappedBias, closeTo(2.6, 0.001));
    expect(tappedOutsideLimits, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('exposes default Bland-Altman semantics label', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleBlandAltmanChart(points: points),
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(
        RegExp(
          r'Bland-Altman chart, 5 pairs\. Bias \+2\.6, lower agreement limit \+0\.4',
        ),
      ),
      findsOneWidget,
    );
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
}
