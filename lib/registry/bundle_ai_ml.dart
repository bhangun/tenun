import 'package:tenun_core/core/chart_registry.dart';
import 'package:tenun_core/core/chart_type.dart';

import '../charts/ai_ml/confusion_matrix_config.dart';
import '../charts/ai_ml/roc_curve_config.dart';

final confusionMatrixRegistration = ChartRegistration(
  type: ChartType.confusionMatrix,
  typeString: 'confusionMatrix',
  aliases: const ['cm'],
  fromJson: ConfusionMatrixChartConfig.fromJson,
  description: 'Confusion Matrix for model evaluation.',
  tags: const ['ai', 'ml', 'statistical'],
);

final rocCurveRegistration = ChartRegistration(
  type: ChartType.rocCurve,
  typeString: 'rocCurve',
  aliases: const ['roc'],
  fromJson: ROCCurveChartConfig.fromJson,
  description: 'ROC Curve for binary classifiers.',
  tags: const ['ai', 'ml', 'statistical'],
);

final aiMLChartsBundle = RegistrationBundle(
  name: 'ai_ml',
  description: 'Confusion Matrix, ROC Curve',
  registrations: [confusionMatrixRegistration, rocCurveRegistration],
);
