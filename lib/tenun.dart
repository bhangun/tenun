// Legacy broad compatibility API surface for Tenun.
//
// New Apache/free-tier consumers should prefer `package:tenun/tenun_core.dart`.
// Commercial chart families should be consumed from `package:tenun_pro`.
// This barrel remains temporarily broad while existing apps and showcase code
// migrate to explicit core/pro entrypoints.

// Core config exports
export 'core/chart_model.dart';
export 'core/chart_type.dart';
export 'core/grid.dart';
export 'core/label.dart';
export 'core/legend.dart';
export 'core/series.dart';
export 'core/text_style.dart';
export 'core/title.dart';
export 'core/tooltip.dart';
export 'core/xyaxis.dart';
export 'core/toolbox_feature.dart';
export 'core/base_config.dart';
export 'core/chart_api_contract.dart';
export 'core/chart_api_fields.dart';
export 'core/chart_api_options.dart';
export 'core/chart_api_surface.dart';
export 'core/chart_widget_api_contract.dart';
export 'core/chart_config_validator.dart';
export 'core/chart_payload_doctor.dart';
export 'core/chart_data_signature.dart';
export 'core/chart_formatters.dart';
export 'core/chart_diagnostic_fallback_fields.dart';
export 'core/chart_json_option_schemas.dart';
export 'core/chart_json_option_field_reference.dart';
export 'core/chart_json_option_completion.dart';
export 'core/chart_json_option_completions.dart';
export 'core/chart_json_option_patch_report.dart';
export 'core/chart_json_option_paths.dart';
export 'core/chart_json_option_value_hint.dart';
export 'core/chart_payload_normalization_fields.dart';
export 'core/chart_runtime_policy_fields.dart';
export 'core/chart_runtime_diagnostics.dart';

// Core utils/system exports
export 'core/utils/helper.dart';
export 'core/chart_registry.dart';
export 'registry/chart_api_contract_mapping.dart';
export 'registry/chart_family_manifest.dart';
export 'registry/chart_family_showcase_coverage.dart';
export 'registry/chart_registration_bundle.dart';
export 'registry/registry_tools.dart';
export 'core/chart_animation_system.dart';
export 'core/chart_async_processor.dart';
export 'core/zoom/chart_drilldown_controller.dart';
export 'core/chart_data_processor.dart';
export 'core/chart_render_pipeline.dart';
export 'core/zoom/chart_zoom_chart_widget.dart';
export 'core/zoom/chart_zoom_state.dart';
export 'core/data_shape_adapter.dart';
export 'core/data_sampler.dart';
export 'core/zoom/chart_zoom_viewport.dart';
export 'core/chart_builder.dart';
export 'core/chart_cache.dart';
export 'core/tenun_options.dart';
export 'core/chart_controller.dart';
export 'core/chart_export.dart';
export 'core/chart_export_archive.dart';
export 'core/chart_export_capability.dart';
export 'core/chart_export_delivery.dart';
export 'core/chart_export_filename.dart';
export 'core/chart_export_format.dart';
export 'core/chart_export_job.dart';
export 'core/chart_export_job_manifest.dart';
export 'core/chart_export_manifest.dart';
export 'core/chart_export_summary.dart';
export 'core/chart_zip_store_writer.dart';
export 'core/chart_sync_group.dart';
export 'core/chart_error_boundary.dart';
export 'core/picture_cache.dart';
export 'core/chart_viewport_culling.dart';

export 'charts/common/simple_chart_reference_line.dart';

// Widget
export 'widget/tenun_widget.dart';
export 'widget/chart_export_controls.dart';
export 'widget/exportable_tenun_chart.dart';
export 'widget/chart_diagnostic_fallback.dart';
export 'widget/chart_diagnostic_fallback_options.dart';

// Area Charts
export 'charts/area/area_chart_config.dart';
export 'charts/area/area_chart.dart';
export 'charts/area/simple_area_chart.dart';
export 'charts/fan/simple_fan_chart.dart';
export 'charts/area/simple_horizon_chart.dart';
export 'charts/spiral/simple_spiral_chart.dart';
export 'charts/area/simple_streamgraph_chart.dart';
export 'charts/area/area_time_axis_chart.dart';
export 'charts/area/large_scale_area_chart.dart';

// Bar Charts
export 'charts/bar/bar_config.dart';
export 'charts/bar/bar_series.dart';
export 'charts/bar/bar_chart.dart';
export 'charts/bar/multi_bar.dart';
export 'charts/bar/simple_bar_chart.dart';
export 'charts/bar/simple_stacked_bar_chart.dart';
export 'charts/bar/stacked_bar_chart.dart';
export 'charts/bar/bar_chart_variants.dart';
export 'charts/bar/rainfall_chart.dart';

