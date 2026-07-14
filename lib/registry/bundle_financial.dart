// Legacy compatibility bundle.
//
// Financial chart implementations are now owned by `tenun_pro`. Prefer
// `package:tenun_pro/tenun_pro_financial.dart` and
// `registerTenunProFinancialCharts()` for new financial/trading chart usage.
// This bundle remains temporarily for apps that still import the old
// `package:tenun/registry/bundle_financial.dart` path.

import 'package:tenun_core/core/chart_registry.dart';
import 'package:tenun_core/core/chart_type.dart';

// Chart config imports
import '../charts/candle/candlestick_ohlc_chart.dart';
import '../charts/trading/trading_charts.dart';

@Deprecated(
  'Financial chart registrations moved to package:tenun_pro/tenun_pro_financial.dart. '
  'Use tenunProFinancialTypes instead.',
)
const Set<ChartType> financialTypes = {
  ChartType.candlestick,
  ChartType.ohlc,
  ChartType.kagi,
  ChartType.renko,
  ChartType.macd,
};

@Deprecated(
  'Financial chart registrations moved to package:tenun_pro/tenun_pro_financial.dart. '
  'Use tenunProCandlestickRegistration instead.',
)
final candlestickRegistration = ChartRegistration(
  type: ChartType.candlestick,
  typeString: 'candlestick',
  aliases: const [],
  fromJson: CandlestickChartConfig.fromJsonCandlestick,
  description: 'Candlestick / OHLC chart',
  tags: const ['financial', 'trading'],
);

@Deprecated(
  'Financial chart registrations moved to package:tenun_pro/tenun_pro_financial.dart. '
  'Use tenunProOhlcRegistration instead.',
)
final ohlcRegistration = ChartRegistration(
  type: ChartType.ohlc,
  typeString: 'ohlc',
  fromJson: CandlestickChartConfig.fromJsonOhlc,
  description: 'OHLC chart',
  tags: const ['financial', 'trading'],
);

@Deprecated(
  'Financial chart registrations moved to package:tenun_pro/tenun_pro_financial.dart. '
  'Use tenunProKagiRegistration instead.',
)
final kagiRegistration = ChartRegistration(
  type: ChartType.kagi,
  typeString: 'kagi',
  fromJson: KagiChartConfig.fromJson,
  description: 'Kagi trading chart',
  tags: const ['financial', 'trading'],
);

@Deprecated(
  'Financial chart registrations moved to package:tenun_pro/tenun_pro_financial.dart. '
  'Use tenunProRenkoRegistration instead.',
)
final renkoRegistration = ChartRegistration(
  type: ChartType.renko,
  typeString: 'renko',
  fromJson: RenkoChartConfig.fromJson,
  description: 'Renko trading chart',
  tags: const ['financial', 'trading'],
);

@Deprecated(
  'Financial chart registrations moved to package:tenun_pro/tenun_pro_financial.dart. '
  'Use tenunProMacdRegistration instead.',
)
final macdRegistration = ChartRegistration(
  type: ChartType.macd,
  typeString: 'macd',
  fromJson: MacdChartConfig.fromJson,
  description: 'MACD trading chart',
  tags: const ['financial', 'trading'],
);

@Deprecated(
  'Financial chart registrations moved to package:tenun_pro/tenun_pro_financial.dart. '
  'Use tenunProFinancialChartsBundle or registerTenunProFinancialCharts() instead.',
)
final financialChartsBundle = RegistrationBundle(
  name: 'financial',
  description: 'Candlestick, OHLC, Kagi, Renko, MACD',
  registrations: [
    candlestickRegistration,
    ohlcRegistration,
    kagiRegistration,
    renkoRegistration,
    macdRegistration,
  ],
);
