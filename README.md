# 📊 Tenun - Enterprise-Grade Flutter Charting Library

> **Declarative, tree-shakeable, JSON-driven, and built for massive datasets with hardware-accelerated rendering.**

Tenun is a production-ready Flutter charting package that delivers **60+ chart types**, seamless **JSON configuration**, zoom/pan/fling state machines, drill-down hierarchies, cross-chart synchronization, and zero-allocation rendering pipelines. Designed for dashboards, financial apps, and data-heavy enterprise UIs.

---

## Package Split Note

Use `package:tenun/tenun_core.dart` for the Apache/free-tier charting surface.
The broader `package:tenun/tenun.dart` barrel is a temporary compatibility
surface while existing apps migrate. Commercial financial, enterprise,
advanced statistical, hierarchy/flow, and AI/ML chart families should be
consumed from `package:tenun_pro`.

---

## 🚀 Features

| Category | Highlights |
|----------|------------|
| **📦 Tree-Shakeable** | Register only the charts you use. Unused types are stripped at compile time. |
| **🔄 JSON-Driven API** | Single unified `option` object. Switch `bar ↔ line ↔ pie` without rewriting data. |
| **⚡ Hardware-Accelerated** | Layered `ChartRenderPipeline`, `ui.Picture` caching, LRU eviction, viewport culling. |
| **📈 Live Interactions** | Pinch-zoom, pan, fling momentum, scroll-wheel, double-tap, crosshair, long-press. |
| **🎯 Drill-Down & Sync** | Hierarchical drill-down state machine. Synchronize zoom/pan across multiple charts. |
| **🎨 Theming & A11y** | Light/Dark/HighContrast themes, RTL support, `Semantics` wrappers, scalable text. |
| **📤 Export & Validation** | CSV/XLSX/PNG/JPEG/SVG export. Strict JSON payload validation with auto-fix suggestions. |
| **📊 60+ Chart Types** | Cartesian, Pie/Radial, Financial, Statistical, Hierarchical, Geo, Flow, Misc. |
---

## 📦 Installation

```yaml
# pubspec.yaml
dependencies:
  tenun: ^0.1.0
```

Run:
```bash
flutter pub get
```

---

## ⚡ Quick Start

### 1. Register Bundles (Tree-Shakeable)
```dart


void main() {
  // Register only the chart families you need.
  coreChartsBundle.register();      // bar, line, area, pie, scatter, etc.
  
  runApp(const MyApp());
}
```

### 2. Basic Usage
```dart


TenunChart(
  jsonConfig: {
    "type": "bar",
    "title": {"text": "Monthly Revenue", "fontSize": 16},
    "xAxis": {"data": ["Jan", "Feb", "Mar", "Apr"]},
    "series": [
      {"name": "Sales", "data": [120, 150, 135, 170], "color": "#42A5F5"}
    ]
  },
  width: 400,
  height: 300,
)
```

---

## 🧱 Architecture & Core Concepts

| Component | Purpose |
|-----------|---------|
| `BaseChartConfig` | Immutable configuration object. All concrete configs extend this. |
| `ChartRegistry` | Maps JSON `type` strings → config factories. Enables tree-shaking. |
| `ChartRenderPipeline` | Composable layer stack (`Background → Grid → Data → Labels → Tooltip`). |
| `ChartPainterBase` | Zero-allocation painter with `Viewport`, `PaintCache`, `TextPainterCache`. |
| `ChartController` | Programmatic control: zoom, selection, data version bump, export triggers. |
| `ChartZoomController` | Manages pinch/pan/fling state, history stack, and drill-down sync. |
| `LargeDataSamplingConfig` | Global LTTB/MinMax/Nth sampling policies for >1k point datasets. |

---

## 📘 API Reference & Usage

### 📐 Widget API
| Widget | Use Case |
|--------|----------|
| `TenunChart` | Basic config or JSON-driven rendering. |
| `TenunChartFromJson` | Shorthand for JSON-only rendering with validation. |
| `TenunChartJson` | JSON option widget with safe forced type switching and non-throwing fallback. |
| `ZoomableTenunChart` | Production-ready: includes pinch, pan, minimap, reset button. |
| `DrillDownChartView` | Hierarchical drill-down with breadcrumbs & back navigation. |
| `ExportableChart` | Wraps any chart with a managed `GlobalKey` for PNG/JPEG capture. |
| `ChartExportControls` | Reusable Material toolbar for CSV/XLSX/PNG/JPEG export buttons, with optional ZIP bundle export. |
| `ExportableTenunChart` | Turnkey chart + export controls for config or JSON payloads. |

`TenunChartJson` defaults to safe JSON building. Use `onBuildResult` for payload/build diagnostics, `onSwitchResult` to surface blocked or warning-producing `forceType` switches, `errorBuilder` for invalid payload UI, and `switchErrorBuilder` for custom blocked-switch UI in editors, previews, and runtime chart switchers.

### 🔄 JSON Configuration 
Tenun uses a unified JSON schema. All optional fields are documented below.

```json
{
  "type": "bar",
  "title": { "text": "Q1 Performance", "fontSize": 18, "color": "#1A1A1A" },
  "tooltip": { "show": true, "formatter": "{a}: {c}", "precision": 2 },
  "legend": { "show": true, "orient": "horizontal", "textColor": "#666" },
  "grid": { "show": true, "horizontalColor": "#E0E0E0", "verticalWidth": 0.5 },
  "xAxis": { "data": ["A", "B", "C"], "fontSize": 11 },
  "yAxis": { "name": "Value", "nameSize": 12, "precision": 1 },
  "series": [
    { "name": "Revenue", "data": [100, 200, 150], "color": "#2196F3" }
  ],
  "theme": { "mode": "dark", "palette": ["#FF1744", "#00E676", "#2979FF"] },
  "sampling": { "enabled": true, "threshold": 800, "strategy": "lttb" }
}
```

