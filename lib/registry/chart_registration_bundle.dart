// Tree-shake friendly registration bundles.
//
// Import only the bundle(s) you need in app startup and call `.register()`.
//
// Example:
// ```dart
// void main() {
//   coreChartsBundle.register();
//   advancedChartsBundle.register(); // optional
//   runApp(const MyApp());
// }
// ```

import 'bundle_calendar.dart';
import 'bundle_cartesian.dart';
import 'bundle_common.dart';
import 'bundle_financial.dart';
import 'bundle_flow.dart';
import 'bundle_geo.dart';
import 'bundle_graph.dart';
import 'bundle_hierarchical.dart';
import 'bundle_matrix.dart';
import 'bundle_pie.dart';
import 'bundle_radial.dart';
import 'bundle_business.dart';
import 'bundle_ai_ml.dart';

import '../core/chart_registry.dart';
import '../core/chart_type.dart';
import 'registry_tools.dart';

export 'bundle_calendar.dart';
export 'bundle_cartesian.dart';
export 'bundle_common.dart';
export 'bundle_financial.dart';
export 'bundle_flow.dart';
export 'bundle_geo.dart';
export 'bundle_graph.dart';
export 'bundle_hierarchical.dart';
export 'bundle_matrix.dart';
export 'bundle_pie.dart';
export 'bundle_radial.dart';
export 'bundle_business.dart';
export 'bundle_ai_ml.dart';

// ---------------------------------------------------------------------------
// Convenience Bundles
// ---------------------------------------------------------------------------

/// Standard bundle containing common chart types.
final coreChartsBundle = RegistrationBundle(
  name: 'core',
  description:
      'Common chart types: Bar, Line, Area, Pie, Donut, Scatter, Bubble',
  registrations: [
    barRegistration,
    lineRegistration,
    areaRegistration,
    pieRegistration,
    donutRegistration,
    scatterRegistration,
    bubbleRegistration,
  ],
);

/// Bundle containing all available chart types.
final allChartsBundle = RegistrationBundle(
  name: 'all',
  description: 'All registered chart types',
  registrations: [
    ...cartesianChartsBundle.registrations,
    ...pieChartsBundle.registrations,
    ...radialChartsBundle.registrations,
    ...hierarchicalChartsBundle.registrations,
    ...flowChartsBundle.registrations,
    ...financialChartsBundle.registrations,
    ...matrixChartsBundle.registrations,
    ...calendarChartsBundle.registrations,
    ...geoChartsBundle.registrations,
    ...graphChartsBundle.registrations,
    ...commonChartsBundle.registrations,
    ...businessChartsBundle.registrations,
    ...aiMLChartsBundle.registrations,
  ],
);

// ---------------------------------------------------------------------------
// Shape-based bundling (internal)
// ---------------------------------------------------------------------------

Map<ChartSeriesDataShape, RegistrationBundle> buildShapeBundles() {
  RegistrationBundle make(
    ChartSeriesDataShape shape,
    String name,
    String description,
    Set<ChartType> allowed,
  ) {
    final regs = allChartsBundle.registrations
        .where((r) => allowed.contains(r.type))
        .toList();
    return RegistrationBundle(
      name: name,
      description: '$description (${shape.name})',
      registrations: regs,
    );
  }

  return {
    ChartSeriesDataShape.cartesian: make(
      ChartSeriesDataShape.cartesian,
      'shape_cartesian',
      'Charts for category/time/value series',
      cartesianTypes,
    ),
    ChartSeriesDataShape.pieLike: make(
      ChartSeriesDataShape.pieLike,
      'shape_pie',
      'Charts for label/value slices',
      pieLikeTypes,
    ),
    ChartSeriesDataShape.hierarchical: make(
      ChartSeriesDataShape.hierarchical,
      'shape_hierarchical',
      'Charts for tree/hierarchy data',
      hierarchicalTypes,
    ),
    ChartSeriesDataShape.matrix: make(
      ChartSeriesDataShape.matrix,
      'shape_matrix',
      'Charts for matrix/grid value data',
      matrixTypes,
    ),
    ChartSeriesDataShape.graph: make(
      ChartSeriesDataShape.graph,
      'shape_graph',
      'Charts for node-link graph data',
      graphTypes,
    ),
    ChartSeriesDataShape.flow: make(
      ChartSeriesDataShape.flow,
      'shape_flow',
      'Charts for flow/process data',
      flowTypes,
    ),
    ChartSeriesDataShape.financial: make(
      ChartSeriesDataShape.financial,
      'shape_financial',
      'Charts for OHLC/trading data',
      financialTypes,
    ),
    ChartSeriesDataShape.radial: make(
      ChartSeriesDataShape.radial,
      'shape_radial',
      'Charts for radial/polar metrics',
      radialTypes,
    ),
    ChartSeriesDataShape.calendar: make(
      ChartSeriesDataShape.calendar,
      'shape_calendar',
      'Charts for date-bucketed activity',
      calendarTypes,
    ),
    ChartSeriesDataShape.geospatial: make(
      ChartSeriesDataShape.geospatial,
      'shape_geo',
      'Charts for region/value map data',
      geoTypes,
    ),
  };
}
