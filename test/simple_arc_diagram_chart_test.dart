import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/tenun.dart';

void main() {
  const nodes = [
    SimpleArcDiagramNode(id: 'awareness', label: 'Awareness'),
    SimpleArcDiagramNode(id: 'trial', label: 'Trial'),
    SimpleArcDiagramNode(id: 'demo', label: 'Demo'),
    SimpleArcDiagramNode(id: 'subscribe', label: 'Subscribe'),
    SimpleArcDiagramNode(id: 'learn', label: 'Learn'),
  ];

  const links = [
    SimpleArcDiagramLink(
      source: 'awareness',
      target: 'trial',
      value: 40,
      label: 'Awareness to Trial',
    ),
    SimpleArcDiagramLink(
      source: 'awareness',
      target: 'demo',
      value: 20,
      label: 'Awareness to Demo',
    ),
    SimpleArcDiagramLink(
      source: 'trial',
      target: 'subscribe',
      value: 18,
      label: 'Trial to Subscribe',
    ),
    SimpleArcDiagramLink(
      source: 'demo',
      target: 'subscribe',
      value: 16,
      label: 'Demo to Subscribe',
    ),
    SimpleArcDiagramLink(
      source: 'trial',
      target: 'learn',
      value: 12,
      label: 'Trial to Learn',
    ),
  ];

  testWidgets('renders arc diagram styles without throwing', (tester) async {
    for (final style in SimpleBarChartStyle.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 460,
              height: 300,
              child: SimpleArcDiagramChart(
                nodes: nodes,
                links: links,
                style: style,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SimpleArcDiagramChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('renders narrow arc diagram without labels', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 180,
            height: 220,
            child: SimpleArcDiagramChart(
              nodes: nodes,
              links: links,
              showLabels: false,
              showValues: false,
              showDirection: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SimpleArcDiagramChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows arc diagram link tooltip on tap', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 300,
            child: SimpleArcDiagramChart(nodes: nodes, links: links),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(102, 190));
    await tester.pump();

    expect(find.text('Awareness to Trial'), findsOneWidget);
    expect(find.text('40'), findsOneWidget);
    expect(find.text('Awareness'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invokes arc diagram link callback without tooltip', (
    tester,
  ) async {
    String? tappedLabel;
    int? tappedIndex;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 300,
            child: SimpleArcDiagramChart(
              nodes: nodes,
              links: links,
              showTooltip: false,
              onLinkTap: (link, index) {
                tappedLabel = link.label;
                tappedIndex = index;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(102, 190));
    await tester.pump();

    expect(tappedLabel, 'Awareness to Trial');
    expect(tappedIndex, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('exposes default arc diagram semantics label', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 300,
            child: SimpleArcDiagramChart(nodes: nodes, links: links),
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(
        RegExp(r'Arc diagram, 5 nodes and 5 links\. Awareness to Trial 40'),
      ),
      findsOneWidget,
    );
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
}