`type` lookup is forgiving for JSON payloads: registered keys and aliases are
matched case-insensitively, and common separators are normalized. For example,
`"line-area"`, `"line_area"`, and `"line area"` resolve to the same registered
chart type. If a type is not registered, `UnregisteredChartTypeException`
includes nearby suggestions when possible.

#### 🔀 Seamless Chart Switching
Change `"type"` in JSON at runtime. Tenun automatically reshapes data between compatible families (`cartesian ↔ pieLike ↔ financial`).

```dart
// Switch bar → line without touching series data
setState(() => jsonConfig['type'] = 'line');
```

For safer runtime switching driven by payload shape:

```dart
import 'package:tenun/registry/registry_tools.dart';

final ranked = rankedCompatibleChartTypesForJson(
  jsonConfig,
  preferredOrder: const [ChartType.line, ChartType.area, ChartType.groupedBar],
);

final check = chartSwitchCompatibilityForJson(
  jsonConfig,
  targetType: ChartType.treemap,
);
if (check.canSwitch && (check.isCompatible || check.requiresForce)) {
  // Show check.reason in UI before switching.
}

final switched = switchChartTypeForSeriesShapeAuto(
  jsonConfig,
  preferredOrder: const [ChartType.line, ChartType.area, ChartType.groupedBar],
);
```

- `rankedCompatibleChartTypesForJson(...)`: returns compatible alternatives in priority order.
- `chartSwitchCompatibilityForJson(...)`: checks a manual target without throwing and explains direct vs force-conversion switching.
- `switchChartTypeForSeriesShapeAuto(...)`: picks the first compatible target and rewrites payload safely.
- `DataShapeAdapter.adapt(...)` remains available as a compatibility facade and now uses the same registry-backed inference as validator/tooling.
- Financial switching extracts close prices for cartesian targets and can synthesize OHLC tuples when switching line/bar data to `candlestick` or `ohlc`.
- `TenunOption.fromJson(json).switchType(type).build()` is the high-level option API when you want to preserve global config (`title`, `tooltip`, `legend`, `grid`) while switching types.
- `TenunOption.fromJson(json).tryBuild()` validates and resolves configs without throwing, which is safer for JSON editors, previews, and developer tooling.

#### 🏁 Bar Race Markers, Images & Controls
`barRace` is frame-driven, so it does not require `series`. You can provide
classic frame objects or shorthand `categories + frames` arrays.

```json
{
  "type": "barRace",
  "title": { "text": "Top Products" },
  "categories": ["A", "B", "C"],
  "frameLabels": ["2024", "2025", "2026"],
  "frames": [
    [120, 80, 65],
    [140, 95, 70],
    [160, 110, 77]
  ],
  "markers": {
    "A": { "text": "A", "backgroundColor": "#E6F4FF", "size": 28 },
    "B": { "imageAsset": "assets/logos/product_b.png" },
    "C": { "imageUrl": "https://example.com/product-c.png" }
  },
  "autoPlay": false,
  "loop": true,
  "showControls": true,
  "showStepControls": true,
  "showProgressIndicator": true,
  "showFrameLabel": true,
  "frameDuration": 1200,
  "maxBars": 10
}
```

Classic frame objects are also accepted:

```json
{
  "type": "barRace",
  "frames": [
    { "label": "2024", "values": { "A": 120, "B": 80 } },
    { "label": "2025", "values": { "A": 140, "B": 95 } }
  ],
  "icons": { "A": "A", "B": "B" },
  "images": { "C": "assets/logos/product_c.png" }
}
```

Direct config usage is available when you do not need JSON:

```dart
TenunChart(
  config: BarRaceChartConfig(
    title: TitlesData(text: 'Top Products'),
    frames: const [
      BarRaceFrame(label: '2024', values: {'A': 120, 'B': 80}),
      BarRaceFrame(label: '2025', values: {'A': 140, 'B': 95}),
    ],
    markers: const {
      'A': BarRaceMarkerStyle(text: 'A', backgroundColor: '#E6F4FF'),
      'B': BarRaceMarkerStyle(imageAsset: 'assets/logos/product_b.png'),
    },
    autoPlay: false,
    showControls: true,
    showStepControls: true,
  ),
)
```

Marker image loading is optional and decorative. If an asset/network image
fails, Tenun falls back to the marker text or the first character of the bar
label. Asset images still need to be declared in your app `pubspec.yaml`.

### 🎮 Programmatic Control
```dart
final chartCtrl = ChartController();
final zoomCtrl = ChartZoomController();

TenunChart(
  config: myConfig.withController(chartCtrl),
  // ...
)

// Programmatic actions
chartCtrl.zoomTo(start: 0, end: 25);          // Zoom to index range
chartCtrl.selectIndex(5, seriesIndex: 0);     // Highlight data point
chartCtrl.highlightSeries(1);                 // Emphasize series
chartCtrl.incrementDataVersion();             // Trigger re-render after data push
chartCtrl.requestExport();                    // Fire export pipeline
```

### 🔍 Zoom, Pan & Interactions
```dart
ZoomableTenunChart(
  config: myConfig,
  zoomConstraints: const ZoomConstraints(
    enablePinchZoom: true,
    enableFling: true,
    flingFriction: 0.88,
    minWindowFraction: 0.02, // Max zoom: 2% of data visible
    maxWindowFraction: 1.0,  // Max zoomed-out window
  ),
  showMinimap: true,
  showResetButton: true,
  onTap: (fraction, zoomCtrl) {
    print('Tapped at ${fraction * 100}% of dataset');
  },
)
```
- Zoom ranges are normalized defensively: reversed ranges are swapped, non-finite gesture inputs are ignored, and min/max window constraints are enforced.

