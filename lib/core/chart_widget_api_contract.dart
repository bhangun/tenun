import 'package:flutter/widgets.dart';

import 'chart_api_contract.dart';

abstract class ChartApiContractProvider {
  ChartApiContract get apiContract;

  bool supportsApiField(String field) => apiContract.supports(field);

  bool recommendsApiField(String field) => apiContract.recommends(field);
}

class ChartWidgetApiContracts {
  const ChartWidgetApiContracts._();

  static ChartApiContract? resolve(Object? value) {
    if (value is ChartApiContractProvider) return value.apiContract;
    if (value is Widget) return resolveType(value.runtimeType);
    return null;
  }

  static ChartApiContract? resolveType(Type type) {
    return resolveTypeName(type.toString());
  }

  static ChartApiContract? resolveTypeName(String typeName) {
    if (isSimpleChartTypeName(typeName)) {
      return ChartApiContracts.simpleWidget;
    }
    return null;
  }

  static bool isSimpleChartTypeName(String typeName) {
    final name = typeName.trim();
    return name.length > 'SimpleChart'.length &&
        name.startsWith('Simple') &&
        name.endsWith('Chart');
  }
}

extension ChartWidgetApiContractExtension on Widget {
  ChartApiContract? get apiContract => ChartWidgetApiContracts.resolve(this);

  bool supportsApiField(String field) {
    return apiContract?.supports(field) ?? false;
  }

  bool recommendsApiField(String field) {
    return apiContract?.recommends(field) ?? false;
  }
}
