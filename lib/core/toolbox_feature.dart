class Feature {
  final bool show;

  Feature({
    this.show = false,
  });
}

class ToolboxFeature {
  final Feature saveAsImage;
  final Feature dataZoom;
  final Feature dataView;
  final Feature restore;

  ToolboxFeature({
    required this.saveAsImage,
    required this.dataZoom,
    required this.dataView,
    required this.restore,
  });
}