### 📂 Drill-Down & Cross-Chart Sync
```dart
// 1. Define root level
final rootLevel = DrillDownLevel(
  id: 'year',
  label: 'Annual Sales',
  config: yearlyConfig,
);

// 2. Initialize controller
final drillCtrl = ChartDrillDownController(root: rootLevel);

// 3. Render
DrillDownChartView(
  controller: drillCtrl,
  builder: (config) => TenunChart(config: config),
)

// 4. Push drill-down on tap
drillCtrl.push(DrillDownLevel(
  id: 'q1_2024',
  label: 'Q1 2024',
  config: quarterlyConfig,
));

// Cross-Chart Sync (Dashboard)
final syncGroup = ChartControllerGroup();
syncGroup.add(chartCtrlA);
syncGroup.add(chartCtrlB);
// Zooming A now automatically zooms B
```

### 🎨 Theming & Accessibility
```dart
final theme = ChartTheme.dark.copyWith(
  palette: ChartPalette.ocean,
  typography: const ChartTypography(titleSize: 18, axisLabelSize: 12),
);

TenunChart(
  config: myConfig.withTheme(theme),
  // Accessibility is auto-enabled via ChartInteractionLayer & Semantics wrappers
)
```

### 📈 Large Datasets & Performance
```dart
// Global sampling policy (apply at app startup)
LargeDataSamplingConfig.enabled = true;
LargeDataSamplingConfig.threshold = 1200; // Auto-sample above 1200 pts
LargeDataSamplingConfig.mode = ChartDataMode.auto; // or .large / .regular
```
- Data processing cache is enabled for larger series by default and skips
  simple charts unless explicitly forced:
```dart
ChartDataProcessor.configureProcessingCache(
  enabled: true,
  maxEntries: 32,
  minPointCount: 1000,
);

final processed = ChartDataProcessor.process(
  config.series,
  renderThreshold: 500,
  // Optional viewport culling. Both bounds are inclusive.
  startIndex: 100,
  endIndex: 400,
);

debugPrint(ChartDataProcessor.processingCacheStats.toJson().toString());
```
- `renderThreshold` is clamped to a safe minimum internally, so invalid values
  from dynamic controls cannot break sampling.
- Heavy preprocessing can be moved off the UI thread with point-count based
  isolate offloading:
```dart
AsyncChartProcessorConfig.isolatePointThreshold = 10000;

final processed = await AsyncChartProcessor.processAsync(
  config.series,
  renderThreshold: 500,
  onReport: (report) {
    debugPrint(report.toJson().toString());
  },
);
```
- Widget-level runtime diagnostics are available without extra processing:
```dart
TenunChartFromJson(
  jsonConfig: myJson,
  onRuntimeDiagnostics: (diagnostics) {
    debugPrint(diagnostics.toJson().toString());
  },
);
```
- **< 5k points**: LTTB (visually accurate)
- **5k–50k points**: MinMax (preserves peaks/valleys)
- **> 50k points**: Nth-Point (fastest, uniform decimation)
- For `candlestick` / `ohlc`, you can pass object rows or tuples:
  - `[open, high, low, close, volume?]`
  - `[date, open, high, low, close, volume?]`
- Viewport culling + `ui.Picture` cache ensures **60 FPS** even with 100k+ points.

### 🛡️ Validation & Export
```dart
// Validate JSON before rendering
final result = ChartConfigValidator.validateJsonPayload(myJson, deep: true);
if (!result.isValid) {
  debugPrint(result.errors.map((e) => e.message).join('\n'));
}

// Reusable normalization policy for direct options, widgets, and factories.
const normalizationOptions = PayloadNormalizationOptions(
  dropUnsupportedSampling: true,
  sanitizeTradingPayload: true,
  defaultThreshold: 1200,
);

// Direct option usage with non-throwing build diagnostics.
final optionResult = TenunOption.fromJson(
  myJson,
  autoNormalizePayload: true, // derives series from shorthand collections
  normalizationOptions: normalizationOptions,
).tryBuild();
if (optionResult.isRenderSafe) {
  final config = optionResult.config!;
  // Render with TenunChart(config: config)
} else {
  debugPrint(optionResult.message);
  debugPrint(optionResult.validation.toReport().compactMessage);
}
// TenunOption preserves chart-specific top-level fields such as `nodes`,
// `showLabels`, `frameDuration`, and trading parameters in toRenderJson().

// Optional: validator also checks dataMode/sampling fields when present:
// - mistyped chart types include nearby registered type suggestions when possible
// - dataMode: regular | auto | large
// - sampling.enabled: bool
// - sampling.threshold: > 0
// - sampling.strategy: auto | lttb | minMax | nth
// - warns if sampling is set on chart types that likely ignore sampling
// - for candlestick/ohlc: validates tuple/object OHLC shape, numeric values,
//   and invalid ranges (high < low)
// - for kagi/renko/macd: validates numeric price rows and positive chart
//   params (reversalPct, brickSize, fast/slow/signal)
// - for barRace: validates frames, shorthand categories, markers/images,
//   controls, frameDuration, and maxBars
// - deep validation supports external-data charts (treemap/sankey/funnel/etc.)
//   without false EMPTY_SERIES errors

// Optional auto-fix normalization (before validate/render)
// - sampling/dataMode normalization
// - trading payload sanitation (kagi/renko/macd)
final normalized = ChartConfigValidator.normalizePayload(
  myJson,
  options: normalizationOptions,
);
final diffs = ChartConfigValidator.diffPayloads(myJson, normalized);
for (final diff in diffs) {
  debugPrint('${diff.kind.name} ${diff.path}: '
      '${diff.rawText} -> ${diff.normalizedText}');
}

final report = ChartConfigValidator.normalizePayloadWithReport(
  myJson,
  options: normalizationOptions,
);
debugPrint(report.summary.compactLabel);
debugPrint('Changed paths: ${report.changedPaths.join(', ')}');
final diagnostics = {
  'validation': result.toJson(),
  'normalization': report.toJson(), // summaries + paths, no full payloads
};

// Widget-level auto-normalization (optional)
TenunChartFromJson(
  jsonConfig: myJson,
  validatePayload: true,
  strictValidation: true,
  autoNormalizePayload: true,
  normalizationOptions: normalizationOptions,
  onPayloadNormalizationResult: (report) {
    debugPrint('Rendering ${report.normalizedPayload["type"]} '
        'with ${report.summary.compactLabel}');
  },
);
// Widget callbacks are dispatched after the frame and deduped for identical
// payload/result signatures, so they are safe for setState/logging.

// Safe option widget usage has the same normalization contract.
TenunChartJson(
  jsonConfig: myJson,
  autoNormalizePayload: true,
  normalizationOptions: normalizationOptions,
  onBuildResult: (result) => debugPrint(result.message),
);

// Optional render safety net for malformed/unregistered chart payloads.
TenunChartFromJson(
  jsonConfig: myJson,
  catchRenderErrors: true,
  onRenderError: (error, stackTrace) {
    debugPrint('Chart failed: $error');
  },
  renderErrorBuilder: (context, error, stackTrace) {
    return Text('Unable to render chart: $error');
  },
);

// Export to PNG/JPEG/CSV/XLSX
final pngBytes = await ChartExporter.toPng(exportKey, pixelRatio: 3.0);
final jpegBytes = await ChartExporter.toJpeg(exportKey, pixelRatio: 3.0);
final csvString = ChartExporter.toCsv(myConfig, delimiter: ',');
final xlsxBytes = ChartExporter.toXlsx(myConfig, sheetName: 'Monthly Metrics');
```

