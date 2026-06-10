import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/tenun.dart';

void main() {
  const words = [
    SimpleWordCloudData(text: 'Trust', value: 42, group: 'Brand'),
    SimpleWordCloudData(text: 'Speed', value: 34, group: 'Product'),
    SimpleWordCloudData(text: 'Support', value: 30, group: 'Service'),
    SimpleWordCloudData(text: 'Learning', value: 24, group: 'Education'),
    SimpleWordCloudData(text: 'Quality', value: 21, group: 'Product'),
    SimpleWordCloudData(text: 'Clarity', value: 17, group: 'Brand'),
    SimpleWordCloudData(text: 'Access', value: 14, group: 'Service'),
    SimpleWordCloudData(text: 'Growth', value: 12, group: 'Education'),
  ];

  testWidgets('renders word cloud styles without throwing', (tester) async {
    for (final style in SimpleBarChartStyle.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 460,
              height: 280,
              child: SimpleWordCloudChart(
                words: words,
                style: style,
                allowRotation: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SimpleWordCloudChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('renders word cloud shapes with values', (tester) async {
    for (final shape in SimpleWordCloudShape.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 460,
              height: 280,
              child: SimpleWordCloudChart(
                words: words,
                shape: shape,
                showValues: true,
                showLegend: false,
                allowRotation: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SimpleWordCloudChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('shows word cloud tooltip on tap', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleWordCloudChart(words: words, allowRotation: false),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(230, 141));
    await tester.pump();

    expect(find.text('Trust'), findsOneWidget);
    expect(find.text('Brand'), findsOneWidget);
    expect(find.text('Value'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invokes word tap callback without tooltip', (tester) async {
    String? tappedText;
    int? tappedIndex;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleWordCloudChart(
              words: words,
              allowRotation: false,
              showTooltip: false,
              onWordTap: (word, index) {
                tappedText = word.text;
                tappedIndex = index;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(230, 141));
    await tester.pump();

    expect(tappedText, 'Trust');
    expect(tappedIndex, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('exposes default word cloud semantics label', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 460,
            height: 280,
            child: SimpleWordCloudChart(words: words),
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(
        RegExp(r'Word cloud, 8 words\. Trust 42, Speed 34, Support 30'),
      ),
      findsOneWidget,
    );
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
}
