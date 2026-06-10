import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/tenun.dart';

void main() {
  const data = [
    SimpleTreeDiagramData(
      label: 'Portfolio',
      value: 100,
      children: [
        SimpleTreeDiagramData(label: 'Core', value: 42),
        SimpleTreeDiagramData(label: 'Growth', value: 34),
        SimpleTreeDiagramData(label: 'Support', value: 24),
      ],
    ),
  ];

  const nestedData = [
    SimpleTreeDiagramData(
      label: 'Learning',
      children: [
        SimpleTreeDiagramData(
          label: 'Foundations',
          children: [
            SimpleTreeDiagramData(label: 'Reading', value: 22),
            SimpleTreeDiagramData(label: 'Practice', value: 18),
          ],
        ),
        SimpleTreeDiagramData(
          label: 'Mastery',
          children: [
            SimpleTreeDiagramData(label: 'Projects', value: 26),
            SimpleTreeDiagramData(label: 'Coaching', value: 14),
          ],
        ),
      ],
    ),
  ];

  testWidgets('renders tree diagram styles without throwing', (tester) async {
    for (final style in SimpleBarChartStyle.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 460,
              height: 280,
              child: SimpleTreeDiagramChart(data: data, style: style),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SimpleTreeDiagramChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('renders horizontal nested tree without root', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleTreeDiagramChart(
              data: nestedData,
              orientation: SimpleTreeDiagramOrientation.horizontal,
              showRoot: false,
              showValues: true,
              curvedLinks: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SimpleTreeDiagramChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows tree tooltip on tap', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleTreeDiagramChart(data: data),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(230, 34));
    await tester.pump();

    expect(find.text('Portfolio'), findsWidgets);
    expect(find.text('Depth 0'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invokes tree node tap callback without tooltip', (tester) async {
    String? tappedLabel;
    double? tappedValue;
    int? tappedDepth;
    int? tappedPathLength;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleTreeDiagramChart(
              data: data,
              showTooltip: false,
              onNodeTap: (node, path, value, depth) {
                tappedLabel = node.label;
                tappedValue = value;
                tappedDepth = depth;
                tappedPathLength = path.length;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(230, 34));
    await tester.pump();

    expect(tappedLabel, 'Portfolio');
    expect(tappedValue, 100);
    expect(tappedDepth, 0);
    expect(tappedPathLength, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('exposes default tree semantics label', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleTreeDiagramChart(data: data),
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(
        RegExp(r'Tree diagram, 4 nodes and 3 links\. Portfolio 100'),
      ),
      findsOneWidget,
    );
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
}