---

## 📊 Supported Chart Types

| Family | Types |
|--------|-------|
| **Standard (Cartesian)** | `bar`, `line`, `area`, `scatter`, `bubble`, `combo`, `waterfall`, `histogram`, `lollipop`, `stepLine`, `rainfall` |
| **Business & Project** | `sCurve`, `pareto`, `indicator` (KPI Tile), `gantt`, `timeline`, `bullet` |
| **AI / ML & Statistical** | `confusionMatrix`, `rocCurve`, `boxPlot`, `violin`, `ridgeline`, `errorBar`, `strip` |
| **Circular & Radial** | `pie`, `donut`, `nightingale`, `sunburst`, `radar`, `gauge`, `polarBar`, `polarLine` |
| **Hierarchical & Flow** | `treemap`, `sankey`, `network`, `chord` |
| **Financial & Trading** | `candlestick`, `ohlc`, `kagi`, `renko`, `macd` are commercial Pro charts in `tenun_pro` |
| **Specialized & Misc** | `heatmap`, `calendar`, `wordcloud`, `parallel`, `sparkline`, `custom` |
| **Variants (v3)** | `barRace`, `barGradient`, `barRounded`, `lineConfidenceBand`, `lineMarkline`, `logAxis`, `functionPlot`, `dynamicTimeSeries`, `largeScaleArea`, `areaTimeAxis`, `customizedPie`, `pieLabelAlign`, `pieSpecialLabel` |


## 🚀 Quick Start

### 1. Register Chart Bundles
Register only the chart types you need. Unregistered types are tree-shaken at compile time.

```dart
void main() {
  // Core: bar, line, area, pie, scatter, donut
  coreChartsBundle.register();
  
  // Optional: sankey, treemap, gantt, sunburst
  // advancedChartsBundle.register();
  
  runApp(const MyApp());
}
```


---

## 🌳 Tree-Shaking & Bundle Guide

Tenun ships as modular bundles. Only register what you need:

```dart
void main() {
  // Cartesian: bar, line, area, pie, scatter, donut, combo, gauge, radar, funnel
  cartesianChartsBundle.register();
  
  // Financial: Candlestick, OHLC, Kagi, Renko, MACD.
  // Use package:tenun_pro/tenun_pro_financial.dart:
  // registerTenunProFinancialCharts(includeCore: true);
  
  // Hierarchical: Treemap, Sunburst
  hierarchicalChartsBundle.register();
  
  // Calendar: Calendar, Calendar Pie.
  calendarChartsBundle.register();

  // Sparkline, Parallel, Wordcloud, Custom, Violin, BoxPlot
  commonChartsBundle.register();

  // Flow: Sankey, Funnel, Waterfall, Timeline, Gantt
  flowChartsBundle.register();

  // Geo: Choropleth Map
  geoChartsBundle.register();

  // Matrix: Heatmap, Sparkline Matrix
  matrixChartsBundle.register();

  // Pie: Pie, Donut, and variants
  pieChartsBundle.register();

  // Radial: Gauge, Radar, PolarBar, Radial, Bullet
  radialChartsBundle.register();


  
  runApp(const MyApp());
}
```
*Unused bundles are completely stripped by the Dart compiler, keeping APK/IPA size minimal.*

---

### 2. Basic Usage
```dart
TenunChart(
  jsonConfig: {
    "type": "bar",
    "title": {"text": "Monthly Sales"},
    "series": [{"name": "Revenue", "data": [120, 180, 150, 210]}]
  },
  width: 300,
  height: 200,
)
```

---

## ⚙️ Configuration API

Tenun supports both **JSON-driven**  and **programmatic** configurations.

### JSON Schema
```json
{
  "type": "line",
  "sampling": {"enabled": true, "threshold": 800, "strategy": "lttb"},
  "theme": {"mode": "dark"},
  "xAxis": {"data": ["Jan", "Feb", "Mar"]},
  "series": [
    {"name": "Growth", "data": [120, 135, 150], "color": "#42A5F5"}
  ]
}
```

