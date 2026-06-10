import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/tenun.dart';

void main() {
  final lanes = [
    SimpleEventStripLane(
      label: 'Release',
      events: [
        SimpleEventStripEvent(
          date: DateTime(2026, 1, 8),
          label: 'Discovery',
          description: 'Signals mapped',
          tag: 'Plan',
        ),
        SimpleEventStripEvent(
          date: DateTime(2026, 2, 14),
          label: 'Beta',
          description: 'Cohort activated',
          tag: 'Build',
          weight: 2,
        ),
        SimpleEventStripEvent(
          date: DateTime(2026, 3, 22),
          label: 'Launch',
          description: 'Public release',
          tag: 'Ship',
          weight: 3,
        ),
      ],
    ),
    SimpleEventStripLane(
      label: 'Ops',
      events: [
        SimpleEventStripEvent(
          date: DateTime(2026, 1, 18),
          label: 'Audit',
          weight: 1.4,
        ),
        SimpleEventStripEvent(
          date: DateTime(2026, 2, 26),
          label: 'Incident',
          description: 'Latency spike',
          tag: 'Risk',
          weight: 2.6,
        ),
        SimpleEventStripEvent(
          date: DateTime(2026, 4, 10),
          label: 'Recovery',
          weight: 1.8,
        ),
      ],
    ),
    SimpleEventStripLane(
      label: 'Learning',
      events: [
        SimpleEventStripEvent(date: DateTime(2026, 1, 15), label: 'Lesson'),
        SimpleEventStripEvent(
          date: DateTime(2026, 3, 5),
          label: 'Workshop',
          weight: 2.2,
        ),
        SimpleEventStripEvent(
          date: DateTime(2026, 4, 18),
          label: 'Review',
          weight: 1.7,
        ),
      ],
    ),
  ];

  testWidgets('renders event strip styles without throwing', (tester) async {
    for (final style in SimpleBarChartStyle.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 460,
              height: 280,
              child: SimpleEventStripChart(
                lanes: lanes,
                style: style,
                minDate: DateTime(2026),
                maxDate: DateTime(2026, 5),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SimpleEventStripChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('renders event labels and marker date', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 500,
            height: 280,
            child: SimpleEventStripChart(
              lanes: lanes,
              minDate: DateTime(2026),
              maxDate: DateTime(2026, 5),
              markerDate: DateTime(2026, 3, 1),
              showEventLabels: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SimpleEventStripChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows event strip tooltip on tap', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleEventStripChart(
              lanes: lanes,
              minDate: DateTime(2026),
              maxDate: DateTime(2026, 5),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(214, 57));
    await tester.pump();

    expect(find.text('Beta'), findsWidgets);
    expect(find.text('Release'), findsWidgets);
    expect(find.text('2026-02-14'), findsWidgets);
    expect(find.text('Cohort activated'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invokes event strip tap callback without tooltip', (
    tester,
  ) async {
    String? tappedLabel;
    int? tappedLane;
    int? tappedEvent;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleEventStripChart(
              lanes: lanes,
              minDate: DateTime(2026),
              maxDate: DateTime(2026, 5),
              showTooltip: false,
              onEventTap: (event, laneIndex, eventIndex) {
                tappedLabel = event.label;
                tappedLane = laneIndex;
                tappedEvent = eventIndex;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(214, 57));
    await tester.pump();

    expect(tappedLabel, 'Beta');
    expect(tappedLane, 0);
    expect(tappedEvent, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('exposes default event strip semantics label', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleEventStripChart(lanes: lanes),
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(
        RegExp(
          r'Event strip chart, 3 lanes, 9 events\. Release: 2026-01-08 Discovery \(1\)',
        ),
      ),
      findsOneWidget,
    );
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
}