// Line Charts
export 'charts/line/line_config.dart';
export 'charts/line/line_series.dart';
export 'charts/line/line_chart.dart';
export 'charts/line/simple_line_chart.dart';
export 'charts/line/simple_sparkline_chart.dart';
export 'charts/line/simple_step_chart.dart';
export 'charts/control/simple_control_chart.dart';
export 'charts/cycle/simple_cycle_plot_chart.dart';
export 'charts/small_multiples/simple_small_multiples_chart.dart';
export 'charts/line/line_area_variants.dart';
export 'charts/line/line_style_item_chart.dart';
export 'charts/line/multi_x_axes_chart.dart';

// Scatter Charts
export 'charts/scatter/scatter_config.dart';
export 'charts/scatter/scatter_chart.dart';
export 'charts/scatter/scatter_chart_painter.dart';
export 'charts/scatter/simple_connected_scatter_chart.dart';
export 'charts/scatter/simple_hexbin_chart.dart';
export 'charts/continuous_heatmap/simple_continuous_heatmap_chart.dart';
export 'charts/scatter_matrix/simple_scatter_plot_matrix_chart.dart';
export 'charts/scatter/simple_scatter_chart.dart';
export 'charts/quadrant/simple_quadrant_chart.dart';
export 'charts/ternary/simple_ternary_chart.dart';
export 'charts/voronoi/simple_voronoi_chart.dart';

// Legacy financial compatibility exports.
//
// Prefer `package:tenun_pro/tenun_pro_financial.dart` for financial/trading
// charts. These exports remain temporarily so existing apps can migrate
// without an immediate source break.
export 'charts/candle/candlestick_data.dart';
export 'charts/candle/candlestick_ohlc_chart.dart';
export 'charts/candle/simple_candlestick_chart.dart';
export 'charts/trading/trading_charts.dart';

// Heatmap Charts
export 'charts/heatmap/heatmap_calendar_parallel_charts.dart';
export 'charts/heatmap/simple_heatmap_chart.dart';
export 'charts/cohort/simple_cohort_retention_chart.dart';
export 'charts/matrix/simple_bubble_matrix_chart.dart';
export 'charts/contour/simple_contour_chart.dart';
export 'charts/correlation/simple_correlation_matrix_chart.dart';
export 'charts/parallel/simple_parallel_coordinates_chart.dart';
export 'charts/punch_card/simple_punch_card_chart.dart';

// Waffle Charts
export 'charts/waffle/simple_waffle_chart.dart';

// Range Charts
export 'charts/range/simple_range_chart.dart';

// Dot Plot Charts
export 'charts/dot_plot/simple_dot_plot_chart.dart';

// Strip Plot Charts
export 'charts/strip/simple_strip_plot_chart.dart';

// Beeswarm Charts
export 'charts/beeswarm/simple_beeswarm_chart.dart';

// Sina Plot Charts
export 'charts/sina/simple_sina_plot_chart.dart';

// Population Pyramid Charts
export 'charts/population_pyramid/simple_population_pyramid_chart.dart';

// Bump Charts
export 'charts/bump/simple_bump_chart.dart';

// Marimekko Charts
export 'charts/marimekko/simple_marimekko_chart.dart';
export 'charts/mosaic/simple_mosaic_plot_chart.dart';

// Pictogram Charts
export 'charts/pictogram/simple_pictogram_chart.dart';
export 'charts/dot_density/simple_dot_density_chart.dart';

// Pie Charts
export 'charts/pie/pie_config.dart';
export 'charts/pie/pie_series.dart';
export 'charts/pie/pie_chart_variants.dart';
export 'charts/pie/simple_donut_chart.dart';
export 'charts/pie/customized_pie_chart.dart';
export 'charts/pie/pie_label_align_chart.dart';
export 'charts/pie/pie_special_label_chart.dart';
export 'charts/rose/simple_rose_chart.dart';