### Programmatic Config
```dart
TenunChart(
  config: LineChartConfig(
    series: [Series(name: "Growth", data: [120, 135, 150])],
    theme: ChartTheme.dark,
    sampling: SamplingConfig(threshold: 800),
  ),
)
```

### Validation
Always validate payloads in production to catch malformed JSON early.
```dart
final result = ChartConfigValidator.validateJsonPayload(json, deep: true);
if (!result.isValid) {
  debugPrint(result.errors.map((e) => e.message).join('\n'));
}
```

---

## 🖱 Interactions & Zoom

Wrap your chart in `ZoomableTenunChart` to enable pinch, pan, fling, and scroll-wheel zoom.

```dart
ZoomableTenunChart(
  config: myConfig,
  zoomConstraints: ZoomConstraints(
    enablePinchZoom: true,
    enableFling: true,
    flingFriction: 0.88,
    minWindowFraction: 0.02, // Max zoom: 2% visible
  ),
  showMinimap: true,
  showResetButton: true,
  onTap: (frac, zoom) => print('Tapped at ${frac * 100}%'),
)
```

### Programmatic Control
```dart
final ctrl = ChartController();
// Later in your widget:
ctrl.selectIndex(5);
ctrl.zoomTo(start: 10, end: 50);
ctrl.incrementDataVersion(); // Triggers re-process after live data push
```

---

## 📊 Drill-Down Navigation

Implement hierarchical navigation (e.g., Annual → Quarterly → Monthly) with breadcrumbs and back navigation.

```dart
final drill = ChartDrillDownController(
  root: DrillDownLevel(
    id: 'year',
    label: 'Annual Sales',
    config: yearlyConfig,
  ),
);

DrillDownChartView(
  controller: drill,
  builder: (config) => TenunChart(config: config),
  showBreadcrumbs: true,
)

// Push deeper level on tap:
drill.push(DrillDownLevel(
  id: 'q1_2024',
  label: 'Q1 2024',
  config: quarterlyConfig,
));
```

---

## 🚀 Performance & Large Datasets

Tenun automatically samples datasets exceeding the threshold. Configure strategies globally or per-chart.

```dart
// Global config (call in main())
LargeDataSamplingConfig.enabled = true;
LargeDataSamplingConfig.threshold = 1200; // Auto-sample above 1200 pts
LargeDataSamplingConfig.strategy = SamplingStrategy.lttb; // Best visual accuracy
```

**Strategies:**
- `lttb`: Largest-Triangle-Three-Buckets (≤5k pts). Preserves peaks/valleys.
- `minMax`: Keeps local min/max per bucket (5k–50k pts).
- `nth`: Fastest uniform decimation (>50k pts).

---

## 🎨 Theming

Apply built-in themes or customize tokens.

```dart
TenunChart(
  config: myConfig.withTheme(ChartTheme.dark),
  // or
  config: myConfig.withTheme(
    ChartTheme.light.copyWith(
      palette: ChartPalette.ocean,
      typography: ChartTypography(titleSize: 18),
    ),
  ),
)
```

---

## 📤 Exporting

Export charts to CSV, XLSX, PNG, JPEG, or SVG.

