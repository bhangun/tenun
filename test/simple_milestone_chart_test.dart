import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/tenun.dart';

void main() {
  final data = [
    SimpleMilestoneData(
      date: DateTime(2026, 1, 8),
      label: 'Discovery',
      description: 'Signals mapped',
      tag: 'Plan',
      status: SimpleMilestoneStatus.done,
    ),
    SimpleMilestoneData(
      date: DateTime(2026, 2, 14),
      label: 'Pilot',
      description: 'First cohort activated',
      tag: 'Build',
      status: SimpleMilestoneStatus.active,
    ),
    SimpleMilestoneData(
      date: DateTime(2026, 3, 22),
      label: 'Launch',
      description: 'Public workflow released',
      tag: 'Ship',
    ),
    SimpleMilestoneData(
      date: DateTime(2026, 4, 18),
      label: 'Review',
      description: 'Quality readout',
      tag: 'Learn',
      status: SimpleMilestoneStatus.blocked,
    ),
  ];

  testWidgets('renders milestone styles without throwing', (tester) async {
    for (final style in SimpleBarChartStyle.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 460,
              height: 280,
              child: SimpleMilestoneChart(
                milestones: data,
                style: style,
                minDate: DateTime(2026),
                maxDate: DateTime(2026, 5),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SimpleMilestoneChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('renders vertical milestone chart', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 300,
            child: SimpleMilestoneChart(
              milestones: data,
              orientation: SimpleMilestoneOrientation.vertical,
              minDate: DateTime(2026),
              maxDate: DateTime(2026, 5),
              showDescriptions: false,
              showTags: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SimpleMilestoneChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows milestone tooltip on tap', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleMilestoneChart(
              milestones: data,
              minDate: DateTime(2026),
              maxDate: DateTime(2026, 5),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(176, 132));
    await tester.pump();

    expect(find.text('Pilot'), findsWidgets);
    expect(find.text('2026-02-14'), findsWidgets);
    expect(find.text('active'), findsOneWidget);
    expect(find.text('First cohort activated'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invokes milestone tap callback without tooltip', (tester) async {
    String? tappedLabel;
    int? tappedIndex;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleMilestoneChart(
              milestones: data,
              minDate: DateTime(2026),
              maxDate: DateTime(2026, 5),
              showTooltip: false,
              onMilestoneTap: (milestone, index) {
                tappedLabel = milestone.label;
                tappedIndex = index;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(176, 132));
    await tester.pump();

    expect(tappedLabel, 'Pilot');
    expect(tappedIndex, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('exposes default milestone semantics label', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleMilestoneChart(milestones: data),
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(
        RegExp(
          r'Milestone chart, 4 milestones\. 2026-01-08 Discovery, done, Signals mapped',
        ),
      ),
      findsOneWidget,
    );
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
}
