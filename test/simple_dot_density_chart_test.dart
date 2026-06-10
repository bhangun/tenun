import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/tenun.dart';

void main() {
  const data = [
    SimpleDotDensityChartData(label: 'Ready', value: 36),
    SimpleDotDensityChartData(label: 'Coached', value: 9),
    SimpleDotDensityChartData(label: 'Needs Help', value: 5),
  ];

  testWidgets('renders dot density styles without throwing', (tester) async {
    for (final style in SimpleBarChartStyle.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 460,
              height: 280,
              child: SimpleDotDensityChart(data: data, style: style),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SimpleDotDensityChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('renders progress dot density with empty dots', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleDotDensityChart(
              data: [SimpleDotDensityChartData(label: 'Completion', value: 73)],
              totalValue: 100,
              rows: 5,
              columns: 10,
              showLegend: false,
              fillDirection: SimpleDotDensityFillDirection.leftToRight,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SimpleDotDensityChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows dot density tooltip on tap', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleDotDensityChart(data: data),
          ),
        ),
      ),
    );

    await tester.tapAt(const Offset(28, 190));
    await tester.pump();

    expect(find.text('Ready'), findsWidgets);
    expect(find.text('72%'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invokes dot density tap callback without tooltip', (
    tester,
  ) async {
    String? tappedLabel;
    int? tappedIndex;
    double? tappedShare;
    int? tappedDots;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleDotDensityChart(
              data: data,
              showTooltip: false,
              onDotTap: (item, index, share, dotCount) {
                tappedLabel = item.label;
                tappedIndex = index;
                tappedShare = share;
                tappedDots = dotCount;
              },
            ),
          ),
        ),
      ),
    );

    await tester.tapAt(const Offset(28, 190));
    await tester.pump();

    expect(tappedLabel, 'Ready');
    expect(tappedIndex, 0);
    expect(tappedShare, 0.72);
    expect(tappedDots, 36);
    expect(tester.takeException(), isNull);
  });

  testWidgets('exposes default dot density semantics label', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleDotDensityChart(data: data),
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(
        RegExp(r'Dot density chart, 3 categories\. Ready 36, 72%'),
      ),
      findsOneWidget,
    );
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
}