```dart
// PNG/JPEG via GlobalKey
final _exportKey = GlobalKey();
RepaintBoundary(key: _exportKey, child: TenunChart(config: myConfig));

final png = await ChartExporter.toPng(_exportKey, pixelRatio: 2.0);
final jpeg = await ChartExporter.toJpeg(_exportKey, pixelRatio: 2.0);

// CSV/XLSX
final csv = ChartExporter.toCsv(myConfig, delimiter: ',');
final xlsx = ChartExporter.toXlsx(myConfig, sheetName: 'Chart Data');

// Request-based exports validate unsafe options early:
// - CSV delimiter must not be empty.
// - PNG/JPEG pixelRatio must be finite and greater than zero.

// Unified request/result API
final cancelToken = ChartExportCancellationToken();
final result = await ChartExporter.export(
  ChartExportRequest.xlsx(
    config: myConfig,
    categoryLabels: ['Jan', 'Feb', 'Mar'],
    filename: 'monthly_report',
    timeout: const Duration(seconds: 10),
    cancellationToken: cancelToken, // call cancelToken.cancel(...) from UI
  ),
);
if (result.success) {
  debugPrint('${result.filename}: ${result.sizeBytes} bytes');
  final payload = result.payloadBytes; // bytes for save/share APIs
  final dataUri = result.dataUri; // useful for web download previews
  final contentDisposition = result.contentDisposition();
  final durationMicros = result.duration?.inMicroseconds;
  debugPrint(result.preview());
  debugPrint(result.toMetadataJson().toString());
}

// Filenames are sanitized for delivery safety. You can preview the policy too.
final safeName = ChartExportFilename.withExtension(
  '../Finance/Q2:Report?.csv',
  'csv',
);

// Batch export multiple formats from the same chart payload.
final batch = await ChartExporter.exportFormats(
  formats: const [ChartExportFormat.csv, ChartExportFormat.xlsx],
  config: myConfig,
  categoryLabels: ['Jan', 'Feb', 'Mar'],
  filename: 'monthly_report',
  batchOptions: ChartExportBatchOptions(
    skipUnavailable: true,
    stopOnFirstFailure: true,
    continueOnProgressError: true,
    onProgress: (progress) {
      debugPrint('Exported ${progress.completed}/${progress.total}');
    },
    onProgressError: (error, stackTrace, progress) {
      debugPrint('Export progress observer failed at ${progress.completed}');
    },
  ),
);
if (batch.hasFailures) {
  debugPrint(batch.failed.map((item) => item.preview()).join('\n'));
}
if (batch.hasIssues) {
  debugPrint(batch.primaryIssue ?? batch.issueMessages.join('\n'));
}
debugPrint(batch.toMetadataJson().toString());
debugPrint(batch.summaryText());
if (!batch.hasOutput) debugPrint('No export files were produced.');
debugPrint('Skipped unavailable formats: ${batch.skippedUnavailableCount}');
final manifestFile = ChartExportManifest.exportBatchFile(batch);
final archiveFile = ChartExportArchive.exportBatchZip(batch);

// Platform-neutral save/share/download delivery.
// Tenun does not force a storage plugin; plug in your app's platform layer.
final saver = ChartExportCallbackDeliveryAdapter.save(
  onFile: (file) async {
    // Example integrations:
    // - path_provider + dart:io: File(path).writeAsBytes(file.bytes)
    // - share_plus: SharePlus.instance.share(... file.bytes ...)
    // - web: create a Blob / anchor download from file.bytes or file.dataUri
    debugPrint('Save ${file.filename} (${file.mimeType})');
  },
);
final delivery = await ChartExportDelivery.deliverBatch(
  batch,
  ChartExportDelivery.withRetry(saver, maxAttempts: 3),
  timeout: const Duration(seconds: 10),
  cancellationToken: cancelToken,
  batchOptions: ChartExportDeliveryBatchOptions(
    stopOnFirstFailure: true,
    continueOnProgressError: true,
    onProgress: (progress) {
      debugPrint('Delivered ${progress.completed}/${progress.total}');
    },
    onProgressError: (error, stackTrace, progress) {
      debugPrint('Delivery progress observer failed at ${progress.completed}');
    },
  ),
);
if (delivery.hasFailures) {
  debugPrint(delivery.failed.map((item) => item.errorText).join('\n'));
}
if (delivery.hasIssues) {
  debugPrint(delivery.primaryIssue ?? delivery.issueMessages.join('\n'));
}
final deliveryManifestFile = ChartExportManifest.deliveryBatchFile(delivery);
final deliveryArchiveFile = ChartExportArchive.deliveryBatchZip(delivery);

// Delivery presets are composable:
// - dryRun validates the delivery path without writing/sharing anything.
// - chain fans out to multiple adapters, such as memory capture + platform save.
final previewDelivery = ChartExportDelivery.dryRun(
  intent: ChartExportDeliveryIntent.share,
);
final fanOutDelivery = ChartExportDelivery.chain(
  [
    ChartExportMemoryDeliveryAdapter(intent: ChartExportDeliveryIntent.save),
    saver,
  ],
  stopOnFirstFailure: true,
);

// One orchestrated job for export + optional ZIP + optional delivery.
// This is useful for app services, custom toolbars, or background actions.
final jobController = ChartExportJobController();
final jobOptions = ChartExportJobOptions(
  formats: const [
    ChartExportFormat.csv,
    ChartExportFormat.xlsx,
    ChartExportFormat.png,
  ],
  config: myConfig,
  boundaryKey: _exportKey,
  categoryLabels: ['Jan', 'Feb', 'Mar'],
  filename: 'monthly_report',
  skipUnavailable: true,
  deliverExports: true,
  createArchive: true,
  deliverArchive: true,
  deliveryAdapter: ChartExportDelivery.withRetry(saver, maxAttempts: 3),
  cancellationToken: cancelToken,
  // Strict by default: jobs with plan blockers return a failed result before
  // running export work. Use warnOnly for legacy permissive/no-op behavior.
  preflightPolicy: ChartExportJobPreflightPolicy.failOnBlockers,
  // Callback errors are isolated by default and reported as job warnings.
  // Set this to false if observers should abort the job.
  continueOnCallbackError: true,
  onProgress: (progress) {
    debugPrint('${progress.stage.name}: ${progress.completed}/${progress.total}');
  },
  onEvent: (event) {
    debugPrint('${event.type.name}/${event.stage.name}: ${event.message}');
  },
  onCallbackError: (error) {
    debugPrint(error.toMetadataJson().toString());
  },
);
final plan = jobOptions.buildPlan();
debugPrint(plan.summaryText()); // dry-run: availability, archive, delivery
if (!plan.canRun) {
  debugPrint(plan.blockers.map((issue) => issue.message).join('\n'));
  return;
}
if (plan.hasWarnings) {
  debugPrint(plan.issues.map((issue) => issue.toMetadataJson()).toString());
}

final job = await jobController.run(
  jobOptions,
);
debugPrint(job.summaryText(includeTiming: true));
debugPrint(job.events.map((event) => event.toMetadataJson()).toString());
debugPrint('Files: ${job.outputFilenames.join(', ')}');
for (final file in job.outputFiles) {
  debugPrint('${file.filename}: ${file.sizeBytes} bytes');
}
final jobManifest = ChartExportJobManifest.file(
  job,
  filename: 'monthly_report_manifest',
);
debugPrint(jobManifest.text ?? '');
debugPrint(job.timing?.toMetadataJson().toString() ?? 'No timing data');
switch (job.status) {
  case ChartExportJobStatus.succeeded:
    debugPrint('Export job completed cleanly.');
  case ChartExportJobStatus.completedWithIssues:
    debugPrint('Export job completed with warnings.');
  case ChartExportJobStatus.failed:
    debugPrint('Export job failed.');
  case ChartExportJobStatus.cancelled:
    debugPrint('Export job cancelled: ${job.cancellationReason}');
}
if (job.hasIssues) {
  debugPrint(job.issueMessages.join('\n'));
  debugPrint(job.toMetadataJson().toString());
}

// Custom toolbars can use the same availability resolver as the built-in UI.
final exportCapabilities = ChartExportCapabilities.evaluate(
  formats: ChartExportControls.defaultFormats,
  config: myConfig,
  boundaryKey: _exportKey,
);
debugPrint(exportCapabilities.exportableFormats.toString());

// Payload-aware export for advanced JSON shapes:
// - series data
// - tree data (`children`, `nodes`, `data`)
// - flow data (`nodes` + `links`)
// - bar race frames (`frames`)
final payloadCsv = await ChartExporter.export(
  ChartExportRequest.csvPayload(
    jsonConfig: jsonConfig,
    filename: 'raw_payload_export',
  ),
);

// SVG (Bar/Line/Pie only)
final svg = SvgChartExporter.barChart(
  values: [10, 20, 15],
  labels: ['A', 'B', 'C'],
  title: 'Exported Chart',
);
```

