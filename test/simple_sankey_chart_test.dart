import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/tenun.dart';

void main() {
  const links = [
    SimpleSankeyLink(source: 'Visitors', target: 'Signup', value: 72),
    SimpleSankeyLink(source: 'Visitors', target: 'Browse', value: 28),
    SimpleSankeyLink(source: 'Signup', target: 'Trial', value: 43),
    SimpleSankeyLink(source: 'Signup', target: 'Demo', value: 19),
    SimpleSankeyLink(source: 'Browse', target: 'Demo', value: 11),
    SimpleSankeyLink(source: 'Trial', target: 'Paid', value: 24),
    SimpleSankeyLink(source: 'Demo', target: 'Paid', value: 18),
  ];

  testWidgets('renders sankey styles without throwing', (tester) async {
    for (final style in SimpleBarChartStyle.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 460,
              height: 280,
              child: SimpleSankeyChart(links: links, style: style),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SimpleSankeyChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('renders sankey with explicit nodes and compact labels', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleSankeyChart(
              nodes: [
                SimpleSankeyNode(id: 'Visitors', label: 'Traffic', column: 0),
                SimpleSankeyNode(id: 'Signup', label: 'Signups', column: 1),
                SimpleSankeyNode(id: 'Browse', label: 'Browsing', column: 1),
                SimpleSankeyNode(id: 'Trial', label: 'Trials', column: 2),
                SimpleSankeyNode(id: 'Demo', label: 'Demos', column: 2),
                SimpleSankeyNode(id: 'Paid', label: 'Paid', column: 3),
              ],
              links: links,
              showValues: false,
              showNodeValues: true,
              nodeGap: 10,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SimpleSankeyChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows sankey node tooltip on tap', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleSankeyChart(links: links),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(76, 80));
    await tester.pump();

    expect(find.text('Visitors'), findsWidgets);
    expect(find.text('Flow'), findsOneWidget);
    expect(find.text('100'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invokes sankey link tap callback without tooltip', (
    tester,
  ) async {
    String? tappedSource;
    String? tappedTarget;
    double? tappedValue;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleSankeyChart(
              links: links,
              showTooltip: false,
              onLinkTap: (link, value) {
                tappedSource = link.source;
                tappedTarget = link.target;
                tappedValue = value;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(125, 98));
    await tester.pump();

    expect(tappedSource, 'Visitors');
    expect(tappedTarget, 'Signup');
    expect(tappedValue, 72);
    expect(tester.takeException(), isNull);
  });

  testWidgets('exposes default sankey semantics label', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleSankeyChart(links: links),
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(
        RegExp(r'Sankey chart, 6 nodes and 7 links\. Visitors to Signup 72'),
      ),
      findsOneWidget,
    );
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
}
