import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/tenun.dart';

void main() {
  const data = [
    SimplePictogramChartData(label: 'Ready', value: 36),
    SimplePictogramChartData(label: 'Coached', value: 9),
    SimplePictogramChartData(label: 'Needs Help', value: 5),
  ];

  testWidgets('renders pictogram styles without throwing', (tester) async {
    for (final style in SimpleBarChartStyle.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 460,
              height: 280,
              child: SimplePictogramChart(data: data, style: style),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SimplePictogramChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('renders pictogram symbol variants', (tester) async {
    for (final symbol in SimplePictogramSymbol.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 460,
              height: 280,
              child: SimplePictogramChart(
                data: data,
                symbol: symbol,
                showLegend: false,
                fillDirection: SimplePictogramFillDirection.leftToRight,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SimplePictogramChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('shows pictogram tooltip on tap', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimplePictogramChart(data: data),
          ),
        ),
      ),
    );

    await tester.tapAt(const Offset(29, 192));
    await tester.pump();

    expect(find.text('Ready'), findsWidgets);
    expect(find.text('72%'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invokes pictogram unit tap callback without tooltip', (
    tester,
  ) async {
    String? tappedLabel;
    int? tappedIndex;
    double? tappedShare;
    int? tappedUnits;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimplePictogramChart(
              data: data,
              showTooltip: false,
              onUnitTap: (item, index, share, unitCount) {
                tappedLabel = item.label;
                tappedIndex = index;
                tappedShare = share;
                tappedUnits = unitCount;
              },
            ),
          ),
        ),
      ),
    );

    await tester.tapAt(const Offset(29, 192));
    await tester.pump();

    expect(tappedLabel, 'Ready');
    expect(tappedIndex, 0);
    expect(tappedShare, 0.72);
    expect(tappedUnits, 36);
    expect(tester.takeException(), isNull);
  });

  testWidgets('exposes default pictogram semantics label', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimplePictogramChart(data: data),
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(
        RegExp(r'Pictogram chart, 3 categories\. Ready 36, 72%'),
      ),
      findsOneWidget,
    );
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
}
