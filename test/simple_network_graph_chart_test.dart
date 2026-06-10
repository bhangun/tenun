import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/tenun.dart';

void main() {
  const nodes = [
    SimpleNetworkNode(
      id: 'platform',
      label: 'Platform',
      value: 30,
      group: 'Core',
      x: 0.22,
      y: 0.42,
    ),
    SimpleNetworkNode(
      id: 'data',
      label: 'Data',
      value: 18,
      group: 'Core',
      x: 0.50,
      y: 0.20,
    ),
    SimpleNetworkNode(
      id: 'learning',
      label: 'Learning',
      value: 14,
      group: 'Experience',
      x: 0.78,
      y: 0.36,
    ),
    SimpleNetworkNode(
      id: 'support',
      label: 'Support',
      value: 12,
      group: 'Experience',
      x: 0.68,
      y: 0.72,
    ),
    SimpleNetworkNode(
      id: 'billing',
      label: 'Billing',
      value: 10,
      group: 'Ops',
      x: 0.32,
      y: 0.78,
    ),
  ];

  const links = [
    SimpleNetworkLink(
      source: 'platform',
      target: 'data',
      value: 8,
      label: 'Telemetry',
    ),
    SimpleNetworkLink(source: 'data', target: 'learning', value: 5),
    SimpleNetworkLink(source: 'platform', target: 'billing', value: 4),
    SimpleNetworkLink(source: 'learning', target: 'support', value: 3),
    SimpleNetworkLink(source: 'support', target: 'platform', value: 2),
  ];

  testWidgets('renders network graph styles without throwing', (tester) async {
    for (final style in SimpleBarChartStyle.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 460,
              height: 280,
              child: SimpleNetworkGraphChart(
                nodes: nodes,
                links: links,
                style: style,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SimpleNetworkGraphChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('renders grouped directed network with link labels', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleNetworkGraphChart(
              nodes: nodes,
              links: links,
              layout: SimpleNetworkGraphLayout.grouped,
              directed: true,
              showValues: true,
              showLinkLabels: true,
              showLegend: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SimpleNetworkGraphChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows network node tooltip on tap', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleNetworkGraphChart(
              nodes: nodes,
              links: links,
              layout: SimpleNetworkGraphLayout.positioned,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(115, 120));
    await tester.pump();

    expect(find.text('Platform'), findsWidgets);
    expect(find.text('Core'), findsWidgets);
    expect(find.text('Value'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invokes network node tap callback without tooltip', (
    tester,
  ) async {
    String? tappedId;
    int? tappedIndex;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleNetworkGraphChart(
              nodes: nodes,
              links: links,
              layout: SimpleNetworkGraphLayout.positioned,
              showTooltip: false,
              onNodeTap: (node, index) {
                tappedId = node.id;
                tappedIndex = index;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(115, 120));
    await tester.pump();

    expect(tappedId, 'platform');
    expect(tappedIndex, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invokes network link tap callback without tooltip', (
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
            child: SimpleNetworkGraphChart(
              nodes: nodes,
              links: links,
              layout: SimpleNetworkGraphLayout.positioned,
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

    await tester.tapAt(const Offset(173, 95));
    await tester.pump();

    expect(tappedLabel, 'Telemetry');
    expect(tappedIndex, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('exposes default network semantics label', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleNetworkGraphChart(nodes: nodes, links: links),
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(
        RegExp(r'Network graph, 5 nodes and 5 links\. Platform to Data 8'),
      ),
      findsOneWidget,
    );
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
}