For in-app export buttons, wrap the chart with `ExportableChart` and place
`ChartExportControls` wherever your design system expects actions.
When `showStatus` is enabled, the status line also reports live job progress
for export, archive, and delivery stages. By default it also shows preflight
diagnostics when every configured format is unavailable.

```dart
final exportController = ExportableChartController();

Column(
  children: [
    Expanded(
      child: ExportableChart(
        controller: exportController,
        child: TenunChart(config: myConfig),
      ),
    ),
    ChartExportControls(
      config: myConfig,
      controller: exportController,
      categoryLabels: const ['Jan', 'Feb', 'Mar'],
      filename: 'dashboard_chart',
      showUnavailableFormatTooltips: true,
      showPreflightDiagnostics: true,
      showBatchExportButton: true, // adds "All" when 2+ formats are available
      showArchiveExportButton: true, // adds a ZIP bundle button
      showCancelButton: true, // shows while an export job is running
      preflightPolicy: ChartExportJobPreflightPolicy.failOnBlockers,
      archiveExportLabel: 'ZIP',
      cancelExportLabel: 'Stop',
      cancelExportReason: 'User cancelled export.',
      stopBatchOnFirstFailure: true,
      stopDeliveryBatchOnFirstFailure: true,
      exportTimeout: const Duration(seconds: 10),
      deliveryTimeout: const Duration(seconds: 10),
      cancellationToken: cancelToken,
      deliveryAdapter: ChartExportDelivery.withRetry(
        ChartExportCallbackDeliveryAdapter.save(
          onFile: (file) async {
            // Save/share/download with your app's platform layer.
            debugPrint('Deliver ${file.filename}');
          },
        ),
        maxAttempts: 3,
      ),
      onResult: (result) {
        if (result.bytes != null) {
          // Save/share bytes with your platform storage layer.
        }
      },
      onExportJobPlan: (plan) {
        if (!plan.canRun) debugPrint(plan.diagnosticsText());
        debugPrint('Single export plan: ${plan.summaryText()}');
      },
      onExportJobProgress: (progress) {
        debugPrint('Single export ${progress.stage.name}: ${progress.message}');
      },
      onExportJobResult: (job) {
        debugPrint('Single export job: ${job.summaryText()}');
      },
      onDeliveryResult: (delivery) {
        debugPrint('Delivered ${delivery.filename}');
      },
      onBatchResult: (batch) {
        debugPrint('${batch.successCount} exports completed');
      },
      onBatchJobPlan: (plan) {
        debugPrint('Batch plan: ${plan.summaryText()}');
      },
      onBatchJobProgress: (progress) {
        debugPrint('Batch job ${progress.stage.name}: ${progress.message}');
      },
      onBatchJobResult: (job) {
        debugPrint('Batch job: ${job.summaryText()}');
      },
      onArchiveResult: (archive) {
        debugPrint('Archive ready: ${archive.filename}');
      },
      onArchiveJobPlan: (plan) {
        debugPrint('Archive plan: ${plan.summaryText()}');
      },
      onArchiveJobProgress: (progress) {
        debugPrint('Archive job ${progress.stage.name}: ${progress.message}');
      },
      onArchiveJobResult: (job) {
        debugPrint('Archive job: ${job.summaryText()}');
      },
      onArchiveDeliveryResult: (delivery) {
        debugPrint('Archive delivery: ${delivery.filename}');
      },
      onBatchProgress: (progress) {
        debugPrint('Export progress: ${progress.completed}/${progress.total}');
      },
      onDeliveryBatchResult: (delivery) {
        debugPrint('${delivery.successCount} files delivered');
      },
      onDeliveryBatchProgress: (progress) {
        debugPrint('Delivery progress: ${progress.completed}/${progress.total}');
      },
      onError: (error, stackTrace) {
        // Control/callback errors are reported here without locking the toolbar.
        debugPrint('Export control error: $error');
      },
    ),
  ],
);
```

For a turnkey config or JSON-driven chart with export controls included:

```dart
ExportableTenunChart(
  jsonConfig: {
    'type': 'line',
    'xAxis': {'data': ['Jan', 'Feb', 'Mar']},
    'series': [
      {'name': 'Revenue', 'data': [12, 18, 24]},
    ],
  },
  categoryLabels: const ['Jan', 'Feb', 'Mar'],
  filename: 'revenue_chart',
  validatePayload: true,
  catchRenderErrors: true,
  showUnavailableFormatTooltips: true,
  showExportPreflightDiagnostics: true,
  showArchiveExportButton: true,
  showCancelExportButton: true,
  exportPreflightPolicy: ChartExportJobPreflightPolicy.failOnBlockers,
  archiveExportLabel: 'ZIP',
  cancelExportLabel: 'Stop',
  stopBatchOnFirstFailure: true,
  stopDeliveryBatchOnFirstFailure: true,
  exportDeliveryAdapter: ChartExportCallbackDeliveryAdapter.download(
    onFile: (file) async => debugPrint(file.dataUri),
  ),
  onBatchExportProgress: (progress) {
    debugPrint('Exported ${progress.completed}/${progress.total}');
  },
  onExportJobResult: (job) {
    debugPrint('Single export job: ${job.summaryText()}');
  },
  onBatchExportResult: (batch) {
    debugPrint(batch.toMetadataJson().toString());
  },
  onBatchExportJobResult: (job) {
    debugPrint('Batch job: ${job.summaryText()}');
  },
  onArchiveExportResult: (archive) {
    debugPrint('Archive ready: ${archive.filename}');
  },
  onArchiveExportJobResult: (job) {
    debugPrint('Archive job: ${job.summaryText()}');
  },
  onArchiveExportDeliveryResult: (delivery) {
    debugPrint('Archive delivered: ${delivery.filename}');
  },
  onExportDeliveryBatchProgress: (progress) {
    debugPrint('Delivered ${progress.completed}/${progress.total}');
  },
  onExportResult: (result) {
    debugPrint('${result.filename}: ${result.mimeType}');
  },
  onExportError: (error, stackTrace) {
    debugPrint('Export control error: $error');
  },
);
```

