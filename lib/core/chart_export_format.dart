enum ChartExportFormat { csv, xlsx, png, jpeg }

extension ChartExportFormatDetails on ChartExportFormat {
  String get extension => switch (this) {
    ChartExportFormat.csv => 'csv',
    ChartExportFormat.xlsx => 'xlsx',
    ChartExportFormat.png => 'png',
    ChartExportFormat.jpeg => 'jpg',
  };

  String get mimeType => switch (this) {
    ChartExportFormat.csv => 'text/csv',
    ChartExportFormat.xlsx =>
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    ChartExportFormat.png => 'image/png',
    ChartExportFormat.jpeg => 'image/jpeg',
  };

  bool get isText => this == ChartExportFormat.csv;

  bool get isBinary => !isText;
}
