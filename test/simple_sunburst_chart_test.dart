import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/tenun.dart';

void main() {
  const data = [
    SimpleSunburstData(
      label: 'Core',
      value: 42,
      children: [
        SimpleSunburstData(label: 'Product', value: 18),
        SimpleSunburstData(label: 'Platform', value: 14),
        SimpleSunburstData(label: 'Trust', value: 10),
      ],
    ),
    SimpleSunburstData(
      label: 'Growth',
      value: 28,
      children: [
        SimpleSunburstData(label: 'Acquisition', value: 12),
        SimpleSunburstData(label: 'Expansion', value: 10),
        SimpleSunburstData(label: 'Labs', value: 6),
      ],
    ),
    SimpleSunburstData(
      label: 'Education',
      value: 18,
      children: [
        SimpleSunburstData(label: 'Academy', value: 10),
        SimpleSunburstData(label: 'Workshops', value: 8),
      ],
    ),
    SimpleSunburstData(
      label: 'Support',
      value: 12,
      children: [
        SimpleSunburstData(label: 'Success', value: 7),
        SimpleSunburstData(label: 'Ops', value: 5),
      ],
    ),
  ];

  testWidgets('renders sunburst styles without throwing', (tester) async {
    for (final style in SimpleBarChartStyle.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 460,
              height: 280,
              child: SimpleSunburstChart(data: data, style: style),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SimpleSunburstChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('renders sunburst with shallow depth and center label', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleSunburstChart(
              data: data,
              maxDepth: 1,
              centerLabel: 'Portfolio',
              showValues: false,
              showParentLabels: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SimpleSunburstChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows sunburst tooltip on tap', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleSunburstChart(data: data, maxDepth: 1),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(300, 120));
    await tester.pump();

    expect(find.text('Core'), findsWidgets);
    expect(find.text('42'), findsWidgets);
    expect(find.text('42%'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invokes sunburst segment tap callback without tooltip', (
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
            child: SimpleSunburstChart(
              data: data,
              maxDepth: 1,
              showTooltip: false,
              onSegmentTap: (item, path, value, share) {
                tappedLabel = item.label;
                tappedShare = share;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(300, 120));
    await tester.pump();

    expect(tappedLabel, 'Core');
    expect(tappedShare, closeTo(0.42, 0.001));
    expect(tester.takeException(), isNull);
  });

  testWidgets('exposes default sunburst semantics label', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleSunburstChart(data: data),
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(
        RegExp(r'Sunburst chart, 10 segments\. Product 18, 18%'),
      ),
      findsOneWidget,
    );
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
}