// Other Charts
export 'charts/radar/radar_config.dart';
export 'charts/radar/simple_radar_chart.dart';
export 'charts/radial/simple_radial_bar_chart.dart';
export 'charts/radial/simple_radial_heatmap_chart.dart';
export 'charts/gauge/gauge_config.dart';
export 'charts/gauge/simple_gauge_chart.dart';
export 'charts/funnel/funnel_config.dart';
export 'charts/funnel/simple_funnel_chart.dart';
export 'charts/box_plot/box_plot_chart.dart';
export 'charts/box_plot/simple_box_plot_chart.dart';
export 'charts/boxen/simple_boxen_plot_chart.dart';
export 'charts/bland_altman/simple_bland_altman_chart.dart';
export 'charts/bubble/bubble_config.dart';
export 'charts/bubble/bubble_chart.dart';
export 'charts/bubble/simple_bubble_chart.dart';
export 'charts/likert/simple_likert_chart.dart';
export 'charts/lorenz/simple_lorenz_curve_chart.dart';
export 'charts/packed_bubble/simple_packed_bubble_chart.dart';
export 'charts/qq_plot/simple_qq_plot_chart.dart';
export 'charts/venn/simple_venn_chart.dart';
export 'charts/upset/simple_upset_chart.dart';
export 'charts/bullet/bullet_chart.dart';
export 'charts/bullet/simple_bullet_chart.dart';
export 'charts/choroplet/choropleth_chart.dart';
export 'charts/custom/custom_chart.dart';
export 'charts/error_bar/simple_error_bar_chart.dart';
export 'charts/forest_plot/simple_forest_plot_chart.dart';
export 'charts/alluvial/simple_alluvial_chart.dart';
export 'charts/arc/simple_arc_diagram_chart.dart';
export 'charts/chord/simple_chord_chart.dart';
export 'charts/sankey/sankey.dart';
export 'charts/sankey/simple_sankey_chart.dart';
export 'charts/sunburst/sunburst.dart';
export 'charts/sunburst/simple_sunburst_chart.dart';
export 'charts/waterfall/waterfall_chart.dart';
export 'charts/waterfall/waterfall_config.dart';
export 'charts/waterfall/simple_waterfall_chart.dart';
export 'charts/treemap/treemap_chart.dart';
export 'charts/treemap/treemap.dart';
export 'charts/treemap/simple_treemap_chart.dart';
export 'charts/icicle/simple_icicle_chart.dart';
export 'charts/tree/simple_tree_diagram_chart.dart';
export 'charts/gantt/gantt_chart.dart';
export 'charts/gantt/simple_gantt_chart.dart';
export 'charts/milestone/simple_milestone_chart.dart';
export 'charts/event_strip/simple_event_strip_chart.dart';
export 'charts/polar_bar/polar_bar_chart.dart';
export 'charts/polar_line/polar_line_config.dart';
export 'charts/polar_line/polar_line_chart.dart';
export 'charts/combo/combo_chart.dart';
export 'charts/histogram/histogram_chart.dart';
export 'charts/histogram/simple_histogram_chart.dart';
export 'charts/binned_dot/simple_binned_dot_plot_chart.dart';
export 'charts/frequency_polygon/simple_frequency_polygon_chart.dart';
export 'charts/density/simple_density_chart.dart';
export 'charts/ecdf/simple_ecdf_chart.dart';
export 'charts/barcode/simple_barcode_plot_chart.dart';
export 'charts/raincloud/simple_raincloud_chart.dart';
export 'charts/rug/simple_rug_plot_chart.dart';
export 'charts/lollipop/lollipop_chart.dart';
export 'charts/lollipop/simple_lollipop_chart.dart';
export 'charts/network/network_radial_timeline_wordcloud_charts.dart';
export 'charts/network/simple_network_graph_chart.dart';
export 'charts/wordcloud/simple_word_cloud_chart.dart';
export 'charts/rigeline/ridgeline_strip_error_bar_charts.dart';
export 'charts/rigeline/simple_ridgeline_chart.dart';
export 'charts/sparkline/sparkline_chart.dart';
export 'charts/timeline/simple_timeline_chart.dart';
export 'charts/violin/violin_chart.dart';
export 'charts/violin/simple_violin_chart.dart';
export 'charts/slope/slope_dumbbell_areabump_charts.dart';
export 'charts/slope/simple_slope_chart.dart';
export 'charts/slope/simple_dumbbell_chart.dart';
export 'charts/tornado/simple_tornado_chart.dart';
export 'charts/pararel/pararel_chart.dart';
export 'charts/calendar/calendar_chart.dart';
export 'charts/calendar/simple_calendar_heatmap_chart.dart';
export 'charts/tile_map/simple_tile_map_chart.dart';

// Business Charts
export 'charts/s_curve/s_curve_config.dart';
export 'charts/s_curve/s_curve_chart.dart';
export 'charts/pareto/pareto_config.dart';
export 'charts/pareto/pareto_chart.dart';
export 'charts/pareto/simple_pareto_chart.dart';
export 'charts/indicator/indicator_chart.dart';
export 'registry/bundle_business.dart';

// AI/ML Charts
export 'charts/ai_ml/confusion_matrix_config.dart';
export 'charts/ai_ml/confusion_matrix_chart.dart';
export 'charts/ai_ml/roc_curve_config.dart';
export 'charts/ai_ml/roc_curve_chart.dart';
export 'registry/bundle_ai_ml.dart';
