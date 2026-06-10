import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/tenun.dart';

void main() {
  final data = [
    SimpleTimelineEvent(
      date: DateTime(2026, 1, 8),
      title: 'Discovery',
      description: 'Research complete',
      tag: 'Plan',
    ),
    SimpleTimelineEvent(
      date: DateTime(2026, 2, 12),
      title: 'Pilot',
      description: 'First cohort live',
      tag: 'Build',
    ),
    SimpleTimelineEvent(
      date: DateTime(2026, 3, 18),
      title: 'Launch',
      description: 'Public release',
      tag: 'Ship',
    ),
    SimpleTimelineEvent(
      date: DateTime(2026, 4, 25),
      title: 'Review',
      description: 'Impact report',
      tag: 'Learn',
    ),
  ];

  testWidgets('renders timeline styles without throwing', (tester) async {
    for (final style in SimpleBarChartStyle.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 460,
              height: 280,
              child: SimpleTimelineChart(events: data, style: style),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SimpleTimelineChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('renders horizontal alternating timeline', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 480,
            height: 260,
            child: SimpleTimelineChart(
              events: data,
              orientation: SimpleTimelineOrientation.horizontal,
              alternating: true,
              showDescriptions: false,
              showTags: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SimpleTimelineChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows timeline tooltip on tap', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleTimelineChart(events: data),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(110, 49));
    await tester.pump();

    expect(find.text('Discovery'), findsWidgets);
    expect(find.text('2026-01-08'), findsWidgets);
    expect(find.text('Research complete'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invokes timeline tap callback without tooltip', (tester) async {
    String? tappedTitle;
    int? tappedIndex;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleTimelineChart(
              events: data,
              showTooltip: false,
              onEventTap: (event, index) {
                tappedTitle = event.title;
                tappedIndex = index;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(110, 49));
    await tester.pump();

    expect(tappedTitle, 'Discovery');
    expect(tappedIndex, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('exposes default timeline semantics label', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleTimelineChart(events: data),
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(
        RegExp(
          r'Timeline chart, 4 events\. 2026-01-08 Discovery, Research complete',
        ),
      ),
      findsOneWidget,
    );
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
}