---

## 🛠 Extending Tenun (Custom Charts)

Add a proprietary chart type without modifying the core.

### 1. Define Config
```dart
class MyChartConfig extends BaseChartConfig {
  final List<double> customData;
  MyChartConfig({required this.customData, required super.series}) 
    : super(type: ChartType.custom);
  
  @override
  Widget buildChart() => _MyChartWidget(config: this);
}
```

### 2. Implement Painter
Extend `ChartPainterBase` to access caches and helpers.
```dart
class _MyChartPainter extends ChartPainterBase {
  _MyChartPainter({required super.theme, required this.data});
  final List<double> data;
  
  @override
  void paint(Canvas canvas, Size size) {
    // Use paintCache, textPainterCache, etc.
    final path = buildAndCachePath('my_path_${data.hashCode}', () {
      final p = ui.Path();
      // ... build path ...
      return p;
    });
    canvas.drawPath(path, strokePaint(Colors.blue, 2));
  }
}
```

### 3. Register Type
```dart
final myChartRegistration = ChartRegistration(
  type: ChartType.custom,
  typeString: 'my_custom_chart',
  fromJson: (json) => MyChartConfig.fromJson(json),
  description: 'My proprietary chart',
  tags: ['custom'],
);

// In main():
ChartRegistry.register(myChartRegistration);
```

### 4. Temporary Registration Scope
Use scoped registration for tests, showcase stories, plugin previews, or runtime experiments that must not mutate the app-wide registry.
```dart
// Synchronous work:
final config = ChartRegistry.withRegistrations(
  [myChartRegistration],
  () => ChartRegistry.resolve({
    'type': 'my_custom_chart',
    'series': [
      {'data': [10, 20, 30]},
    ],
  }),
);

// Async work must use the async helper so restoration waits for completion.
await ChartRegistry.withRegistrationsAsync(
  [myChartRegistration],
  () async => loadAndRenderPreview(),
);

// Manual control is available when you need multiple scoped operations.
final snapshot = ChartRegistry.snapshot();
try {
  ChartRegistry.register(myChartRegistration);
  renderPreview();
} finally {
  ChartRegistry.restore(snapshot);
}
```

---

## ✅ Best Practices

| Area | Recommendation |
|------|----------------|
| **Tree-Shaking** | Only register `coreChartsBundle` + specific variant bundles you use. |
| **Scoped Registration** | Prefer `ChartRegistry.withRegistrations()` for tests, previews, and dynamic plugins so temporary chart types do not leak globally. |
| **Painting** | Always use `ChartPainterBase` helpers. Never allocate `Paint`/`TextPainter` inside `paint()`. |
| **Large Data** | Set `LargeDataSamplingConfig.threshold` at app startup. Enable `isComplex: true` in `ChartPainterWidget`. |
| **State** | Keep configs immutable. Use `withTheme()`, `withController()`, or `copyWith()` for updates. |
| **Validation** | Use `validatePayload: true` in `TenunChart` during development to catch JSON errors early. |
| **Animations** | Use `ChartAnimationPreset.morph` for live data updates to smoothly transition between old and new values. |

---

## 📖 API Reference Summary

| Class | Description |
|-------|-------------|
| `TenunChart` / `TenunChartFromJson` | Main entry widget. Handles config resolution and validation. |
| `TenunChartJson` | Stateful JSON option widget with safe build diagnostics and fallback UI. |
| `TenunOption` | High-level JSON option facade with safe switching and non-throwing `tryBuild()`. |
| `ZoomableTenunChart` | Interactive wrapper with pinch/pan/fling/scroll. |
| `DrillDownChartView` | All-in-one drill-down chart with breadcrumbs. |
| `ChartConfigValidator` | Structured payload validation (errors, warnings, suggestions). |
| `ChartExporter` / `SvgChartExporter` | Export to CSV/XLSX/PNG/JPEG/SVG. |
| `ChartExportJobController` | Orchestrates batch export, dry-run planning, preflight policy, optional ZIP archives, delivery, progress, lifecycle events, cancellation, callback isolation, terminal status, stage timing, issue messages, and summaries. |
| `ChartExportJobManifest` | Creates JSON metadata/files for complete export jobs, including plan, status, timings, lifecycle events, outputs, issues, archive, and delivery results. |
| `ChartExportDelivery` | Platform-neutral save/share/download adapter helpers for export results. |
| `ChartExportControls` | Drop-in export buttons backed by `ChartExporter.export()`. |
| `ExportableTenunChart` | Combined chart/export wrapper for config and JSON payloads. |
| `ChartAnimationController` | Manages entrance and morph animations. |
| `ChartRenderPipeline` | Composable layer stack for performant rendering. |


## 📄 License

Apache License. © 2026 Tenun Contributors.  
For enterprise support, custom chart plugins, or SLA guarantees, contact the maintainers.

---
