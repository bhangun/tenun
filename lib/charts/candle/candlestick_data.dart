/// Legacy compatibility model for the old `package:tenun` financial surface.
///
/// Prefer `package:tenun_pro/tenun_pro_financial.dart`, where Financial chart
/// models and implementations are now owned.
@Deprecated(
  'Financial chart models moved to package:tenun_pro/tenun_pro_financial.dart. '
  'Use CandlestickData from tenun_pro instead.',
)
class CandlestickData {
  final double open;
  final double high;
  final double low;
  final double close;
  final DateTime date;

  CandlestickData({
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.date,
  });
}
