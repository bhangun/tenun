// Public Apache/free-tier API surface for Tenun.
//
// This barrel is intentionally narrower than `tenun.dart`. It exposes the
// core rendering/JSON pipeline and standard chart families. Commercial
// financial, statistical, enterprise, export, large-data, and advanced
// interaction APIs should be consumed from `package:tenun_pro/tenun_pro.dart`.

// Core config exports.
export 'core/base_config.dart';
export 'core/chart_api_contract.dart';
export 'core/chart_api_fields.dart';
export 'core/chart_api_options.dart';
export 'core/chart_api_surface.dart';
export 'core/chart_async_processor.dart';
export 'core/chart_builder.dart';
export 'core/chart_cache.dart';
export 'core/chart_config_validator.dart';
export 'core/chart_controller.dart';
export 'core/chart_data_processor.dart';
export 'core/chart_data_signature.dart';
export 'core/chart_data_value_reader.dart';
export 'core/chart_diagnostic_fallback_fields.dart';
export 'core/chart_error_boundary.dart';
export 'core/chart_formatters.dart';
export 'core/chart_json_option_completion.dart';
export 'core/chart_json_option_completions.dart';
export 'core/chart_json_option_field_reference.dart';
export 'core/chart_json_option_patch_report.dart';
export 'core/chart_json_option_paths.dart';
export 'core/chart_json_option_schemas.dart';
export 'core/chart_json_option_value_hint.dart';
export 'core/chart_model.dart';
export 'core/chart_payload_doctor.dart';
export 'core/chart_payload_normalization_fields.dart';
export 'core/chart_registry.dart';
export 'core/chart_render_pipeline.dart';
export 'core/chart_runtime_diagnostics.dart';
export 'core/chart_runtime_policy_fields.dart';
export 'core/chart_theme.dart';
export 'core/chart_type.dart';
export 'core/chart_viewport_culling.dart';
export 'core/chart_widget_api_contract.dart';
export 'core/data_sampler.dart';
export 'core/data_shape_adapter.dart';
export 'core/grid.dart';
export 'core/label.dart';
export 'core/legend.dart';
export 'core/picture_cache.dart';
export 'core/series.dart';
export 'core/tenun_options.dart';
export 'core/text_style.dart';
export 'core/title.dart';
export 'core/toolbox_feature.dart';
export 'core/tooltip.dart';
export 'core/utils/helper.dart';
export 'core/xyaxis.dart';
export 'core/zoom/chart_zoom_chart_widget.dart';
export 'core/zoom/chart_zoom_state.dart';
export 'core/zoom/chart_zoom_viewport.dart';

// Core registry.
export 'registry/bundle_core.dart';
export 'registry/chart_api_contract_mapping.dart';
export 'registry/chart_family_manifest.dart';
export 'registry/chart_family_showcase_coverage.dart';
export 'registry/registry_tools.dart';

// Shared chart primitives.
export 'charts/common/simple_chart_reference_line.dart';

// Core widgets.
export 'widget/chart_diagnostic_fallback.dart';
export 'widget/chart_diagnostic_fallback_options.dart';
export 'widget/tenun_widget.dart';

// Standard Cartesian charts.
export 'charts/area/area_chart.dart';
export 'charts/area/area_chart_config.dart';
export 'charts/area/simple_area_chart.dart';
export 'charts/bar/bar_chart.dart';
export 'charts/bar/bar_config.dart';
export 'charts/bar/bar_series.dart';
export 'charts/bar/multi_bar.dart';
export 'charts/bar/simple_bar_chart.dart';
export 'charts/bar/simple_stacked_bar_chart.dart';
export 'charts/bar/stacked_bar_chart.dart';
export 'charts/line/line_chart.dart';
export 'charts/line/line_config.dart';
export 'charts/line/line_series.dart';
export 'charts/line/simple_line_chart.dart';
export 'charts/line/simple_sparkline_chart.dart';
export 'charts/line/simple_step_chart.dart';
export 'charts/scatter/scatter_chart.dart';
export 'charts/scatter/scatter_chart_painter.dart';
export 'charts/scatter/scatter_config.dart';
export 'charts/scatter/simple_scatter_chart.dart';

// Standard pie-like charts.
export 'charts/pie/pie_config.dart';
export 'charts/pie/pie_series.dart';
export 'charts/pie/simple_donut_chart.dart';
