enum ChartApiFieldCategory {
  structure,
  display,
  interaction,
  accessibility,
  animation,
  formatting,
  layout,
  runtime,
}

enum ChartApiFieldValueKind {
  boolean,
  string,
  number,
  duration,
  curve,
  formatter,
  callback,
  widgetBuilder,
  object,
  list,
}

class ChartApiFieldSpec {
  final String canonicalField;
  final List<String> aliases;
  final ChartApiFieldCategory category;
  final ChartApiFieldValueKind valueKind;
  final String description;
  final bool configFriendly;
  final bool widgetFriendly;

  const ChartApiFieldSpec({
    required this.canonicalField,
    required this.aliases,
    required this.category,
    required this.valueKind,
    required this.description,
    this.configFriendly = true,
    this.widgetFriendly = true,
  });

  bool matches(String field) => aliases.contains(field);

  Map<String, dynamic> toJson() => {
    'canonicalField': canonicalField,
    'aliases': List<String>.from(aliases),
    'category': category.name,
    'valueKind': valueKind.name,
    'description': description,
    'configFriendly': configFriendly,
    'widgetFriendly': widgetFriendly,
  };
}
