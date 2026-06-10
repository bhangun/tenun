import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/tenun.dart';

void main() {
  const categories = [
    SimpleLikertCategory(
      label: 'Strongly disagree',
      sentiment: SimpleLikertSentiment.negative,
    ),
    SimpleLikertCategory(
      label: 'Disagree',
      sentiment: SimpleLikertSentiment.negative,
    ),
    SimpleLikertCategory(
      label: 'Neutral',
      sentiment: SimpleLikertSentiment.neutral,
    ),
    SimpleLikertCategory(
      label: 'Agree',
      sentiment: SimpleLikertSentiment.positive,
    ),
    SimpleLikertCategory(
      label: 'Strongly agree',
      sentiment: SimpleLikertSentiment.positive,
    ),
  ];

  const items = [
    SimpleLikertItem(label: 'Ease', values: [4, 6, 18, 42, 30]),
    SimpleLikertItem(label: 'Trust', values: [6, 10, 20, 40, 24]),
    SimpleLikertItem(label: 'Support', values: [8, 12, 22, 36, 22]),
  ];

  testWidgets('renders likert styles without throwing', (tester) async {
    for (final style in SimpleBarChartStyle.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 520,
              height: 300,
              child: SimpleLikertChart(
                categories: categories,
                items: items,
                style: style,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SimpleLikertChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('shows likert tooltip on tap', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 520,
            height: 300,
            child: SimpleLikertChart(categories: categories, items: items),
          ),
        ),
      ),
    );

    await tester.tapAt(const Offset(348, 56));
    await tester.pump();

    expect(find.text('Ease'), findsWidgets);
    expect(find.text('Agree'), findsWidgets);
    expect(find.text('42%'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invokes likert segment tap callback without tooltip', (
    tester,
  ) async {
    String? tappedItem;
    String? tappedCategory;
    int? tappedItemIndex;
    int? tappedCategoryIndex;
    double? tappedDisplayedValue;
    double? tappedShare;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 520,
            height: 300,
            child: SimpleLikertChart(
              categories: categories,
              items: items,
              showTooltip: false,
              onSegmentTap:
                  (
                    item,
                    category,
                    itemIndex,
                    categoryIndex,
                    displayedValue,
                    share,
                  ) {
                    tappedItem = item.label;
                    tappedCategory = category.label;
                    tappedItemIndex = itemIndex;
                    tappedCategoryIndex = categoryIndex;
                    tappedDisplayedValue = displayedValue;
                    tappedShare = share;
                  },
            ),
          ),
        ),
      ),
    );

    await tester.tapAt(const Offset(348, 56));
    await tester.pump();

    expect(tappedItem, 'Ease');
    expect(tappedCategory, 'Agree');
    expect(tappedItemIndex, 0);
    expect(tappedCategoryIndex, 3);
    expect(tappedDisplayedValue, 42);
    expect(tappedShare, closeTo(0.42, 0.001));
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders absolute compact likert chart', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 240,
            child: SimpleLikertChart(
              categories: categories,
              items: items,
              stackAsPercent: false,
              showValues: false,
              showLegend: false,
              showAxisLabels: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SimpleLikertChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('exposes default likert semantics label', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 520,
            height: 300,
            child: SimpleLikertChart(categories: categories, items: items),
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(
        RegExp(
          r'Likert chart, 3 items and 5 response categories\. '
          r'Ease 72% positive, 10% negative',
        ),
      ),
      findsOneWidget,
    );
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
}
