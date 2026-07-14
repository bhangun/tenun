// Apache/free-tier registration bundle facade.
//
// Pro chart registrations are owned by `package:tenun_pro`. This file keeps
// the historical `allChartsBundle` and common registration names available for
// basic/core consumers, but maps them only to the Apache core chart family.

import 'package:tenun_core/core/chart_registry.dart';
import 'package:tenun_core/core/chart_type.dart';
import 'package:tenun_core/registry/registry_tools_core.dart';
import 'bundle_calendar.dart';
import 'bundle_cartesian.dart';
import 'bundle_core.dart' as core;
import 'bundle_financial.dart';
import 'bundle_flow.dart';
import 'bundle_geo.dart';
import 'bundle_graph.dart';
import 'bundle_hierarchical.dart';
import 'bundle_matrix.dart';
import 'bundle_pie.dart';
import 'bundle_radial.dart';

/// Basic/core bar chart registration.
final barRegistration = core.coreBarRegistration;

/// Basic/core line chart registration.
final lineRegistration = core.coreLineRegistration;

/// Basic/core area chart registration.
final areaRegistration = core.coreAreaRegistration;

/// Basic/core pie chart registration.
final pieRegistration = core.corePieRegistration;

/// Basic/core donut chart registration.
final donutRegistration = core.coreDonutRegistration;

/// Basic/core scatter chart registration.
final scatterRegistration = core.coreScatterRegistration;

/// All chart registrations available from the Apache/free-tier package.
final allChartsBundle = RegistrationBundle(
  name: 'all_core',
  description: 'All Apache/free-tier chart types',
  registrations: core.coreChartsBundle.registrations,
);

/// Shape-based bundling for Apache/free-tier chart registrations.
Map<ChartSeriesDataShape, RegistrationBundle> buildShapeBundles() {
  RegistrationBundle make(
    ChartSeriesDataShape shape,
    String name,
    String description,
    Set<ChartType> allowed,
  ) {
    final regs = allChartsBundle.registrations
        .where((registration) => allowed.contains(registration.type))
        .toList(growable: false);

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
      'Core charts for category/time/value series',
      cartesianTypes,
    ),
    ChartSeriesDataShape.pieLike: make(
      ChartSeriesDataShape.pieLike,
      'shape_pie',
      'Core charts for label/value slices',
      pieLikeTypes,
    ),
    ChartSeriesDataShape.hierarchical: make(
      ChartSeriesDataShape.hierarchical,
      'shape_hierarchical',
      'Pro charts for tree/hierarchy data',
      hierarchicalTypes,
    ),
    ChartSeriesDataShape.matrix: make(
      ChartSeriesDataShape.matrix,
      'shape_matrix',
      'Pro charts for matrix/grid value data',
      matrixTypes,
    ),
    ChartSeriesDataShape.graph: make(
      ChartSeriesDataShape.graph,
      'shape_graph',
      'Pro charts for node-link graph data',
      graphTypes,
    ),
    ChartSeriesDataShape.flow: make(
      ChartSeriesDataShape.flow,
      'shape_flow',
      'Pro charts for flow/process data',
      flowTypes,
    ),
    ChartSeriesDataShape.financial: make(
      ChartSeriesDataShape.financial,
      'shape_financial',
      'Pro charts for OHLC/trading data',
      financialTypes,
    ),
    ChartSeriesDataShape.radial: make(
      ChartSeriesDataShape.radial,
      'shape_radial',
      'Pro charts for radial/polar metrics',
      radialTypes,
    ),
    ChartSeriesDataShape.calendar: make(
      ChartSeriesDataShape.calendar,
      'shape_calendar',
      'Pro charts for date-bucketed activity',
      calendarTypes,
    ),
    ChartSeriesDataShape.geospatial: make(
      ChartSeriesDataShape.geospatial,
      'shape_geo',
      'Pro charts for region/value map data',
      geoTypes,
    ),
  };
}
