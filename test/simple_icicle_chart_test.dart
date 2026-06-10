import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/tenun.dart';

void main() {
  const data = [
    SimpleIcicleData(
      label: 'Portfolio',
      value: 100,
      children: [
        SimpleIcicleData(label: 'Core', value: 42),
        SimpleIcicleData(label: 'Growth', value: 34),
        SimpleIcicleData(label: 'Support', value: 24),
      ],
    ),
  ];

  const nestedData = [
    SimpleIcicleData(
      label: 'Learning',
      children: [
        SimpleIcicleData(
          label: 'Foundations',
          children: [
            SimpleIcicleData(label: 'Reading', value: 22),
            SimpleIcicleData(label: 'Practice', value: 18),
          ],
        ),
        SimpleIcicleData(
          label: 'Mastery',
          children: [
            SimpleIcicleData(label: 'Projects', value: 26),
            SimpleIcicleData(label: 'Coaching', value: 14),
          ],
        ),
      ],
    ),
  ];

  testWidgets('renders icicle styles without throwing', (tester) async {
    for (final style in SimpleBarChartStyle.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 460,
              height: 280,
              child: SimpleIcicleChart(data: data, style: style),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SimpleIcicleChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('renders horizontal nested icicle with parent labels hidden', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleIcicleChart(
              data: nestedData,
              orientation: SimpleIcicleOrientation.horizontal,
              showParentLabels: false,
              showValues: true,
              maxDepth: 3,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SimpleIcicleChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows icicle tooltip on tap', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleIcicleChart(data: data),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(230, 50));
    await tester.pump();

    expect(find.text('Portfolio'), findsWidgets);
    expect(find.text('Value'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invokes icicle segment tap callback without tooltip', (
    tester,
  ) async {
    String? tappedLabel;
    double? tappedValue;
    double? tappedShare;
    int? tappedPathLength;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleIcicleChart(
              data: data,
              showTooltip: false,
              onSegmentTap: (segment, path, value, share) {
                tappedLabel = segment.label;
                tappedValue = value;
                tappedShare = share;
                tappedPathLength = path.length;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(230, 50));
    await tester.pump();

    expect(tappedLabel, 'Portfolio');
    expect(tappedValue, 100);
    expect(tappedShare, 100);
    expect(tappedPathLength, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('exposes default icicle semantics label', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleIcicleChart(data: data),
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(RegExp(r'Icicle chart, 3 segments\. Core 42, 42%')),
      findsOneWidget,
    );
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
}
