import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/tenun.dart';
import 'package:tenun/registry/bundle_cartesian.dart' hide lineRegistration, areaRegistration, barRegistration, scatterRegistration;
import 'package:tenun/registry/bundle_financial.dart';
import 'package:tenun/registry/bundle_flow.dart';
import 'package:tenun/registry/bundle_geo.dart';
import 'package:tenun/registry/bundle_radial.dart';
import 'package:tenun/registry/bundle_hierarchical.dart';
import 'package:tenun/registry/bundle_matrix.dart';
import 'package:tenun/registry/bundle_pie.dart';
import 'package:tenun/registry/bundle_calendar.dart';
import 'package:tenun/registry/bundle_graph.dart';
import 'package:tenun/registry/bundle_common.dart';

const _canvasWidth = 480.0;
const _canvasHeight = 320.0;

void main() {
  group('JSON visual smoke fingerprints', () {
    for (final sample in _samples) {
      testWidgets('${sample.name} builds visual render structure', (
        tester,
      ) async {
        await ChartRegistry.withRegistrationsAsync(
          [
            ...allChartsBundle.registrations,
            ...cartesianChartsBundle.registrations,
            ...financialChartsBundle.registrations,
            ...flowChartsBundle.registrations,
            ...geoChartsBundle.registrations,
            ...radialChartsBundle.registrations,
            ...commonChartsBundle.registrations,
            ...hierarchicalChartsBundle.registrations,
            ...matrixChartsBundle.registrations,
            ...pieChartsBundle.registrations,
            ...calendarChartsBundle.registrations,
            ...graphChartsBundle.registrations,
          ],
          clearBefore: true,
          () async {
            final validation = ChartConfigValidator.validateJsonPayload(
              sample.payload,
              deep: true,
            );
            expect(validation.errors, isEmpty, reason: validation.toString());

            final fingerprint = await _captureFingerprint(tester, sample);

            expect(fingerprint.width, _canvasWidth.toInt());
            expect(fingerprint.height, _canvasHeight.toInt());
            expect(
              fingerprint.customPaintCount,
              greaterThanOrEqualTo(sample.minCustomPaintCount),
              reason:
                  '${sample.name} did not build enough paint layers: '
                  '$fingerprint',
            );
            expect(
              fingerprint.repaintBoundaryCount,
              greaterThanOrEqualTo(sample.minRepaintBoundaryCount),
              reason:
                  '${sample.name} did not build expected repaint isolation: '
                  '$fingerprint',
            );
            expect(
              fingerprint.nonZeroRenderBoxCount,
              greaterThanOrEqualTo(sample.minNonZeroRenderBoxCount),
              reason:
                  '${sample.name} rendered too little visual structure: '
                  '$fingerprint',
            );
            if (sample.expectedText case final expectedText?) {
              expect(
                fingerprint.textLabels.any(
                  (label) => label.contains(expectedText),
                ),
                isTrue,
                reason:
                    '${sample.name} did not expose expected text '
                    '"$expectedText": $fingerprint',
              );
            }
            expect(find.textContaining('Invalid chart payload'), findsNothing);
            expect(find.textContaining('Chart render error'), findsNothing);
            expect(tester.takeException(), isNull);
          },
        );
      });
    }
  });
}

