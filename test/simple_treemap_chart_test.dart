import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/tenun.dart';

void main() {
  const data = [
    SimpleTreemapData(
      label: 'Core',
      value: 42,
      children: [
        SimpleTreemapData(label: 'Product', value: 18),
        SimpleTreemapData(label: 'Platform', value: 14),
        SimpleTreemapData(label: 'Trust', value: 10),
      ],
    ),
    SimpleTreemapData(
      label: 'Growth',
      value: 28,
      children: [
        SimpleTreemapData(label: 'Acquisition', value: 12),
        SimpleTreemapData(label: 'Expansion', value: 10),
        SimpleTreemapData(label: 'Labs', value: 6),
      ],
    ),
    SimpleTreemapData(label: 'Education', value: 18),
    SimpleTreemapData(label: 'Support', value: 12),
  ];

  testWidgets('renders treemap styles without throwing', (tester) async {
    for (final style in SimpleBarChartStyle.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 460,
              height: 280,
              child: SimpleTreemapChart(data: data, style: style),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SimpleTreemapChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('renders treemap with shallow depth and compact labels', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleTreemapChart(
              data: data,
              maxDepth: 1,
              showValues: false,
              showParentLabels: false,
              minLabelArea: 500,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SimpleTreemapChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows treemap tooltip on tap', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleTreemapChart(data: data, maxDepth: 1),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(80, 120));
    await tester.pump();

    expect(find.text('Core'), findsWidgets);
    expect(find.text('42'), findsWidgets);
    expect(find.text('42%'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invokes treemap tile tap callback without tooltip', (
    tester,
  ) async {
    String? tappedLabel;
    double? tappedShare;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleTreemapChart(
              data: data,
              maxDepth: 1,
              showTooltip: false,
              onTileTap: (item, path, value, share) {
                tappedLabel = item.label;
                tappedShare = share;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(80, 120));
    await tester.pump();

    expect(tappedLabel, 'Core');
    expect(tappedShare, closeTo(0.42, 0.001));
    expect(tester.takeException(), isNull);
  });

  testWidgets('exposes default treemap semantics label', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleTreemapChart(data: data),
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(
        RegExp(r'Treemap chart, 8 tiles\. Product 18, 18%'),
      ),
      findsOneWidget,
    );
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
}
