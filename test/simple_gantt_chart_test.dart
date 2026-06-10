import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/tenun.dart';

void main() {
  final data = [
    SimpleGanttTask(
      id: 'research',
      label: 'Research',
      start: DateTime(2026, 1, 1),
      end: DateTime(2026, 1, 12),
      progress: 1,
      group: 'Discovery',
    ),
    SimpleGanttTask(
      id: 'design',
      label: 'Design',
      start: DateTime(2026, 1, 10),
      end: DateTime(2026, 1, 28),
      progress: 0.72,
      group: 'Delivery',
      dependencies: const ['research'],
    ),
    SimpleGanttTask(
      id: 'build',
      label: 'Build',
      start: DateTime(2026, 1, 24),
      end: DateTime(2026, 2, 22),
      progress: 0.38,
      group: 'Delivery',
      dependencies: const ['design'],
    ),
    SimpleGanttTask(
      id: 'launch',
      label: 'Launch',
      start: DateTime(2026, 2, 28),
      end: DateTime(2026, 2, 28),
      progress: 0,
      group: 'Release',
      dependencies: const ['build'],
      isMilestone: true,
    ),
  ];

  testWidgets('renders gantt styles without throwing', (tester) async {
    for (final style in SimpleBarChartStyle.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 520,
              height: 300,
              child: SimpleGanttChart(
                tasks: data,
                style: style,
                minDate: DateTime(2026, 1, 1),
                maxDate: DateTime(2026, 3, 1),
                today: DateTime(2026, 1, 20),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SimpleGanttChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('renders compact gantt without dependencies or dates', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 420,
            height: 260,
            child: SimpleGanttChart(
              tasks: data,
              minDate: DateTime(2026, 1, 1),
              maxDate: DateTime(2026, 3, 1),
              showDates: false,
              showDependencies: false,
              showToday: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SimpleGanttChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows gantt tooltip on tap', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 520,
            height: 300,
            child: SimpleGanttChart(
              tasks: data,
              minDate: DateTime(2026, 1, 1),
              maxDate: DateTime(2026, 3, 1),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(148, 39));
    await tester.pump();

    expect(find.text('Research'), findsWidgets);
    expect(find.text('Progress'), findsOneWidget);
    expect(find.text('100%'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invokes gantt tap callback without tooltip', (tester) async {
    String? tappedLabel;
    int? tappedIndex;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 520,
            height: 300,
            child: SimpleGanttChart(
              tasks: data,
              minDate: DateTime(2026, 1, 1),
              maxDate: DateTime(2026, 3, 1),
              showTooltip: false,
              onTaskTap: (task, index) {
                tappedLabel = task.label;
                tappedIndex = index;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(148, 39));
    await tester.pump();

    expect(tappedLabel, 'Research');
    expect(tappedIndex, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('exposes default gantt semantics label', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 520,
            height: 300,
            child: SimpleGanttChart(tasks: data),
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(
        RegExp(
          r'Gantt chart, 4 tasks\. Research 2026-01-01 to 2026-01-12, 100%',
        ),
      ),
      findsOneWidget,
    );
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
}