Future<_VisualFingerprint> _captureFingerprint(
  WidgetTester tester,
  _VisualSample sample,
) async {
  final boundaryKey = GlobalKey();

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: RepaintBoundary(
            key: boundaryKey,
            child: Container(
              width: _canvasWidth,
              height: _canvasHeight,
              color: Colors.white,
              child: TenunChart(
                jsonConfig: sample.payload,
                width: _canvasWidth,
                height: _canvasHeight,
                validatePayload: true,
                strictValidation: true,
                autoNormalizePayload: true,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 120));
  await tester.pump(const Duration(milliseconds: 120));

  final boundary =
      boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
  final painterTypes = <String>{};
  var customPaintCount = 0;
  var repaintBoundaryCount = 0;
  var nonZeroRenderBoxCount = 0;

  for (final object in tester.allRenderObjects) {
    if (object is RenderBox && object.hasSize && !object.size.isEmpty) {
      nonZeroRenderBoxCount++;
    }
    if (object is RenderCustomPaint) {
      if (object.painter != null || object.foregroundPainter != null) {
        customPaintCount++;
      }
      final painter = object.painter;
      if (painter != null) painterTypes.add(painter.runtimeType.toString());
      final foregroundPainter = object.foregroundPainter;
      if (foregroundPainter != null) {
        painterTypes.add(foregroundPainter.runtimeType.toString());
      }
    }
    if (object is RenderRepaintBoundary &&
        object.hasSize &&
        !object.size.isEmpty) {
      repaintBoundaryCount++;
    }
  }

  final textLabels = tester
      .widgetList<Text>(find.byType(Text))
      .map((widget) => widget.data ?? widget.textSpan?.toPlainText() ?? '')
      .where((label) => label.trim().isNotEmpty)
      .toList(growable: false);

  return _VisualFingerprint(
    width: boundary.size.width.round(),
    height: boundary.size.height.round(),
    customPaintCount: customPaintCount,
    repaintBoundaryCount: repaintBoundaryCount,
    nonZeroRenderBoxCount: nonZeroRenderBoxCount,
    painterTypes: painterTypes.toList(growable: false)..sort(),
    textLabels: textLabels,
  );
}

class _VisualFingerprint {
  final int width;
  final int height;
  final int customPaintCount;
  final int repaintBoundaryCount;
  final int nonZeroRenderBoxCount;
  final List<String> painterTypes;
  final List<String> textLabels;

  const _VisualFingerprint({
    required this.width,
    required this.height,
    required this.customPaintCount,
    required this.repaintBoundaryCount,
    required this.nonZeroRenderBoxCount,
    required this.painterTypes,
    required this.textLabels,
  });

  @override
  String toString() =>
      'VisualFingerprint(width: $width, height: $height, '
      'customPaintCount: $customPaintCount, '
      'repaintBoundaryCount: $repaintBoundaryCount, '
      'nonZeroRenderBoxCount: $nonZeroRenderBoxCount, '
      'painterTypes: $painterTypes, textLabels: $textLabels)';
}

class _VisualSample {
  final String name;
  final Map<String, dynamic> payload;
  final String? expectedText;
  final int minCustomPaintCount;
  final int minRepaintBoundaryCount;
  final int minNonZeroRenderBoxCount;

  const _VisualSample({
    required this.name,
    required this.payload,
    this.expectedText,
    this.minCustomPaintCount = 1,
    this.minRepaintBoundaryCount = 1,
    this.minNonZeroRenderBoxCount = 4,
  });
}

final _samples = <_VisualSample>[
  const _VisualSample(
    name: 'bar cartesian',
    expectedText: 'Bar Visual Smoke',
    minCustomPaintCount: 1,
    minRepaintBoundaryCount: 1,
    minNonZeroRenderBoxCount: 4,
    payload: {
      'type': 'bar',
      'title': {'text': 'Bar Visual Smoke'},
      'xAxis': {
        'data': ['Jan', 'Feb', 'Mar', 'Apr', 'May'],
      },
      'grid': {'show': true},
      'legend': {'show': true},
      'series': [
        {
          'name': 'Revenue',
          'data': [42, 58, 51, 74, 69],
          'color': '#2563EB',
        },
      ],
    },
  ),
  const _VisualSample(
    name: 'line cartesian',
    expectedText: 'Line Visual Smoke',
    payload: {
      'type': 'line',
      'title': {'text': 'Line Visual Smoke'},
      'xAxis': {
        'data': ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'],
      },
      'grid': {'show': true},
      'legend': {'show': true},
      'series': [
        {
          'name': 'Actual',
          'data': [12, 19, 14, 28, 24, 34],
          'color': '#0F766E',
        },
        {
          'name': 'Forecast',
          'data': [10, 16, 20, 22, 30, 32],
          'color': '#F97316',
        },
      ],
    },
  ),
  const _VisualSample(
    name: 'area cartesian',
    expectedText: 'Area Visual Smoke',
    payload: {
      'type': 'area',
      'title': {'text': 'Area Visual Smoke'},
      'xAxis': {
        'data': ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'],
      },
      'grid': {'show': true},
      'legend': {'show': true},
      'areaOpacity': 0.3,
      'gradientArea': true,
      'showDots': true,
      'series': [
        {
          'name': 'North',
          'data': [31, 42, 37, 52, 48, 61],
          'color': '#7C3AED',
        },
        {
          'name': 'South',
          'data': [22, 28, 33, 39, 44, 47],
          'color': '#DC2626',
        },
      ],
    },
  ),
  const _VisualSample(
    name: 'treemap hierarchy',
    expectedText: 'Treemap Visual Smoke',
    payload: {
      'type': 'treemap',
      'title': {'text': 'Treemap Visual Smoke'},
      'series': [
        {
          'data': [
            {
              'name': 'Core',
              'value': 42,
              'children': [
                {'name': 'Product', 'value': 18},
                {'name': 'Platform', 'value': 14},
                {'name': 'Trust', 'value': 10},
              ],
            },
            {'name': 'Growth', 'value': 28},
            {'name': 'Education', 'value': 18},
            {'name': 'Support', 'value': 12},
          ],
        },
      ],
    },
  ),
  const _VisualSample(
    name: 'sunburst hierarchy',
    expectedText: 'Sunburst Visual Smoke',
    payload: {
      'type': 'sunburst',
      'title': {'text': 'Sunburst Visual Smoke'},
      'series': [
        {
          'data': [
            {
              'name': 'Product A',
              'value': 40,
              'children': [
                {'name': 'Online', 'value': 28},
                {'name': 'Offline', 'value': 12},
              ],
            },
            {
              'name': 'Product B',
              'value': 35,
              'children': [
                {'name': 'Online', 'value': 20},
                {'name': 'Offline', 'value': 15},
              ],
            },
            {'name': 'Product C', 'value': 25},
          ],
        },
      ],
    },
  ),
  const _VisualSample(
    name: 'sankey flow',
    expectedText: 'Sankey Visual Smoke',
    payload: {
      'type': 'sankey',
      'title': {'text': 'Sankey Visual Smoke'},
      'series': [
        {
          'nodes': [
            {'id': 'visits', 'name': 'Visits', 'column': 0},
            {'id': 'product', 'name': 'Product', 'column': 1},
            {'id': 'checkout', 'name': 'Checkout', 'column': 2},
            {'id': 'purchase', 'name': 'Purchase', 'column': 2},
          ],
          'links': [
            {'source': 'visits', 'target': 'product', 'value': 5000},
            {'source': 'product', 'target': 'checkout', 'value': 4200},
            {'source': 'checkout', 'target': 'purchase', 'value': 3800},
            {'source': 'product', 'target': 'purchase', 'value': 1200},
          ],
        },
      ],
    },
  ),
  const _VisualSample(
    name: 'heatmap matrix',
    expectedText: 'Heatmap Visual Smoke',
    payload: {
      'type': 'heatmap',
      'title': {'text': 'Heatmap Visual Smoke'},
      'xLabels': ['Mon', 'Tue', 'Wed', 'Thu'],
      'yLabels': ['Morning', 'Afternoon', 'Evening'],
      'series': [
        {
          'data': [
            [12, 18, 9, 15],
            [8, 14, 20, 11],
            [5, 10, 16, 22],
          ],
        },
      ],
      'lowColor': '#DBEAFE',
      'highColor': '#1D4ED8',
      'showValues': true,
    },
  ),
  const _VisualSample(
    name: 'candlestick financial',
    expectedText: 'Candlestick Visual Smoke',
    payload: {
      'type': 'candlestick',
      'title': {'text': 'Candlestick Visual Smoke'},
      'xAxis': {
        'data': ['D1', 'D2', 'D3', 'D4', 'D5'],
      },
      'series': [
        {
          'data': [
            [100, 110, 95, 108],
            [108, 114, 104, 112],
            [112, 118, 109, 115],
            [115, 120, 111, 113],
            [113, 124, 112, 121],
          ],
        },
      ],
    },
  ),
  const _VisualSample(
    name: 'renko trading',
    expectedText: 'Renko Visual Smoke',
    payload: {
      'type': 'renko',
      'title': {'text': 'Renko Visual Smoke'},
      'brickSize': 2,
      'series': [
        {
          'data': [100, 101, 104, 108, 106, 103, 109, 113, 118],
        },
      ],
    },
  ),
];
