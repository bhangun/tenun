import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/tenun.dart';

void main() {
  const stages = ['Channel', 'Intent', 'Outcome'];

  const flows = [
    SimpleAlluvialFlow(
      categories: ['Search', 'Trial', 'Subscribe'],
      value: 42,
      label: 'Search trial',
    ),
    SimpleAlluvialFlow(
      categories: ['Search', 'Demo', 'Subscribe'],
      value: 24,
      label: 'Search demo',
    ),
    SimpleAlluvialFlow(
      categories: ['Partner', 'Demo', 'Subscribe'],
      value: 18,
      label: 'Partner demo',
    ),
    SimpleAlluvialFlow(
      categories: ['Academy', 'Trial', 'Learn'],
      value: 16,
      label: 'Academy trial',
    ),
    SimpleAlluvialFlow(
      categories: ['Direct', 'Learn', 'Learn'],
      value: 10,
      label: 'Direct learn',
    ),
  ];

  testWidgets('renders alluvial styles without throwing', (tester) async {
    for (final style in SimpleBarChartStyle.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 460,
              height: 300,
              child: SimpleAlluvialChart(
                stageLabels: stages,
                flows: flows,
                style: style,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SimpleAlluvialChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('renders narrow alluvial without labels', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 180,
            height: 220,
            child: SimpleAlluvialChart(
              stageLabels: stages,
              flows: flows,
              showStageLabels: false,
              showNodeLabels: false,
              showValues: false,
              nodeGap: 6,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SimpleAlluvialChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows alluvial flow tooltip on tap', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 300,
            child: SimpleAlluvialChart(stageLabels: stages, flows: flows),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(150, 60));
    await tester.pump();

    expect(find.text('Search trial'), findsOneWidget);
    expect(find.text('42'), findsOneWidget);
    expect(find.text('Search -> Trial -> Subscribe'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invokes alluvial flow callback without tooltip', (tester) async {
    String? tappedLabel;
    int? tappedIndex;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 300,
            child: SimpleAlluvialChart(
              stageLabels: stages,
              flows: flows,
              showTooltip: false,
              onFlowTap: (flow, index) {
                tappedLabel = flow.label;
                tappedIndex = index;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(150, 60));
    await tester.pump();

    expect(tappedLabel, 'Search trial');
    expect(tappedIndex, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('exposes default alluvial semantics label', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 300,
            child: SimpleAlluvialChart(stageLabels: stages, flows: flows),
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(
        RegExp(r'Alluvial chart, 3 stages and 5 flows\. Search trial 42'),
      ),
      findsOneWidget,
    );
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
}
