import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/tenun.dart';

void main() {
  const nodes = [
    SimpleChordNode(id: 'awareness', label: 'Awareness'),
    SimpleChordNode(id: 'trial', label: 'Trial'),
    SimpleChordNode(id: 'demo', label: 'Demo'),
    SimpleChordNode(id: 'closed', label: 'Closed'),
  ];

  const links = [
    SimpleChordLink(source: 'awareness', target: 'trial', value: 40),
    SimpleChordLink(source: 'awareness', target: 'demo', value: 20),
    SimpleChordLink(source: 'awareness', target: 'closed', value: 10),
    SimpleChordLink(source: 'trial', target: 'closed', value: 18),
    SimpleChordLink(source: 'demo', target: 'closed', value: 16),
  ];

  testWidgets('renders chord styles without throwing', (tester) async {
    for (final style in SimpleBarChartStyle.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 460,
              height: 300,
              child: SimpleChordChart(nodes: nodes, links: links, style: style),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SimpleChordChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('renders narrow chord without labels', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 150,
            height: 220,
            child: SimpleChordChart(
              nodes: nodes,
              links: links,
              showLabels: false,
              showValues: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SimpleChordChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows chord node tooltip on tap', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 300,
            child: SimpleChordChart(nodes: nodes, links: links),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(318, 94));
    await tester.pump();

    expect(find.text('Awareness'), findsWidgets);
    expect(find.text('70'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invokes chord node tap callback without tooltip', (
    tester,
  ) async {
    String? tappedNode;
    double? tappedValue;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 300,
            child: SimpleChordChart(
              nodes: nodes,
              links: links,
              showTooltip: false,
              onNodeTap: (node, value) {
                tappedNode = node.label;
                tappedValue = value;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(318, 94));
    await tester.pump();

    expect(tappedNode, 'Awareness');
    expect(tappedValue, 70);
    expect(tester.takeException(), isNull);
  });

  testWidgets('exposes default chord semantics label', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 300,
            child: SimpleChordChart(nodes: nodes, links: links),
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(
        RegExp(r'Chord chart, 4 nodes and 5 links\. awareness to trial 40'),
      ),
      findsOneWidget,
    );
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
}
