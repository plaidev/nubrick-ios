// Generated code - do not modify
// ignore_for_file: unnecessary_cast, unnecessary_null_checks

class StringDecoder {
  static String? decode(dynamic element) {
    if (element == null) {
      return null;
    }
    if (element is! String) {
      return null;
    }
    return element;
  }
}

class IntDecoder {
  static int? decode(dynamic element) {
    if (element == null) {
      return null;
    }
    if (element is int) {
      return element;
    }
    if (element is String) {
      try {
        return int.parse(element);
      } catch (e) {
        return null;
      }
    }
    return null;
  }
}

class FloatDecoder {
  static double? decode(dynamic element) {
    if (element == null) {
      return null;
    }
    if (element is double) {
      return element;
    }
    if (element is int) {
      return element.toDouble();
    }
    if (element is String) {
      try {
        return double.parse(element);
      } catch (e) {
        return null;
      }
    }
    return null;
  }
}

class BooleanDecoder {
  static bool? decode(dynamic element) {
    if (element == null) {
      return null;
    }
    if (element is bool) {
      return element;
    }
    if (element is String) {
      if (element.toLowerCase() == 'true') {
        return true;
      } else if (element.toLowerCase() == 'false') {
        return false;
      }
    }
    return null;
  }
}

class ListDecoder {
  static List<T>? decode<T>(dynamic element, T? Function(dynamic) decoder) {
    if (element == null) {
      return null;
    }
    if (element is! List) {
      return null;
    }

    List<T> list = [];
    for (var item in element) {
      final decoded = decoder(item);
      if (decoded != null) {
        list.add(decoded);
      }
    }
    return list;
  }
}

class DateTimeDecoder {
  static DateTime? decode(dynamic element) {
    if (element == null) {
      return null;
    }
    if (element is! String) {
      return null;
    }
    try {
      return DateTime.parse(element);
    } catch (e) {
      return null;
    }
  }
}

enum AlignItems {
  // ignore: constant_identifier_names
  START,
  // ignore: constant_identifier_names
  CENTER,
  // ignore: constant_identifier_names
  END,
  // ignore: constant_identifier_names
  UNKNOWN,
}

extension AlignItemsExtension on AlignItems {
  static AlignItems? decode(dynamic json) {
    if (json == null) {
      return null;
    }
    if (json is! String) {
      return null;
    }

    switch (json) {
      case 'START':
        return AlignItems.START;
      case 'CENTER':
        return AlignItems.CENTER;
      case 'END':
        return AlignItems.END;
      default:
        return AlignItems.UNKNOWN;
    }
  }

  String? encode() {
    switch (this) {
      case AlignItems.START:
        return 'START';
      case AlignItems.CENTER:
        return 'CENTER';
      case AlignItems.END:
        return 'END';
      case AlignItems.UNKNOWN:
        return null;
    }
  }
}

class ApiHttpHeader {
  final String? name;
  final String? value;

  ApiHttpHeader({
    this.name,
    this.value,
  });

  static ApiHttpHeader? decode(dynamic json) {
    if (json == null) {
      return null;
    }
    if (json is! Map<String, dynamic>) {
      return null;
    }

    return ApiHttpHeader(
      name: StringDecoder.decode(json['name']),
      value: StringDecoder.decode(json['value']),
    );
  }

  Map<String, dynamic> encode() {
    return {
      '__typename': 'ApiHttpHeader',
      'name': name,
      'value': value,
    };
  }
}

class ApiHttpRequest {
  final String? url;
  final ApiHttpRequestMethod? method;
  final List<ApiHttpHeader>? headers;
  final String? body;

  ApiHttpRequest({
    this.url,
    this.method,
    this.headers,
    this.body,
  });

  static ApiHttpRequest? decode(dynamic json) {
    if (json == null) {
      return null;
    }
    if (json is! Map<String, dynamic>) {
      return null;
    }

    return ApiHttpRequest(
      url: StringDecoder.decode(json['url']),
      method: ApiHttpRequestMethodExtension.decode(json['method']),
      headers: ListDecoder.decode(
          json['headers'], (element) => ApiHttpHeader.decode(element)),
      body: StringDecoder.decode(json['body']),
    );
  }

  Map<String, dynamic> encode() {
    return {
      '__typename': 'ApiHttpRequest',
      'url': url,
      'method': method?.encode(),
      'headers': headers?.map((e) => e.encode()).toList(growable: false),
      'body': body,
    };
  }
}

enum ApiHttpRequestMethod {
  // ignore: constant_identifier_names
  GET,
  // ignore: constant_identifier_names
  POST,
  // ignore: constant_identifier_names
  PUT,
  // ignore: constant_identifier_names
  DELETE,
  // ignore: constant_identifier_names
  PATCH,
  // ignore: constant_identifier_names
  HEAD,
  // ignore: constant_identifier_names
  TRACE,
  // ignore: constant_identifier_names
  UNKNOWN,
}

extension ApiHttpRequestMethodExtension on ApiHttpRequestMethod {
  static ApiHttpRequestMethod? decode(dynamic json) {
    if (json == null) {
      return null;
    }
    if (json is! String) {
      return null;
    }

    switch (json) {
      case 'GET':
        return ApiHttpRequestMethod.GET;
      case 'POST':
        return ApiHttpRequestMethod.POST;
      case 'PUT':
        return ApiHttpRequestMethod.PUT;
      case 'DELETE':
        return ApiHttpRequestMethod.DELETE;
      case 'PATCH':
        return ApiHttpRequestMethod.PATCH;
      case 'HEAD':
        return ApiHttpRequestMethod.HEAD;
      case 'TRACE':
        return ApiHttpRequestMethod.TRACE;
      default:
        return ApiHttpRequestMethod.UNKNOWN;
    }
  }

  String? encode() {
    switch (this) {
      case ApiHttpRequestMethod.GET:
        return 'GET';
      case ApiHttpRequestMethod.POST:
        return 'POST';
      case ApiHttpRequestMethod.PUT:
        return 'PUT';
      case ApiHttpRequestMethod.DELETE:
        return 'DELETE';
      case ApiHttpRequestMethod.PATCH:
        return 'PATCH';
      case ApiHttpRequestMethod.HEAD:
        return 'HEAD';
      case ApiHttpRequestMethod.TRACE:
        return 'TRACE';
      case ApiHttpRequestMethod.UNKNOWN:
        return null;
    }
  }
}

class ApiHttpResponseAssertion {
  final List<int>? statusCodes;

  ApiHttpResponseAssertion({
    this.statusCodes,
  });

  static ApiHttpResponseAssertion? decode(dynamic json) {
    if (json == null) {
      return null;
    }
    if (json is! Map<String, dynamic>) {
      return null;
    }

    return ApiHttpResponseAssertion(
      statusCodes: ListDecoder.decode(
          json['statusCodes'], (element) => IntDecoder.decode(element)),
    );
  }

  Map<String, dynamic> encode() {
    return {
      '__typename': 'ApiHttpResponseAssertion',
      'statusCodes': statusCodes?.map((e) => e).toList(growable: false),
    };
  }
}

class BoxShadow {
  final Color? color;
  final int? offsetX;
  final int? offsetY;
  final int? radius;

  BoxShadow({
    this.color,
    this.offsetX,
    this.offsetY,
    this.radius,
  });

  static BoxShadow? decode(dynamic json) {
    if (json == null) {
      return null;
    }
    if (json is! Map<String, dynamic>) {
      return null;
    }

    return BoxShadow(
      color: Color.decode(json['color']),
      offsetX: IntDecoder.decode(json['offsetX']),
      offsetY: IntDecoder.decode(json['offsetY']),
      radius: IntDecoder.decode(json['radius']),
    );
  }

  Map<String, dynamic> encode() {
    return {
      '__typename': 'BoxShadow',
      'color': color?.encode(),
      'offsetX': offsetX,
      'offsetY': offsetY,
      'radius': radius,
    };
  }
}

enum BuiltinUserProperty {
  // ignore: constant_identifier_names
  userId,
  // ignore: constant_identifier_names
  userRnd,
  // ignore: constant_identifier_names
  languageCode,
  // ignore: constant_identifier_names
  regionCode,
  // ignore: constant_identifier_names
  currentTime,
  // ignore: constant_identifier_names
  firstBootTime,
  // ignore: constant_identifier_names
  lastBootTime,
  // ignore: constant_identifier_names
  retentionPeriod,
  // ignore: constant_identifier_names
  bootingTime,
  // ignore: constant_identifier_names
  sdkVersion,
  // ignore: constant_identifier_names
  osVersion,
  // ignore: constant_identifier_names
  osName,
  // ignore: constant_identifier_names
  appId,
  // ignore: constant_identifier_names
  appVersion,
  // ignore: constant_identifier_names
  cfBundleVersion,
  // ignore: constant_identifier_names
  localYear,
  // ignore: constant_identifier_names
  localMonth,
  // ignore: constant_identifier_names
  localWeekday,
  // ignore: constant_identifier_names
  localDay,
  // ignore: constant_identifier_names
  localHour,
  // ignore: constant_identifier_names
  localMinute,
  // ignore: constant_identifier_names
  localSecond,
  // ignore: constant_identifier_names
  UNKNOWN,
}

extension BuiltinUserPropertyExtension on BuiltinUserProperty {
  static BuiltinUserProperty? decode(dynamic json) {
    if (json == null) {
      return null;
    }
    if (json is! String) {
      return null;
    }

    switch (json) {
      case 'userId':
        return BuiltinUserProperty.userId;
      case 'userRnd':
        return BuiltinUserProperty.userRnd;
      case 'languageCode':
        return BuiltinUserProperty.languageCode;
      case 'regionCode':
        return BuiltinUserProperty.regionCode;
      case 'currentTime':
        return BuiltinUserProperty.currentTime;
      case 'firstBootTime':
        return BuiltinUserProperty.firstBootTime;
      case 'lastBootTime':
        return BuiltinUserProperty.lastBootTime;
      case 'retentionPeriod':
        return BuiltinUserProperty.retentionPeriod;
      case 'bootingTime':
        return BuiltinUserProperty.bootingTime;
      case 'sdkVersion':
        return BuiltinUserProperty.sdkVersion;
      case 'osVersion':
        return BuiltinUserProperty.osVersion;
      case 'osName':
        return BuiltinUserProperty.osName;
      case 'appId':
        return BuiltinUserProperty.appId;
      case 'appVersion':
        return BuiltinUserProperty.appVersion;
      case 'cfBundleVersion':
        return BuiltinUserProperty.cfBundleVersion;
      case 'localYear':
        return BuiltinUserProperty.localYear;
      case 'localMonth':
        return BuiltinUserProperty.localMonth;
      case 'localWeekday':
        return BuiltinUserProperty.localWeekday;
      case 'localDay':
        return BuiltinUserProperty.localDay;
      case 'localHour':
        return BuiltinUserProperty.localHour;
      case 'localMinute':
        return BuiltinUserProperty.localMinute;
      case 'localSecond':
        return BuiltinUserProperty.localSecond;
      default:
        return BuiltinUserProperty.UNKNOWN;
    }
  }

  String? encode() {
    switch (this) {
      case BuiltinUserProperty.userId:
        return 'userId';
      case BuiltinUserProperty.userRnd:
        return 'userRnd';
      case BuiltinUserProperty.languageCode:
        return 'languageCode';
      case BuiltinUserProperty.regionCode:
        return 'regionCode';
      case BuiltinUserProperty.currentTime:
        return 'currentTime';
      case BuiltinUserProperty.firstBootTime:
        return 'firstBootTime';
      case BuiltinUserProperty.lastBootTime:
        return 'lastBootTime';
      case BuiltinUserProperty.retentionPeriod:
        return 'retentionPeriod';
      case BuiltinUserProperty.bootingTime:
        return 'bootingTime';
      case BuiltinUserProperty.sdkVersion:
        return 'sdkVersion';
      case BuiltinUserProperty.osVersion:
        return 'osVersion';
      case BuiltinUserProperty.osName:
        return 'osName';
      case BuiltinUserProperty.appId:
        return 'appId';
      case BuiltinUserProperty.appVersion:
        return 'appVersion';
      case BuiltinUserProperty.cfBundleVersion:
        return 'cfBundleVersion';
      case BuiltinUserProperty.localYear:
        return 'localYear';
      case BuiltinUserProperty.localMonth:
        return 'localMonth';
      case BuiltinUserProperty.localWeekday:
        return 'localWeekday';
      case BuiltinUserProperty.localDay:
        return 'localDay';
      case BuiltinUserProperty.localHour:
        return 'localHour';
      case BuiltinUserProperty.localMinute:
        return 'localMinute';
      case BuiltinUserProperty.localSecond:
        return 'localSecond';
      case BuiltinUserProperty.UNKNOWN:
        return null;
    }
  }
}

enum CollectionKind {
  // ignore: constant_identifier_names
  CAROUSEL,
  // ignore: constant_identifier_names
  SCROLL,
  // ignore: constant_identifier_names
  GRID,
  // ignore: constant_identifier_names
  UNKNOWN,
}

extension CollectionKindExtension on CollectionKind {
  static CollectionKind? decode(dynamic json) {
    if (json == null) {
      return null;
    }
    if (json is! String) {
      return null;
    }

    switch (json) {
      case 'CAROUSEL':
        return CollectionKind.CAROUSEL;
      case 'SCROLL':
        return CollectionKind.SCROLL;
      case 'GRID':
        return CollectionKind.GRID;
      default:
        return CollectionKind.UNKNOWN;
    }
  }

  String? encode() {
    switch (this) {
      case CollectionKind.CAROUSEL:
        return 'CAROUSEL';
      case CollectionKind.SCROLL:
        return 'SCROLL';
      case CollectionKind.GRID:
        return 'GRID';
      case CollectionKind.UNKNOWN:
        return null;
    }
  }
}

class Color {
  final double? red;
  final double? green;
  final double? blue;
  final double? alpha;

  Color({
    this.red,
    this.green,
    this.blue,
    this.alpha,
  });

  static Color? decode(dynamic json) {
    if (json == null) {
      return null;
    }
    if (json is! Map<String, dynamic>) {
      return null;
    }

    return Color(
      red: FloatDecoder.decode(json['red']),
      green: FloatDecoder.decode(json['green']),
      blue: FloatDecoder.decode(json['blue']),
      alpha: FloatDecoder.decode(json['alpha']),
    );
  }

  Map<String, dynamic> encode() {
    return {
      '__typename': 'Color',
      'red': red,
      'green': green,
      'blue': blue,
      'alpha': alpha,
    };
  }
}

enum ConditionOperator {
  // ignore: constant_identifier_names
  Regex,
  // ignore: constant_identifier_names
  Equal,
  // ignore: constant_identifier_names
  NotEqual,
  // ignore: constant_identifier_names
  GreaterThan,
  // ignore: constant_identifier_names
  GreaterThanOrEqual,
  // ignore: constant_identifier_names
  LessThan,
  // ignore: constant_identifier_names
  LessThanOrEqual,
  // ignore: constant_identifier_names
  In,
  // ignore: constant_identifier_names
  NotIn,
  // ignore: constant_identifier_names
  Between,
  // ignore: constant_identifier_names
  UNKNOWN,
}

extension ConditionOperatorExtension on ConditionOperator {
  static ConditionOperator? decode(dynamic json) {
    if (json == null) {
      return null;
    }
    if (json is! String) {
      return null;
    }

    switch (json) {
      case 'Regex':
        return ConditionOperator.Regex;
      case 'Equal':
        return ConditionOperator.Equal;
      case 'NotEqual':
        return ConditionOperator.NotEqual;
      case 'GreaterThan':
        return ConditionOperator.GreaterThan;
      case 'GreaterThanOrEqual':
        return ConditionOperator.GreaterThanOrEqual;
      case 'LessThan':
        return ConditionOperator.LessThan;
      case 'LessThanOrEqual':
        return ConditionOperator.LessThanOrEqual;
      case 'In':
        return ConditionOperator.In;
      case 'NotIn':
        return ConditionOperator.NotIn;
      case 'Between':
        return ConditionOperator.Between;
      default:
        return ConditionOperator.UNKNOWN;
    }
  }

  String? encode() {
    switch (this) {
      case ConditionOperator.Regex:
        return 'Regex';
      case ConditionOperator.Equal:
        return 'Equal';
      case ConditionOperator.NotEqual:
        return 'NotEqual';
      case ConditionOperator.GreaterThan:
        return 'GreaterThan';
      case ConditionOperator.GreaterThanOrEqual:
        return 'GreaterThanOrEqual';
      case ConditionOperator.LessThan:
        return 'LessThan';
      case ConditionOperator.LessThanOrEqual:
        return 'LessThanOrEqual';
      case ConditionOperator.In:
        return 'In';
      case ConditionOperator.NotIn:
        return 'NotIn';
      case ConditionOperator.Between:
        return 'Between';
      case ConditionOperator.UNKNOWN:
        return null;
    }
  }
}

class ExperimentCondition {
  final String? property;
  final String? operator;
  final String? value;

  ExperimentCondition({
    this.property,
    this.operator,
    this.value,
  });

  static ExperimentCondition? decode(dynamic json) {
    if (json == null) {
      return null;
    }
    if (json is! Map<String, dynamic>) {
      return null;
    }

    return ExperimentCondition(
      property: StringDecoder.decode(json['property']),
      operator: StringDecoder.decode(json['operator']),
      value: StringDecoder.decode(json['value']),
    );
  }

  Map<String, dynamic> encode() {
    return {
      '__typename': 'ExperimentCondition',
      'property': property,
      'operator': operator,
      'value': value,
    };
  }
}

class ExperimentConfig {
  final String? id;
  final ExperimentKind? kind;
  final List<ExperimentCondition>? distribution;
  final ExperimentVariant? baseline;
  final List<ExperimentVariant>? variants;
  final int? seed;
  final ExperimentFrequency? frequency;
  final DateTime? startedAt;
  final DateTime? endedAt;

  ExperimentConfig({
    this.id,
    this.kind,
    this.distribution,
    this.baseline,
    this.variants,
    this.seed,
    this.frequency,
    this.startedAt,
    this.endedAt,
  });

  static ExperimentConfig? decode(dynamic json) {
    if (json == null) {
      return null;
    }
    if (json is! Map<String, dynamic>) {
      return null;
    }

    return ExperimentConfig(
      id: StringDecoder.decode(json['id']),
      kind: ExperimentKindExtension.decode(json['kind']),
      distribution: ListDecoder.decode(json['distribution'],
          (element) => ExperimentCondition.decode(element)),
      baseline: ExperimentVariant.decode(json['baseline']),
      variants: ListDecoder.decode(
          json['variants'], (element) => ExperimentVariant.decode(element)),
      seed: IntDecoder.decode(json['seed']),
      frequency: ExperimentFrequency.decode(json['frequency']),
      startedAt: DateTimeDecoder.decode(json['startedAt']),
      endedAt: DateTimeDecoder.decode(json['endedAt']),
    );
  }

  Map<String, dynamic> encode() {
    return {
      '__typename': 'ExperimentConfig',
      'id': id,
      'kind': kind?.encode(),
      'distribution':
          distribution?.map((e) => e.encode()).toList(growable: false),
      'baseline': baseline?.encode(),
      'variants': variants?.map((e) => e.encode()).toList(growable: false),
      'seed': seed,
      'frequency': frequency?.encode(),
      'startedAt': startedAt,
      'endedAt': endedAt,
    };
  }
}

class ExperimentConfigs {
  final List<ExperimentConfig>? configs;

  ExperimentConfigs({
    this.configs,
  });

  static ExperimentConfigs? decode(dynamic json) {
    if (json == null) {
      return null;
    }
    if (json is! Map<String, dynamic>) {
      return null;
    }

    return ExperimentConfigs(
      configs: ListDecoder.decode(
          json['configs'], (element) => ExperimentConfig.decode(element)),
    );
  }

  Map<String, dynamic> encode() {
    return {
      '__typename': 'ExperimentConfigs',
      'configs': configs?.map((e) => e.encode()).toList(growable: false),
    };
  }
}

class ExperimentFrequency {
  final int? period;
  final FrequencyUnit? unit;

  ExperimentFrequency({
    this.period,
    this.unit,
  });

  static ExperimentFrequency? decode(dynamic json) {
    if (json == null) {
      return null;
    }
    if (json is! Map<String, dynamic>) {
      return null;
    }

    return ExperimentFrequency(
      period: IntDecoder.decode(json['period']),
      unit: FrequencyUnitExtension.decode(json['unit']),
    );
  }

  Map<String, dynamic> encode() {
    return {
      '__typename': 'ExperimentFrequency',
      'period': period,
      'unit': unit?.encode(),
    };
  }
}

enum ExperimentKind {
  // ignore: constant_identifier_names
  EMBED,
  // ignore: constant_identifier_names
  POPUP,
  // ignore: constant_identifier_names
  TOOLTIP,
  // ignore: constant_identifier_names
  CONFIG,
  // ignore: constant_identifier_names
  UNKNOWN,
}

extension ExperimentKindExtension on ExperimentKind {
  static ExperimentKind? decode(dynamic json) {
    if (json == null) {
      return null;
    }
    if (json is! String) {
      return null;
    }

    switch (json) {
      case 'EMBED':
        return ExperimentKind.EMBED;
      case 'POPUP':
        return ExperimentKind.POPUP;
      case 'TOOLTIP':
        return ExperimentKind.TOOLTIP;
      case 'CONFIG':
        return ExperimentKind.CONFIG;
      default:
        return ExperimentKind.UNKNOWN;
    }
  }

  String? encode() {
    switch (this) {
      case ExperimentKind.EMBED:
        return 'EMBED';
      case ExperimentKind.POPUP:
        return 'POPUP';
      case ExperimentKind.TOOLTIP:
        return 'TOOLTIP';
      case ExperimentKind.CONFIG:
        return 'CONFIG';
      case ExperimentKind.UNKNOWN:
        return null;
    }
  }
}

class ExperimentVariant {
  final String? id;
  final List<VariantConfig>? configs;
  final int? weight;

  ExperimentVariant({
    this.id,
    this.configs,
    this.weight,
  });

  static ExperimentVariant? decode(dynamic json) {
    if (json == null) {
      return null;
    }
    if (json is! Map<String, dynamic>) {
      return null;
    }

    return ExperimentVariant(
      id: StringDecoder.decode(json['id']),
      configs: ListDecoder.decode(
          json['configs'], (element) => VariantConfig.decode(element)),
      weight: IntDecoder.decode(json['weight']),
    );
  }

  Map<String, dynamic> encode() {
    return {
      '__typename': 'ExperimentVariant',
      'id': id,
      'configs': configs?.map((e) => e.encode()).toList(growable: false),
      'weight': weight,
    };
  }
}

enum FlexDirection {
  // ignore: constant_identifier_names
  ROW,
  // ignore: constant_identifier_names
  COLUMN,
  // ignore: constant_identifier_names
  UNKNOWN,
}

extension FlexDirectionExtension on FlexDirection {
  static FlexDirection? decode(dynamic json) {
    if (json == null) {
      return null;
    }
    if (json is! String) {
      return null;
    }

    switch (json) {
      case 'ROW':
        return FlexDirection.ROW;
      case 'COLUMN':
        return FlexDirection.COLUMN;
      default:
        return FlexDirection.UNKNOWN;
    }
  }

  String? encode() {
    switch (this) {
      case FlexDirection.ROW:
        return 'ROW';
      case FlexDirection.COLUMN:
        return 'COLUMN';
      case FlexDirection.UNKNOWN:
        return null;
    }
  }
}

enum FontDesign {
  // ignore: constant_identifier_names
  DEFAULT,
  // ignore: constant_identifier_names
  MONOSPACE,
  // ignore: constant_identifier_names
  ROUNDED,
  // ignore: constant_identifier_names
  SERIF,
  // ignore: constant_identifier_names
  UNKNOWN,
}

extension FontDesignExtension on FontDesign {
  static FontDesign? decode(dynamic json) {
    if (json == null) {
      return null;
    }
    if (json is! String) {
      return null;
    }

    switch (json) {
      case 'DEFAULT':
        return FontDesign.DEFAULT;
      case 'MONOSPACE':
        return FontDesign.MONOSPACE;
      case 'ROUNDED':
        return FontDesign.ROUNDED;
      case 'SERIF':
        return FontDesign.SERIF;
      default:
        return FontDesign.UNKNOWN;
    }
  }

  String? encode() {
    switch (this) {
      case FontDesign.DEFAULT:
        return 'DEFAULT';
      case FontDesign.MONOSPACE:
        return 'MONOSPACE';
      case FontDesign.ROUNDED:
        return 'ROUNDED';
      case FontDesign.SERIF:
        return 'SERIF';
      case FontDesign.UNKNOWN:
        return null;
    }
  }
}

enum FontWeight {
  // ignore: constant_identifier_names
  ULTRA_LIGHT,
  // ignore: constant_identifier_names
  THIN,
  // ignore: constant_identifier_names
  LIGHT,
  // ignore: constant_identifier_names
  REGULAR,
  // ignore: constant_identifier_names
  MEDIUM,
  // ignore: constant_identifier_names
  SEMI_BOLD,
  // ignore: constant_identifier_names
  BOLD,
  // ignore: constant_identifier_names
  HEAVY,
  // ignore: constant_identifier_names
  BLACK,
  // ignore: constant_identifier_names
  UNKNOWN,
}

extension FontWeightExtension on FontWeight {
  static FontWeight? decode(dynamic json) {
    if (json == null) {
      return null;
    }
    if (json is! String) {
      return null;
    }

    switch (json) {
      case 'ULTRA_LIGHT':
        return FontWeight.ULTRA_LIGHT;
      case 'THIN':
        return FontWeight.THIN;
      case 'LIGHT':
        return FontWeight.LIGHT;
      case 'REGULAR':
        return FontWeight.REGULAR;
      case 'MEDIUM':
        return FontWeight.MEDIUM;
      case 'SEMI_BOLD':
        return FontWeight.SEMI_BOLD;
      case 'BOLD':
        return FontWeight.BOLD;
      case 'HEAVY':
        return FontWeight.HEAVY;
      case 'BLACK':
        return FontWeight.BLACK;
      default:
        return FontWeight.UNKNOWN;
    }
  }

  String? encode() {
    switch (this) {
      case FontWeight.ULTRA_LIGHT:
        return 'ULTRA_LIGHT';
      case FontWeight.THIN:
        return 'THIN';
      case FontWeight.LIGHT:
        return 'LIGHT';
      case FontWeight.REGULAR:
        return 'REGULAR';
      case FontWeight.MEDIUM:
        return 'MEDIUM';
      case FontWeight.SEMI_BOLD:
        return 'SEMI_BOLD';
      case FontWeight.BOLD:
        return 'BOLD';
      case FontWeight.HEAVY:
        return 'HEAVY';
      case FontWeight.BLACK:
        return 'BLACK';
      case FontWeight.UNKNOWN:
        return null;
    }
  }
}

class FrameData {
  final int? width;
  final int? height;
  final int? paddingLeft;
  final int? paddingRight;
  final int? paddingTop;
  final int? paddingBottom;
  final int? borderRadius;
  final int? borderTopLeftRadius;
  final int? borderTopRightRadius;
  final int? borderBottomRightRadius;
  final int? borderBottomLeftRadius;
  final int? borderWidth;
  final Color? borderColor;
  final Color? background;
  final String? backgroundSrc;
  final BoxShadow? shadow;

  FrameData({
    this.width,
    this.height,
    this.paddingLeft,
    this.paddingRight,
    this.paddingTop,
    this.paddingBottom,
    this.borderRadius,
    this.borderTopLeftRadius,
    this.borderTopRightRadius,
    this.borderBottomRightRadius,
    this.borderBottomLeftRadius,
    this.borderWidth,
    this.borderColor,
    this.background,
    this.backgroundSrc,
    this.shadow,
  });

  static FrameData? decode(dynamic json) {
    if (json == null) {
      return null;
    }
    if (json is! Map<String, dynamic>) {
      return null;
    }

    return FrameData(
      width: IntDecoder.decode(json['width']),
      height: IntDecoder.decode(json['height']),
      paddingLeft: IntDecoder.decode(json['paddingLeft']),
      paddingRight: IntDecoder.decode(json['paddingRight']),
      paddingTop: IntDecoder.decode(json['paddingTop']),
      paddingBottom: IntDecoder.decode(json['paddingBottom']),
      borderRadius: IntDecoder.decode(json['borderRadius']),
      borderTopLeftRadius: IntDecoder.decode(json['borderTopLeftRadius']),
      borderTopRightRadius: IntDecoder.decode(json['borderTopRightRadius']),
      borderBottomRightRadius:
          IntDecoder.decode(json['borderBottomRightRadius']),
      borderBottomLeftRadius: IntDecoder.decode(json['borderBottomLeftRadius']),
      borderWidth: IntDecoder.decode(json['borderWidth']),
      borderColor: Color.decode(json['borderColor']),
      background: Color.decode(json['background']),
      backgroundSrc: StringDecoder.decode(json['backgroundSrc']),
      shadow: BoxShadow.decode(json['shadow']),
    );
  }

  Map<String, dynamic> encode() {
    return {
      '__typename': 'FrameData',
      'width': width,
      'height': height,
      'paddingLeft': paddingLeft,
      'paddingRight': paddingRight,
      'paddingTop': paddingTop,
      'paddingBottom': paddingBottom,
      'borderRadius': borderRadius,
      'borderTopLeftRadius': borderTopLeftRadius,
      'borderTopRightRadius': borderTopRightRadius,
      'borderBottomRightRadius': borderBottomRightRadius,
      'borderBottomLeftRadius': borderBottomLeftRadius,
      'borderWidth': borderWidth,
      'borderColor': borderColor?.encode(),
      'background': background?.encode(),
      'backgroundSrc': backgroundSrc,
      'shadow': shadow?.encode(),
    };
  }
}

enum FrequencyUnit {
  // ignore: constant_identifier_names
  DAY,
  // ignore: constant_identifier_names
  UNKNOWN,
}

extension FrequencyUnitExtension on FrequencyUnit {
  static FrequencyUnit? decode(dynamic json) {
    if (json == null) {
      return null;
    }
    if (json is! String) {
      return null;
    }

    switch (json) {
      case 'DAY':
        return FrequencyUnit.DAY;
      default:
        return FrequencyUnit.UNKNOWN;
    }
  }

  String? encode() {
    switch (this) {
      case FrequencyUnit.DAY:
        return 'DAY';
      case FrequencyUnit.UNKNOWN:
        return null;
    }
  }
}

enum ImageContentMode {
  // ignore: constant_identifier_names
  FIT,
  // ignore: constant_identifier_names
  FILL,
  // ignore: constant_identifier_names
  UNKNOWN,
}

extension ImageContentModeExtension on ImageContentMode {
  static ImageContentMode? decode(dynamic json) {
    if (json == null) {
      return null;
    }
    if (json is! String) {
      return null;
    }

    switch (json) {
      case 'FIT':
        return ImageContentMode.FIT;
      case 'FILL':
        return ImageContentMode.FILL;
      default:
        return ImageContentMode.UNKNOWN;
    }
  }

  String? encode() {
    switch (this) {
      case ImageContentMode.FIT:
        return 'FIT';
      case ImageContentMode.FILL:
        return 'FILL';
      case ImageContentMode.UNKNOWN:
        return null;
    }
  }
}

enum JustifyContent {
  // ignore: constant_identifier_names
  START,
  // ignore: constant_identifier_names
  CENTER,
  // ignore: constant_identifier_names
  END,
  // ignore: constant_identifier_names
  SPACE_BETWEEN,
  // ignore: constant_identifier_names
  UNKNOWN,
}

extension JustifyContentExtension on JustifyContent {
  static JustifyContent? decode(dynamic json) {
    if (json == null) {
      return null;
    }
    if (json is! String) {
      return null;
    }

    switch (json) {
      case 'START':
        return JustifyContent.START;
      case 'CENTER':
        return JustifyContent.CENTER;
      case 'END':
        return JustifyContent.END;
      case 'SPACE_BETWEEN':
        return JustifyContent.SPACE_BETWEEN;
      default:
        return JustifyContent.UNKNOWN;
    }
  }

  String? encode() {
    switch (this) {
      case JustifyContent.START:
        return 'START';
      case JustifyContent.CENTER:
        return 'CENTER';
      case JustifyContent.END:
        return 'END';
      case JustifyContent.SPACE_BETWEEN:
        return 'SPACE_BETWEEN';
      case JustifyContent.UNKNOWN:
        return null;
    }
  }
}

enum ModalPresentationStyle {
  // ignore: constant_identifier_names
  DEPENDS_ON_CONTEXT_OR_FULL_SCREEN,
  // ignore: constant_identifier_names
  DEPENDS_ON_CONTEXT_OR_PAGE_SHEET,
  // ignore: constant_identifier_names
  UNKNOWN,
}

extension ModalPresentationStyleExtension on ModalPresentationStyle {
  static ModalPresentationStyle? decode(dynamic json) {
    if (json == null) {
      return null;
    }
    if (json is! String) {
      return null;
    }

    switch (json) {
      case 'DEPENDS_ON_CONTEXT_OR_FULL_SCREEN':
        return ModalPresentationStyle.DEPENDS_ON_CONTEXT_OR_FULL_SCREEN;
      case 'DEPENDS_ON_CONTEXT_OR_PAGE_SHEET':
        return ModalPresentationStyle.DEPENDS_ON_CONTEXT_OR_PAGE_SHEET;
      default:
        return ModalPresentationStyle.UNKNOWN;
    }
  }

  String? encode() {
    switch (this) {
      case ModalPresentationStyle.DEPENDS_ON_CONTEXT_OR_FULL_SCREEN:
        return 'DEPENDS_ON_CONTEXT_OR_FULL_SCREEN';
      case ModalPresentationStyle.DEPENDS_ON_CONTEXT_OR_PAGE_SHEET:
        return 'DEPENDS_ON_CONTEXT_OR_PAGE_SHEET';
      case ModalPresentationStyle.UNKNOWN:
        return null;
    }
  }
}

enum ModalScreenSize {
  // ignore: constant_identifier_names
  MEDIUM,
  // ignore: constant_identifier_names
  LARGE,
  // ignore: constant_identifier_names
  MEDIUM_AND_LARGE,
  // ignore: constant_identifier_names
  UNKNOWN,
}

extension ModalScreenSizeExtension on ModalScreenSize {
  static ModalScreenSize? decode(dynamic json) {
    if (json == null) {
      return null;
    }
    if (json is! String) {
      return null;
    }

    switch (json) {
      case 'MEDIUM':
        return ModalScreenSize.MEDIUM;
      case 'LARGE':
        return ModalScreenSize.LARGE;
      case 'MEDIUM_AND_LARGE':
        return ModalScreenSize.MEDIUM_AND_LARGE;
      default:
        return ModalScreenSize.UNKNOWN;
    }
  }

  String? encode() {
    switch (this) {
      case ModalScreenSize.MEDIUM:
        return 'MEDIUM';
      case ModalScreenSize.LARGE:
        return 'LARGE';
      case ModalScreenSize.MEDIUM_AND_LARGE:
        return 'MEDIUM_AND_LARGE';
      case ModalScreenSize.UNKNOWN:
        return null;
    }
  }
}

class NavigationBackButton {
  final String? title;
  final Color? color;
  final bool? visible;

  NavigationBackButton({
    this.title,
    this.color,
    this.visible,
  });

  static NavigationBackButton? decode(dynamic json) {
    if (json == null) {
      return null;
    }
    if (json is! Map<String, dynamic>) {
      return null;
    }

    return NavigationBackButton(
      title: StringDecoder.decode(json['title']),
      color: Color.decode(json['color']),
      visible: BooleanDecoder.decode(json['visible']),
    );
  }

  Map<String, dynamic> encode() {
    return {
      '__typename': 'NavigationBackButton',
      'title': title,
      'color': color?.encode(),
      'visible': visible,
    };
  }
}

enum Overflow {
  // ignore: constant_identifier_names
  VISIBLE,
  // ignore: constant_identifier_names
  HIDDEN,
  // ignore: constant_identifier_names
  SCROLL,
  // ignore: constant_identifier_names
  UNKNOWN,
}

extension OverflowExtension on Overflow {
  static Overflow? decode(dynamic json) {
    if (json == null) {
      return null;
    }
    if (json is! String) {
      return null;
    }

    switch (json) {
      case 'VISIBLE':
        return Overflow.VISIBLE;
      case 'HIDDEN':
        return Overflow.HIDDEN;
      case 'SCROLL':
        return Overflow.SCROLL;
      default:
        return Overflow.UNKNOWN;
    }
  }

  String? encode() {
    switch (this) {
      case Overflow.VISIBLE:
        return 'VISIBLE';
      case Overflow.HIDDEN:
        return 'HIDDEN';
      case Overflow.SCROLL:
        return 'SCROLL';
      case Overflow.UNKNOWN:
        return null;
    }
  }
}

enum PageKind {
  // ignore: constant_identifier_names
  COMPONENT,
  // ignore: constant_identifier_names
  MODAL,
  // ignore: constant_identifier_names
  WEBVIEW_MODAL,
  // ignore: constant_identifier_names
  TOOLTIP,
  // ignore: constant_identifier_names
  TRIGGER,
  // ignore: constant_identifier_names
  LOAD_BALANCER,
  // ignore: constant_identifier_names
  DISMISSED,
  // ignore: constant_identifier_names
  UNKNOWN,
}

extension PageKindExtension on PageKind {
  static PageKind? decode(dynamic json) {
    if (json == null) {
      return null;
    }
    if (json is! String) {
      return null;
    }

    switch (json) {
      case 'COMPONENT':
        return PageKind.COMPONENT;
      case 'MODAL':
        return PageKind.MODAL;
      case 'WEBVIEW_MODAL':
        return PageKind.WEBVIEW_MODAL;
      case 'TOOLTIP':
        return PageKind.TOOLTIP;
      case 'TRIGGER':
        return PageKind.TRIGGER;
      case 'LOAD_BALANCER':
        return PageKind.LOAD_BALANCER;
      case 'DISMISSED':
        return PageKind.DISMISSED;
      default:
        return PageKind.UNKNOWN;
    }
  }

  String? encode() {
    switch (this) {
      case PageKind.COMPONENT:
        return 'COMPONENT';
      case PageKind.MODAL:
        return 'MODAL';
      case PageKind.WEBVIEW_MODAL:
        return 'WEBVIEW_MODAL';
      case PageKind.TOOLTIP:
        return 'TOOLTIP';
      case PageKind.TRIGGER:
        return 'TRIGGER';
      case PageKind.LOAD_BALANCER:
        return 'LOAD_BALANCER';
      case PageKind.DISMISSED:
        return 'DISMISSED';
      case PageKind.UNKNOWN:
        return null;
    }
  }
}

class Property {
  final String? name;
  final String? value;
  final PropertyType? ptype;

  Property({
    this.name,
    this.value,
    this.ptype,
  });

  static Property? decode(dynamic json) {
    if (json == null) {
      return null;
    }
    if (json is! Map<String, dynamic>) {
      return null;
    }

    return Property(
      name: StringDecoder.decode(json['name']),
      value: StringDecoder.decode(json['value']),
      ptype: PropertyTypeExtension.decode(json['ptype']),
    );
  }

  Map<String, dynamic> encode() {
    return {
      '__typename': 'Property',
      'name': name,
      'value': value,
      'ptype': ptype?.encode(),
    };
  }
}

enum PropertyType {
  // ignore: constant_identifier_names
  INTEGER,
  // ignore: constant_identifier_names
  STRING,
  // ignore: constant_identifier_names
  TIMESTAMPZ,
  // ignore: constant_identifier_names
  UNKNOWN,
}

extension PropertyTypeExtension on PropertyType {
  static PropertyType? decode(dynamic json) {
    if (json == null) {
      return null;
    }
    if (json is! String) {
      return null;
    }

    switch (json) {
      case 'INTEGER':
        return PropertyType.INTEGER;
      case 'STRING':
        return PropertyType.STRING;
      case 'TIMESTAMPZ':
        return PropertyType.TIMESTAMPZ;
      default:
        return PropertyType.UNKNOWN;
    }
  }

  String? encode() {
    switch (this) {
      case PropertyType.INTEGER:
        return 'INTEGER';
      case PropertyType.STRING:
        return 'STRING';
      case PropertyType.TIMESTAMPZ:
        return 'TIMESTAMPZ';
      case PropertyType.UNKNOWN:
        return null;
    }
  }
}

enum TextAlign {
  // ignore: constant_identifier_names
  NATURAL,
  // ignore: constant_identifier_names
  LEFT,
  // ignore: constant_identifier_names
  CENTER,
  // ignore: constant_identifier_names
  RIGHT,
  // ignore: constant_identifier_names
  UNKNOWN,
}

extension TextAlignExtension on TextAlign {
  static TextAlign? decode(dynamic json) {
    if (json == null) {
      return null;
    }
    if (json is! String) {
      return null;
    }

    switch (json) {
      case 'NATURAL':
        return TextAlign.NATURAL;
      case 'LEFT':
        return TextAlign.LEFT;
      case 'CENTER':
        return TextAlign.CENTER;
      case 'RIGHT':
        return TextAlign.RIGHT;
      default:
        return TextAlign.UNKNOWN;
    }
  }

  String? encode() {
    switch (this) {
      case TextAlign.NATURAL:
        return 'NATURAL';
      case TextAlign.LEFT:
        return 'LEFT';
      case TextAlign.CENTER:
        return 'CENTER';
      case TextAlign.RIGHT:
        return 'RIGHT';
      case TextAlign.UNKNOWN:
        return null;
    }
  }
}

class TriggerEventDef {
  final String? name;

  TriggerEventDef({
    this.name,
  });

  static TriggerEventDef? decode(dynamic json) {
    if (json == null) {
      return null;
    }
    if (json is! Map<String, dynamic>) {
      return null;
    }

    return TriggerEventDef(
      name: StringDecoder.decode(json['name']),
    );
  }

  Map<String, dynamic> encode() {
    return {
      '__typename': 'TriggerEventDef',
      'name': name,
    };
  }
}

enum TriggerEventNameDefs {
  // ignore: constant_identifier_names
  RETENTION_1,
  // ignore: constant_identifier_names
  RETENTION_2_3,
  // ignore: constant_identifier_names
  RETENTION_4_7,
  // ignore: constant_identifier_names
  RETENTION_8_14,
  // ignore: constant_identifier_names
  RETENTION_15,
  // ignore: constant_identifier_names
  USER_BOOT_APP,
  // ignore: constant_identifier_names
  USER_ENTER_TO_APP,
  // ignore: constant_identifier_names
  USER_ENTER_TO_APP_FIRSTLY,
  // ignore: constant_identifier_names
  USER_ENTER_TO_FOREGROUND,
  // ignore: constant_identifier_names
  N_ERROR_RECORD,
  // ignore: constant_identifier_names
  N_ERROR_IN_SDK_RECORD,
  // ignore: constant_identifier_names
  UNKNOWN,
}

extension TriggerEventNameDefsExtension on TriggerEventNameDefs {
  static TriggerEventNameDefs? decode(dynamic json) {
    if (json == null) {
      return null;
    }
    if (json is! String) {
      return null;
    }

    switch (json) {
      case 'RETENTION_1':
        return TriggerEventNameDefs.RETENTION_1;
      case 'RETENTION_2_3':
        return TriggerEventNameDefs.RETENTION_2_3;
      case 'RETENTION_4_7':
        return TriggerEventNameDefs.RETENTION_4_7;
      case 'RETENTION_8_14':
        return TriggerEventNameDefs.RETENTION_8_14;
      case 'RETENTION_15':
        return TriggerEventNameDefs.RETENTION_15;
      case 'USER_BOOT_APP':
        return TriggerEventNameDefs.USER_BOOT_APP;
      case 'USER_ENTER_TO_APP':
        return TriggerEventNameDefs.USER_ENTER_TO_APP;
      case 'USER_ENTER_TO_APP_FIRSTLY':
        return TriggerEventNameDefs.USER_ENTER_TO_APP_FIRSTLY;
      case 'USER_ENTER_TO_FOREGROUND':
        return TriggerEventNameDefs.USER_ENTER_TO_FOREGROUND;
      case 'N_ERROR_RECORD':
        return TriggerEventNameDefs.N_ERROR_RECORD;
      case 'N_ERROR_IN_SDK_RECORD':
        return TriggerEventNameDefs.N_ERROR_IN_SDK_RECORD;
      default:
        return TriggerEventNameDefs.UNKNOWN;
    }
  }

  String? encode() {
    switch (this) {
      case TriggerEventNameDefs.RETENTION_1:
        return 'RETENTION_1';
      case TriggerEventNameDefs.RETENTION_2_3:
        return 'RETENTION_2_3';
      case TriggerEventNameDefs.RETENTION_4_7:
        return 'RETENTION_4_7';
      case TriggerEventNameDefs.RETENTION_8_14:
        return 'RETENTION_8_14';
      case TriggerEventNameDefs.RETENTION_15:
        return 'RETENTION_15';
      case TriggerEventNameDefs.USER_BOOT_APP:
        return 'USER_BOOT_APP';
      case TriggerEventNameDefs.USER_ENTER_TO_APP:
        return 'USER_ENTER_TO_APP';
      case TriggerEventNameDefs.USER_ENTER_TO_APP_FIRSTLY:
        return 'USER_ENTER_TO_APP_FIRSTLY';
      case TriggerEventNameDefs.USER_ENTER_TO_FOREGROUND:
        return 'USER_ENTER_TO_FOREGROUND';
      case TriggerEventNameDefs.N_ERROR_RECORD:
        return 'N_ERROR_RECORD';
      case TriggerEventNameDefs.N_ERROR_IN_SDK_RECORD:
        return 'N_ERROR_IN_SDK_RECORD';
      case TriggerEventNameDefs.UNKNOWN:
        return null;
    }
  }
}

class TriggerSetting {
  final UIBlockEventDispatcher? onTrigger;
  final TriggerEventDef? trigger;

  TriggerSetting({
    this.onTrigger,
    this.trigger,
  });

  static TriggerSetting? decode(dynamic json) {
    if (json == null) {
      return null;
    }
    if (json is! Map<String, dynamic>) {
      return null;
    }

    return TriggerSetting(
      onTrigger: UIBlockEventDispatcher.decode(json['onTrigger']),
      trigger: TriggerEventDef.decode(json['trigger']),
    );
  }

  Map<String, dynamic> encode() {
    return {
      '__typename': 'TriggerSetting',
      'onTrigger': onTrigger?.encode(),
      'trigger': trigger?.encode(),
    };
  }
}

abstract class UIBlock {
  factory UIBlock.asUIRootBlock(UIRootBlock data) = UIBlockUIRootBlock;
  factory UIBlock.asUIPageBlock(UIPageBlock data) = UIBlockUIPageBlock;
  factory UIBlock.asUIFlexContainerBlock(UIFlexContainerBlock data) =
      UIBlockUIFlexContainerBlock;
  factory UIBlock.asUITextBlock(UITextBlock data) = UIBlockUITextBlock;
  factory UIBlock.asUIImageBlock(UIImageBlock data) = UIBlockUIImageBlock;
  factory UIBlock.asUICollectionBlock(UICollectionBlock data) =
      UIBlockUICollectionBlock;
  factory UIBlock.asUICarouselBlock(UICarouselBlock data) =
      UIBlockUICarouselBlock;
  factory UIBlock.asUITextInputBlock(UITextInputBlock data) =
      UIBlockUITextInputBlock;
  factory UIBlock.asUISelectInputBlock(UISelectInputBlock data) =
      UIBlockUISelectInputBlock;
  factory UIBlock.asUIMultiSelectInputBlock(UIMultiSelectInputBlock data) =
      UIBlockUIMultiSelectInputBlock;
  factory UIBlock.asUISwitchInputBlock(UISwitchInputBlock data) =
      UIBlockUISwitchInputBlock;

  static UIBlock? decode(dynamic json) {
    if (json == null) {
      return null;
    }
    if (json is! Map<String, dynamic>) {
      return null;
    }

    final typename = json['__typename'];
    if (typename == null || typename is! String) {
      return null;
    }

    switch (typename) {
      case 'UIRootBlock':
        final decoded = UIRootBlock.decode(json);
        return decoded != null ? UIBlock.asUIRootBlock(decoded) : null;
      case 'UIPageBlock':
        final decoded = UIPageBlock.decode(json);
        return decoded != null ? UIBlock.asUIPageBlock(decoded) : null;
      case 'UIFlexContainerBlock':
        final decoded = UIFlexContainerBlock.decode(json);
        return decoded != null ? UIBlock.asUIFlexContainerBlock(decoded) : null;
      case 'UITextBlock':
        final decoded = UITextBlock.decode(json);
        return decoded != null ? UIBlock.asUITextBlock(decoded) : null;
      case 'UIImageBlock':
        final decoded = UIImageBlock.decode(json);
        return decoded != null ? UIBlock.asUIImageBlock(decoded) : null;
      case 'UICollectionBlock':
        final decoded = UICollectionBlock.decode(json);
        return decoded != null ? UIBlock.asUICollectionBlock(decoded) : null;
      case 'UICarouselBlock':
        final decoded = UICarouselBlock.decode(json);
        return decoded != null ? UIBlock.asUICarouselBlock(decoded) : null;
      case 'UITextInputBlock':
        final decoded = UITextInputBlock.decode(json);
        return decoded != null ? UIBlock.asUITextInputBlock(decoded) : null;
      case 'UISelectInputBlock':
        final decoded = UISelectInputBlock.decode(json);
        return decoded != null ? UIBlock.asUISelectInputBlock(decoded) : null;
      case 'UIMultiSelectInputBlock':
        final decoded = UIMultiSelectInputBlock.decode(json);
        return decoded != null
            ? UIBlock.asUIMultiSelectInputBlock(decoded)
            : null;
      case 'UISwitchInputBlock':
        final decoded = UISwitchInputBlock.decode(json);
        return decoded != null ? UIBlock.asUISwitchInputBlock(decoded) : null;
      default:
        return null;
    }
  }

  Map<String, dynamic>? encode();
}

class UIBlockUIRootBlock implements UIBlock {
  final UIRootBlock data;

  UIBlockUIRootBlock(this.data);

  @override
  Map<String, dynamic>? encode() {
    return data.encode();
  }
}

class UIBlockUIPageBlock implements UIBlock {
  final UIPageBlock data;

  UIBlockUIPageBlock(this.data);

  @override
  Map<String, dynamic>? encode() {
    return data.encode();
  }
}

class UIBlockUIFlexContainerBlock implements UIBlock {
  final UIFlexContainerBlock data;

  UIBlockUIFlexContainerBlock(this.data);

  @override
  Map<String, dynamic>? encode() {
    return data.encode();
  }
}

class UIBlockUITextBlock implements UIBlock {
  final UITextBlock data;

  UIBlockUITextBlock(this.data);

  @override
  Map<String, dynamic>? encode() {
    return data.encode();
  }
}

class UIBlockUIImageBlock implements UIBlock {
  final UIImageBlock data;

  UIBlockUIImageBlock(this.data);

  @override
  Map<String, dynamic>? encode() {
    return data.encode();
  }
}

class UIBlockUICollectionBlock implements UIBlock {
  final UICollectionBlock data;

  UIBlockUICollectionBlock(this.data);

  @override
  Map<String, dynamic>? encode() {
    return data.encode();
  }
}

class UIBlockUICarouselBlock implements UIBlock {
  final UICarouselBlock data;

  UIBlockUICarouselBlock(this.data);

  @override
  Map<String, dynamic>? encode() {
    return data.encode();
  }
}

class UIBlockUITextInputBlock implements UIBlock {
  final UITextInputBlock data;

  UIBlockUITextInputBlock(this.data);

  @override
  Map<String, dynamic>? encode() {
    return data.encode();
  }
}

class UIBlockUISelectInputBlock implements UIBlock {
  final UISelectInputBlock data;

  UIBlockUISelectInputBlock(this.data);

  @override
  Map<String, dynamic>? encode() {
    return data.encode();
  }
}

class UIBlockUIMultiSelectInputBlock implements UIBlock {
  final UIMultiSelectInputBlock data;

  UIBlockUIMultiSelectInputBlock(this.data);

  @override
  Map<String, dynamic>? encode() {
    return data.encode();
  }
}

class UIBlockUISwitchInputBlock implements UIBlock {
  final UISwitchInputBlock data;

  UIBlockUISwitchInputBlock(this.data);

  @override
  Map<String, dynamic>? encode() {
    return data.encode();
  }
}

class UIBlockEventDispatcher {
  final String? name;
  final String? destinationPageId;
  final String? deepLink;
  final List<Property>? payload;
  final ApiHttpRequest? httpRequest;
  final ApiHttpResponseAssertion? httpResponseAssertion;

  UIBlockEventDispatcher({
    this.name,
    this.destinationPageId,
    this.deepLink,
    this.payload,
    this.httpRequest,
    this.httpResponseAssertion,
  });

  static UIBlockEventDispatcher? decode(dynamic json) {
    if (json == null) {
      return null;
    }
    if (json is! Map<String, dynamic>) {
      return null;
    }

    return UIBlockEventDispatcher(
      name: StringDecoder.decode(json['name']),
      destinationPageId: StringDecoder.decode(json['destinationPageId']),
      deepLink: StringDecoder.decode(json['deepLink']),
      payload: ListDecoder.decode(
          json['payload'], (element) => Property.decode(element)),
      httpRequest: ApiHttpRequest.decode(json['httpRequest']),
      httpResponseAssertion:
          ApiHttpResponseAssertion.decode(json['httpResponseAssertion']),
    );
  }

  Map<String, dynamic> encode() {
    return {
      '__typename': 'UIBlockEventDispatcher',
      'name': name,
      'destinationPageId': destinationPageId,
      'deepLink': deepLink,
      'payload': payload?.map((e) => e.encode()).toList(growable: false),
      'httpRequest': httpRequest?.encode(),
      'httpResponseAssertion': httpResponseAssertion?.encode(),
    };
  }
}

class UICarouselBlock {
  final String? id;
  final UICarouselBlockData? data;

  UICarouselBlock({
    this.id,
    this.data,
  });

  static UICarouselBlock? decode(dynamic json) {
    if (json == null) {
      return null;
    }
    if (json is! Map<String, dynamic>) {
      return null;
    }

    return UICarouselBlock(
      id: StringDecoder.decode(json['id']),
      data: UICarouselBlockData.decode(json['data']),
    );
  }

  Map<String, dynamic> encode() {
    return {
      '__typename': 'UICarouselBlock',
      'id': id,
      'data': data?.encode(),
    };
  }
}

class UICarouselBlockData {
  final List<UIBlock>? children;
  final FrameData? frame;
  final int? gap;
  final UIBlockEventDispatcher? onClick;

  UICarouselBlockData({
    this.children,
    this.frame,
    this.gap,
    this.onClick,
  });

  static UICarouselBlockData? decode(dynamic json) {
    if (json == null) {
      return null;
    }
    if (json is! Map<String, dynamic>) {
      return null;
    }

    return UICarouselBlockData(
      children: ListDecoder.decode(
          json['children'], (element) => UIBlock.decode(element)),
      frame: FrameData.decode(json['frame']),
      gap: IntDecoder.decode(json['gap']),
      onClick: UIBlockEventDispatcher.decode(json['onClick']),
    );
  }

  Map<String, dynamic> encode() {
    return {
      '__typename': 'UICarouselBlockData',
      'children': children?.map((e) => e.encode()).toList(growable: false),
      'frame': frame?.encode(),
      'gap': gap,
      'onClick': onClick?.encode(),
    };
  }
}

class UICollectionBlock {
  final String? id;
  final UICollectionBlockData? data;

  UICollectionBlock({
    this.id,
    this.data,
  });

  static UICollectionBlock? decode(dynamic json) {
    if (json == null) {
      return null;
    }
    if (json is! Map<String, dynamic>) {
      return null;
    }

    return UICollectionBlock(
      id: StringDecoder.decode(json['id']),
      data: UICollectionBlockData.decode(json['data']),
    );
  }

  Map<String, dynamic> encode() {
    return {
      '__typename': 'UICollectionBlock',
      'id': id,
      'data': data?.encode(),
    };
  }
}

class UICollectionBlockData {
  final List<UIBlock>? children;
  final FrameData? frame;
  final int? gap;
  final CollectionKind? kind;
  final FlexDirection? direction;
  final String? reference;
  final int? gridSize;
  final int? itemWidth;
  final int? itemHeight;
  final bool? fullItemWidth;
  final bool? pageControl;
  final bool? autoScroll;
  final double? autoScrollInterval;
  final UIBlockEventDispatcher? onClick;

  UICollectionBlockData({
    this.children,
    this.frame,
    this.gap,
    this.kind,
    this.direction,
    this.reference,
    this.gridSize,
    this.itemWidth,
    this.itemHeight,
    this.fullItemWidth,
    this.pageControl,
    this.autoScroll,
    this.autoScrollInterval,
    this.onClick,
  });

  static UICollectionBlockData? decode(dynamic json) {
    if (json == null) {
      return null;
    }
    if (json is! Map<String, dynamic>) {
      return null;
    }

    return UICollectionBlockData(
      children: ListDecoder.decode(
          json['children'], (element) => UIBlock.decode(element)),
      frame: FrameData.decode(json['frame']),
      gap: IntDecoder.decode(json['gap']),
      kind: CollectionKindExtension.decode(json['kind']),
      direction: FlexDirectionExtension.decode(json['direction']),
      reference: StringDecoder.decode(json['reference']),
      gridSize: IntDecoder.decode(json['gridSize']),
      itemWidth: IntDecoder.decode(json['itemWidth']),
      itemHeight: IntDecoder.decode(json['itemHeight']),
      fullItemWidth: BooleanDecoder.decode(json['fullItemWidth']),
      pageControl: BooleanDecoder.decode(json['pageControl']),
      autoScroll: BooleanDecoder.decode(json['autoScroll']),
      autoScrollInterval: FloatDecoder.decode(json['autoScrollInterval']),
      onClick: UIBlockEventDispatcher.decode(json['onClick']),
    );
  }

  Map<String, dynamic> encode() {
    return {
      '__typename': 'UICollectionBlockData',
      'children': children?.map((e) => e.encode()).toList(growable: false),
      'frame': frame?.encode(),
      'gap': gap,
      'kind': kind?.encode(),
      'direction': direction?.encode(),
      'reference': reference,
      'gridSize': gridSize,
      'itemWidth': itemWidth,
      'itemHeight': itemHeight,
      'fullItemWidth': fullItemWidth,
      'pageControl': pageControl,
      'autoScroll': autoScroll,
      'autoScrollInterval': autoScrollInterval,
      'onClick': onClick?.encode(),
    };
  }
}

class UIFlexContainerBlock {
  final String? id;
  final UIFlexContainerBlockData? data;

  UIFlexContainerBlock({
    this.id,
    this.data,
  });

  static UIFlexContainerBlock? decode(dynamic json) {
    if (json == null) {
      return null;
    }
    if (json is! Map<String, dynamic>) {
      return null;
    }

    return UIFlexContainerBlock(
      id: StringDecoder.decode(json['id']),
      data: UIFlexContainerBlockData.decode(json['data']),
    );
  }

  Map<String, dynamic> encode() {
    return {
      '__typename': 'UIFlexContainerBlock',
      'id': id,
      'data': data?.encode(),
    };
  }
}

class UIFlexContainerBlockData {
  final List<UIBlock>? children;
  final FlexDirection? direction;
  final JustifyContent? justifyContent;
  final AlignItems? alignItems;
  final int? gap;
  final FrameData? frame;
  final Overflow? overflow;
  final UIBlockEventDispatcher? onClick;

  UIFlexContainerBlockData({
    this.children,
    this.direction,
    this.justifyContent,
    this.alignItems,
    this.gap,
    this.frame,
    this.overflow,
    this.onClick,
  });

  static UIFlexContainerBlockData? decode(dynamic json) {
    if (json == null) {
      return null;
    }
    if (json is! Map<String, dynamic>) {
      return null;
    }

    return UIFlexContainerBlockData(
      children: ListDecoder.decode(
          json['children'], (element) => UIBlock.decode(element)),
      direction: FlexDirectionExtension.decode(json['direction']),
      justifyContent: JustifyContentExtension.decode(json['justifyContent']),
      alignItems: AlignItemsExtension.decode(json['alignItems']),
      gap: IntDecoder.decode(json['gap']),
      frame: FrameData.decode(json['frame']),
      overflow: OverflowExtension.decode(json['overflow']),
      onClick: UIBlockEventDispatcher.decode(json['onClick']),
    );
  }

  Map<String, dynamic> encode() {
    return {
      '__typename': 'UIFlexContainerBlockData',
      'children': children?.map((e) => e.encode()).toList(growable: false),
      'direction': direction?.encode(),
      'justifyContent': justifyContent?.encode(),
      'alignItems': alignItems?.encode(),
      'gap': gap,
      'frame': frame?.encode(),
      'overflow': overflow?.encode(),
      'onClick': onClick?.encode(),
    };
  }
}

class UIImageBlock {
  final String? id;
  final UIImageBlockData? data;

  UIImageBlock({
    this.id,
    this.data,
  });

  static UIImageBlock? decode(dynamic json) {
    if (json == null) {
      return null;
    }
    if (json is! Map<String, dynamic>) {
      return null;
    }

    return UIImageBlock(
      id: StringDecoder.decode(json['id']),
      data: UIImageBlockData.decode(json['data']),
    );
  }

  Map<String, dynamic> encode() {
    return {
      '__typename': 'UIImageBlock',
      'id': id,
      'data': data?.encode(),
    };
  }
}

class UIImageBlockData {
  final String? src;
  final ImageContentMode? contentMode;
  final FrameData? frame;
  final UIBlockEventDispatcher? onClick;

  UIImageBlockData({
    this.src,
    this.contentMode,
    this.frame,
    this.onClick,
  });

  static UIImageBlockData? decode(dynamic json) {
    if (json == null) {
      return null;
    }
    if (json is! Map<String, dynamic>) {
      return null;
    }

    return UIImageBlockData(
      src: StringDecoder.decode(json['src']),
      contentMode: ImageContentModeExtension.decode(json['contentMode']),
      frame: FrameData.decode(json['frame']),
      onClick: UIBlockEventDispatcher.decode(json['onClick']),
    );
  }

  Map<String, dynamic> encode() {
    return {
      '__typename': 'UIImageBlockData',
      'src': src,
      'contentMode': contentMode?.encode(),
      'frame': frame?.encode(),
      'onClick': onClick?.encode(),
    };
  }
}

class UIMultiSelectInputBlock {
  final String? id;
  final UIMultiSelectInputBlockData? data;

  UIMultiSelectInputBlock({
    this.id,
    this.data,
  });

  static UIMultiSelectInputBlock? decode(dynamic json) {
    if (json == null) {
      return null;
    }
    if (json is! Map<String, dynamic>) {
      return null;
    }

    return UIMultiSelectInputBlock(
      id: StringDecoder.decode(json['id']),
      data: UIMultiSelectInputBlockData.decode(json['data']),
    );
  }

  Map<String, dynamic> encode() {
    return {
      '__typename': 'UIMultiSelectInputBlock',
      'id': id,
      'data': data?.encode(),
    };
  }
}

class UIMultiSelectInputBlockData {
  final String? key;
  final List<UISelectInputOption>? options;
  final List<String>? value;
  final String? placeholder;
  final int? size;
  final Color? color;
  final FontDesign? design;
  final FontWeight? weight;
  final TextAlign? textAlign;
  final FrameData? frame;

  UIMultiSelectInputBlockData({
    this.key,
    this.options,
    this.value,
    this.placeholder,
    this.size,
    this.color,
    this.design,
    this.weight,
    this.textAlign,
    this.frame,
  });

  static UIMultiSelectInputBlockData? decode(dynamic json) {
    if (json == null) {
      return null;
    }
    if (json is! Map<String, dynamic>) {
      return null;
    }

    return UIMultiSelectInputBlockData(
      key: StringDecoder.decode(json['key']),
      options: ListDecoder.decode(
          json['options'], (element) => UISelectInputOption.decode(element)),
      value: ListDecoder.decode(
          json['value'], (element) => StringDecoder.decode(element)),
      placeholder: StringDecoder.decode(json['placeholder']),
      size: IntDecoder.decode(json['size']),
      color: Color.decode(json['color']),
      design: FontDesignExtension.decode(json['design']),
      weight: FontWeightExtension.decode(json['weight']),
      textAlign: TextAlignExtension.decode(json['textAlign']),
      frame: FrameData.decode(json['frame']),
    );
  }

  Map<String, dynamic> encode() {
    return {
      '__typename': 'UIMultiSelectInputBlockData',
      'key': key,
      'options': options?.map((e) => e.encode()).toList(growable: false),
      'value': value?.map((e) => e).toList(growable: false),
      'placeholder': placeholder,
      'size': size,
      'color': color?.encode(),
      'design': design?.encode(),
      'weight': weight?.encode(),
      'textAlign': textAlign?.encode(),
      'frame': frame?.encode(),
    };
  }
}

class UIPageBlock {
  final String? id;
  final String? name;
  final UIPageBlockData? data;

  UIPageBlock({
    this.id,
    this.name,
    this.data,
  });

  static UIPageBlock? decode(dynamic json) {
    if (json == null) {
      return null;
    }
    if (json is! Map<String, dynamic>) {
      return null;
    }

    return UIPageBlock(
      id: StringDecoder.decode(json['id']),
      name: StringDecoder.decode(json['name']),
      data: UIPageBlockData.decode(json['data']),
    );
  }

  Map<String, dynamic> encode() {
    return {
      '__typename': 'UIPageBlock',
      'id': id,
      'name': name,
      'data': data?.encode(),
    };
  }
}

class UIPageBlockData {
  final PageKind? kind;
  final ModalPresentationStyle? modalPresentationStyle;
  final ModalScreenSize? modalScreenSize;
  final NavigationBackButton? modalNavigationBackButton;
  final String? webviewUrl;
  final TriggerSetting? triggerSetting;
  final UIBlock? renderAs;
  final UIPageBlockPosition? position;
  final ApiHttpRequest? httpRequest;
  final UITooltipSize? tooltipSize;
  final String? tooltipAnchor;
  final List<Property>? props;
  final String? query;

  UIPageBlockData({
    this.kind,
    this.modalPresentationStyle,
    this.modalScreenSize,
    this.modalNavigationBackButton,
    this.webviewUrl,
    this.triggerSetting,
    this.renderAs,
    this.position,
    this.httpRequest,
    this.tooltipSize,
    this.tooltipAnchor,
    this.props,
    this.query,
  });

  static UIPageBlockData? decode(dynamic json) {
    if (json == null) {
      return null;
    }
    if (json is! Map<String, dynamic>) {
      return null;
    }

    return UIPageBlockData(
      kind: PageKindExtension.decode(json['kind']),
      modalPresentationStyle: ModalPresentationStyleExtension.decode(
          json['modalPresentationStyle']),
      modalScreenSize: ModalScreenSizeExtension.decode(json['modalScreenSize']),
      modalNavigationBackButton:
          NavigationBackButton.decode(json['modalNavigationBackButton']),
      webviewUrl: StringDecoder.decode(json['webviewUrl']),
      triggerSetting: TriggerSetting.decode(json['triggerSetting']),
      renderAs: UIBlock.decode(json['renderAs']),
      position: UIPageBlockPosition.decode(json['position']),
      httpRequest: ApiHttpRequest.decode(json['httpRequest']),
      tooltipSize: UITooltipSize.decode(json['tooltipSize']),
      tooltipAnchor: StringDecoder.decode(json['tooltipAnchor']),
      props: ListDecoder.decode(
          json['props'], (element) => Property.decode(element)),
      query: StringDecoder.decode(json['query']),
    );
  }

  Map<String, dynamic> encode() {
    return {
      '__typename': 'UIPageBlockData',
      'kind': kind?.encode(),
      'modalPresentationStyle': modalPresentationStyle?.encode(),
      'modalScreenSize': modalScreenSize?.encode(),
      'modalNavigationBackButton': modalNavigationBackButton?.encode(),
      'webviewUrl': webviewUrl,
      'triggerSetting': triggerSetting?.encode(),
      'renderAs': renderAs?.encode(),
      'position': position?.encode(),
      'httpRequest': httpRequest?.encode(),
      'tooltipSize': tooltipSize?.encode(),
      'tooltipAnchor': tooltipAnchor,
      'props': props?.map((e) => e.encode()).toList(growable: false),
      'query': query,
    };
  }
}

class UIPageBlockPosition {
  final int? x;
  final int? y;

  UIPageBlockPosition({
    this.x,
    this.y,
  });

  static UIPageBlockPosition? decode(dynamic json) {
    if (json == null) {
      return null;
    }
    if (json is! Map<String, dynamic>) {
      return null;
    }

    return UIPageBlockPosition(
      x: IntDecoder.decode(json['x']),
      y: IntDecoder.decode(json['y']),
    );
  }

  Map<String, dynamic> encode() {
    return {
      '__typename': 'UIPageBlockPosition',
      'x': x,
      'y': y,
    };
  }
}

class UIRootBlock {
  final String? id;
  final UIRootBlockData? data;

  UIRootBlock({
    this.id,
    this.data,
  });

  static UIRootBlock? decode(dynamic json) {
    if (json == null) {
      return null;
    }
    if (json is! Map<String, dynamic>) {
      print("json is not a map");
      return null;
    }

    return UIRootBlock(
      id: StringDecoder.decode(json['id']),
      data: UIRootBlockData.decode(json['data']),
    );
  }

  Map<String, dynamic> encode() {
    return {
      '__typename': 'UIRootBlock',
      'id': id,
      'data': data?.encode(),
    };
  }
}

class UIRootBlockData {
  final List<UIPageBlock>? pages;
  final String? currentPageId;

  UIRootBlockData({
    this.pages,
    this.currentPageId,
  });

  static UIRootBlockData? decode(dynamic json) {
    if (json == null) {
      return null;
    }
    if (json is! Map<String, dynamic>) {
      return null;
    }

    return UIRootBlockData(
      pages: ListDecoder.decode(
          json['pages'], (element) => UIPageBlock.decode(element)),
      currentPageId: StringDecoder.decode(json['currentPageId']),
    );
  }

  Map<String, dynamic> encode() {
    return {
      '__typename': 'UIRootBlockData',
      'pages': pages?.map((e) => e.encode()).toList(growable: false),
      'currentPageId': currentPageId,
    };
  }
}

class UISelectInputBlock {
  final String? id;
  final UISelectInputBlockData? data;

  UISelectInputBlock({
    this.id,
    this.data,
  });

  static UISelectInputBlock? decode(dynamic json) {
    if (json == null) {
      return null;
    }
    if (json is! Map<String, dynamic>) {
      return null;
    }

    return UISelectInputBlock(
      id: StringDecoder.decode(json['id']),
      data: UISelectInputBlockData.decode(json['data']),
    );
  }

  Map<String, dynamic> encode() {
    return {
      '__typename': 'UISelectInputBlock',
      'id': id,
      'data': data?.encode(),
    };
  }
}

class UISelectInputBlockData {
  final String? key;
  final List<UISelectInputOption>? options;
  final String? value;
  final int? size;
  final Color? color;
  final FontDesign? design;
  final FontWeight? weight;
  final TextAlign? textAlign;
  final FrameData? frame;

  UISelectInputBlockData({
    this.key,
    this.options,
    this.value,
    this.size,
    this.color,
    this.design,
    this.weight,
    this.textAlign,
    this.frame,
  });

  static UISelectInputBlockData? decode(dynamic json) {
    if (json == null) {
      return null;
    }
    if (json is! Map<String, dynamic>) {
      return null;
    }

    return UISelectInputBlockData(
      key: StringDecoder.decode(json['key']),
      options: ListDecoder.decode(
          json['options'], (element) => UISelectInputOption.decode(element)),
      value: StringDecoder.decode(json['value']),
      size: IntDecoder.decode(json['size']),
      color: Color.decode(json['color']),
      design: FontDesignExtension.decode(json['design']),
      weight: FontWeightExtension.decode(json['weight']),
      textAlign: TextAlignExtension.decode(json['textAlign']),
      frame: FrameData.decode(json['frame']),
    );
  }

  Map<String, dynamic> encode() {
    return {
      '__typename': 'UISelectInputBlockData',
      'key': key,
      'options': options?.map((e) => e.encode()).toList(growable: false),
      'value': value,
      'size': size,
      'color': color?.encode(),
      'design': design?.encode(),
      'weight': weight?.encode(),
      'textAlign': textAlign?.encode(),
      'frame': frame?.encode(),
    };
  }
}

class UISelectInputOption {
  final String? value;
  final String? label;

  UISelectInputOption({
    this.value,
    this.label,
  });

  static UISelectInputOption? decode(dynamic json) {
    if (json == null) {
      return null;
    }
    if (json is! Map<String, dynamic>) {
      return null;
    }

    return UISelectInputOption(
      value: StringDecoder.decode(json['value']),
      label: StringDecoder.decode(json['label']),
    );
  }

  Map<String, dynamic> encode() {
    return {
      '__typename': 'UISelectInputOption',
      'value': value,
      'label': label,
    };
  }
}

class UISwitchInputBlock {
  final String? id;
  final UISwitchInputBlockData? data;

  UISwitchInputBlock({
    this.id,
    this.data,
  });

  static UISwitchInputBlock? decode(dynamic json) {
    if (json == null) {
      return null;
    }
    if (json is! Map<String, dynamic>) {
      return null;
    }

    return UISwitchInputBlock(
      id: StringDecoder.decode(json['id']),
      data: UISwitchInputBlockData.decode(json['data']),
    );
  }

  Map<String, dynamic> encode() {
    return {
      '__typename': 'UISwitchInputBlock',
      'id': id,
      'data': data?.encode(),
    };
  }
}

class UISwitchInputBlockData {
  final String? key;
  final bool? value;
  final Color? checkedColor;

  UISwitchInputBlockData({
    this.key,
    this.value,
    this.checkedColor,
  });

  static UISwitchInputBlockData? decode(dynamic json) {
    if (json == null) {
      return null;
    }
    if (json is! Map<String, dynamic>) {
      return null;
    }

    return UISwitchInputBlockData(
      key: StringDecoder.decode(json['key']),
      value: BooleanDecoder.decode(json['value']),
      checkedColor: Color.decode(json['checkedColor']),
    );
  }

  Map<String, dynamic> encode() {
    return {
      '__typename': 'UISwitchInputBlockData',
      'key': key,
      'value': value,
      'checkedColor': checkedColor?.encode(),
    };
  }
}

class UITextBlock {
  final String? id;
  final UITextBlockData? data;

  UITextBlock({
    this.id,
    this.data,
  });

  static UITextBlock? decode(dynamic json) {
    if (json == null) {
      return null;
    }
    if (json is! Map<String, dynamic>) {
      return null;
    }

    return UITextBlock(
      id: StringDecoder.decode(json['id']),
      data: UITextBlockData.decode(json['data']),
    );
  }

  Map<String, dynamic> encode() {
    return {
      '__typename': 'UITextBlock',
      'id': id,
      'data': data?.encode(),
    };
  }
}

class UITextBlockData {
  final String? value;
  final int? size;
  final Color? color;
  final FontDesign? design;
  final FontWeight? weight;
  final int? maxLines;
  final FrameData? frame;
  final UIBlockEventDispatcher? onClick;

  UITextBlockData({
    this.value,
    this.size,
    this.color,
    this.design,
    this.weight,
    this.maxLines,
    this.frame,
    this.onClick,
  });

  static UITextBlockData? decode(dynamic json) {
    if (json == null) {
      return null;
    }
    if (json is! Map<String, dynamic>) {
      return null;
    }

    return UITextBlockData(
      value: StringDecoder.decode(json['value']),
      size: IntDecoder.decode(json['size']),
      color: Color.decode(json['color']),
      design: FontDesignExtension.decode(json['design']),
      weight: FontWeightExtension.decode(json['weight']),
      maxLines: IntDecoder.decode(json['maxLines']),
      frame: FrameData.decode(json['frame']),
      onClick: UIBlockEventDispatcher.decode(json['onClick']),
    );
  }

  Map<String, dynamic> encode() {
    return {
      '__typename': 'UITextBlockData',
      'value': value,
      'size': size,
      'color': color?.encode(),
      'design': design?.encode(),
      'weight': weight?.encode(),
      'maxLines': maxLines,
      'frame': frame?.encode(),
      'onClick': onClick?.encode(),
    };
  }
}

class UITextInputBlock {
  final String? id;
  final UITextInputBlockData? data;

  UITextInputBlock({
    this.id,
    this.data,
  });

  static UITextInputBlock? decode(dynamic json) {
    if (json == null) {
      return null;
    }
    if (json is! Map<String, dynamic>) {
      return null;
    }

    return UITextInputBlock(
      id: StringDecoder.decode(json['id']),
      data: UITextInputBlockData.decode(json['data']),
    );
  }

  Map<String, dynamic> encode() {
    return {
      '__typename': 'UITextInputBlock',
      'id': id,
      'data': data?.encode(),
    };
  }
}

class UITextInputBlockData {
  final String? key;
  final String? value;
  final String? placeholder;
  final String? regex;
  final UITooltipMessage? errorMessage;
  final UITextInputKeyboardType? keyboardType;
  final bool? secure;
  final bool? autocorrect;
  final int? size;
  final Color? color;
  final FontDesign? design;
  final FontWeight? weight;
  final TextAlign? textAlign;
  final FrameData? frame;

  UITextInputBlockData({
    this.key,
    this.value,
    this.placeholder,
    this.regex,
    this.errorMessage,
    this.keyboardType,
    this.secure,
    this.autocorrect,
    this.size,
    this.color,
    this.design,
    this.weight,
    this.textAlign,
    this.frame,
  });

  static UITextInputBlockData? decode(dynamic json) {
    if (json == null) {
      return null;
    }
    if (json is! Map<String, dynamic>) {
      return null;
    }

    return UITextInputBlockData(
      key: StringDecoder.decode(json['key']),
      value: StringDecoder.decode(json['value']),
      placeholder: StringDecoder.decode(json['placeholder']),
      regex: StringDecoder.decode(json['regex']),
      errorMessage: UITooltipMessage.decode(json['errorMessage']),
      keyboardType:
          UITextInputKeyboardTypeExtension.decode(json['keyboardType']),
      secure: BooleanDecoder.decode(json['secure']),
      autocorrect: BooleanDecoder.decode(json['autocorrect']),
      size: IntDecoder.decode(json['size']),
      color: Color.decode(json['color']),
      design: FontDesignExtension.decode(json['design']),
      weight: FontWeightExtension.decode(json['weight']),
      textAlign: TextAlignExtension.decode(json['textAlign']),
      frame: FrameData.decode(json['frame']),
    );
  }

  Map<String, dynamic> encode() {
    return {
      '__typename': 'UITextInputBlockData',
      'key': key,
      'value': value,
      'placeholder': placeholder,
      'regex': regex,
      'errorMessage': errorMessage?.encode(),
      'keyboardType': keyboardType?.encode(),
      'secure': secure,
      'autocorrect': autocorrect,
      'size': size,
      'color': color?.encode(),
      'design': design?.encode(),
      'weight': weight?.encode(),
      'textAlign': textAlign?.encode(),
      'frame': frame?.encode(),
    };
  }
}

enum UITextInputKeyboardType {
  // ignore: constant_identifier_names
  DEFAULT,
  // ignore: constant_identifier_names
  ASCII,
  // ignore: constant_identifier_names
  EMAIL,
  // ignore: constant_identifier_names
  DECIMAL,
  // ignore: constant_identifier_names
  NUMBER,
  // ignore: constant_identifier_names
  URI,
  // ignore: constant_identifier_names
  ALPHABET,
  // ignore: constant_identifier_names
  UNKNOWN,
}

extension UITextInputKeyboardTypeExtension on UITextInputKeyboardType {
  static UITextInputKeyboardType? decode(dynamic json) {
    if (json == null) {
      return null;
    }
    if (json is! String) {
      return null;
    }

    switch (json) {
      case 'DEFAULT':
        return UITextInputKeyboardType.DEFAULT;
      case 'ASCII':
        return UITextInputKeyboardType.ASCII;
      case 'EMAIL':
        return UITextInputKeyboardType.EMAIL;
      case 'DECIMAL':
        return UITextInputKeyboardType.DECIMAL;
      case 'NUMBER':
        return UITextInputKeyboardType.NUMBER;
      case 'URI':
        return UITextInputKeyboardType.URI;
      case 'ALPHABET':
        return UITextInputKeyboardType.ALPHABET;
      default:
        return UITextInputKeyboardType.UNKNOWN;
    }
  }

  String? encode() {
    switch (this) {
      case UITextInputKeyboardType.DEFAULT:
        return 'DEFAULT';
      case UITextInputKeyboardType.ASCII:
        return 'ASCII';
      case UITextInputKeyboardType.EMAIL:
        return 'EMAIL';
      case UITextInputKeyboardType.DECIMAL:
        return 'DECIMAL';
      case UITextInputKeyboardType.NUMBER:
        return 'NUMBER';
      case UITextInputKeyboardType.URI:
        return 'URI';
      case UITextInputKeyboardType.ALPHABET:
        return 'ALPHABET';
      case UITextInputKeyboardType.UNKNOWN:
        return null;
    }
  }
}

class UITooltipMessage {
  final String? title;

  UITooltipMessage({
    this.title,
  });

  static UITooltipMessage? decode(dynamic json) {
    if (json == null) {
      return null;
    }
    if (json is! Map<String, dynamic>) {
      return null;
    }

    return UITooltipMessage(
      title: StringDecoder.decode(json['title']),
    );
  }

  Map<String, dynamic> encode() {
    return {
      '__typename': 'UITooltipMessage',
      'title': title,
    };
  }
}

class UITooltipSize {
  final int? width;
  final int? height;

  UITooltipSize({
    this.width,
    this.height,
  });

  static UITooltipSize? decode(dynamic json) {
    if (json == null) {
      return null;
    }
    if (json is! Map<String, dynamic>) {
      return null;
    }

    return UITooltipSize(
      width: IntDecoder.decode(json['width']),
      height: IntDecoder.decode(json['height']),
    );
  }

  Map<String, dynamic> encode() {
    return {
      '__typename': 'UITooltipSize',
      'width': width,
      'height': height,
    };
  }
}

class VariantConfig {
  final String? key;
  final VariantConfigKind? kind;
  final String? value;

  VariantConfig({
    this.key,
    this.kind,
    this.value,
  });

  static VariantConfig? decode(dynamic json) {
    if (json == null) {
      return null;
    }
    if (json is! Map<String, dynamic>) {
      return null;
    }

    return VariantConfig(
      key: StringDecoder.decode(json['key']),
      kind: VariantConfigKindExtension.decode(json['kind']),
      value: StringDecoder.decode(json['value']),
    );
  }

  Map<String, dynamic> encode() {
    return {
      '__typename': 'VariantConfig',
      'key': key,
      'kind': kind?.encode(),
      'value': value,
    };
  }
}

enum VariantConfigKind {
  // ignore: constant_identifier_names
  COMPONENT,
  // ignore: constant_identifier_names
  STRING,
  // ignore: constant_identifier_names
  NUMBER,
  // ignore: constant_identifier_names
  BOOLEAN,
  // ignore: constant_identifier_names
  JSON,
  // ignore: constant_identifier_names
  UNKNOWN,
}

extension VariantConfigKindExtension on VariantConfigKind {
  static VariantConfigKind? decode(dynamic json) {
    if (json == null) {
      return null;
    }
    if (json is! String) {
      return null;
    }

    switch (json) {
      case 'COMPONENT':
        return VariantConfigKind.COMPONENT;
      case 'STRING':
        return VariantConfigKind.STRING;
      case 'NUMBER':
        return VariantConfigKind.NUMBER;
      case 'BOOLEAN':
        return VariantConfigKind.BOOLEAN;
      case 'JSON':
        return VariantConfigKind.JSON;
      default:
        return VariantConfigKind.UNKNOWN;
    }
  }

  String? encode() {
    switch (this) {
      case VariantConfigKind.COMPONENT:
        return 'COMPONENT';
      case VariantConfigKind.STRING:
        return 'STRING';
      case VariantConfigKind.NUMBER:
        return 'NUMBER';
      case VariantConfigKind.BOOLEAN:
        return 'BOOLEAN';
      case VariantConfigKind.JSON:
        return 'JSON';
      case VariantConfigKind.UNKNOWN:
        return null;
    }
  }
}

enum Weekdays {
  // ignore: constant_identifier_names
  SUNDAY,
  // ignore: constant_identifier_names
  MONDAY,
  // ignore: constant_identifier_names
  TUESDAY,
  // ignore: constant_identifier_names
  WEDNESDAY,
  // ignore: constant_identifier_names
  THURSDAY,
  // ignore: constant_identifier_names
  FRIDAY,
  // ignore: constant_identifier_names
  SATURDAY,
  // ignore: constant_identifier_names
  UNKNOWN,
}

extension WeekdaysExtension on Weekdays {
  static Weekdays? decode(dynamic json) {
    if (json == null) {
      return null;
    }
    if (json is! String) {
      return null;
    }

    switch (json) {
      case 'SUNDAY':
        return Weekdays.SUNDAY;
      case 'MONDAY':
        return Weekdays.MONDAY;
      case 'TUESDAY':
        return Weekdays.TUESDAY;
      case 'WEDNESDAY':
        return Weekdays.WEDNESDAY;
      case 'THURSDAY':
        return Weekdays.THURSDAY;
      case 'FRIDAY':
        return Weekdays.FRIDAY;
      case 'SATURDAY':
        return Weekdays.SATURDAY;
      default:
        return Weekdays.UNKNOWN;
    }
  }

  String? encode() {
    switch (this) {
      case Weekdays.SUNDAY:
        return 'SUNDAY';
      case Weekdays.MONDAY:
        return 'MONDAY';
      case Weekdays.TUESDAY:
        return 'TUESDAY';
      case Weekdays.WEDNESDAY:
        return 'WEDNESDAY';
      case Weekdays.THURSDAY:
        return 'THURSDAY';
      case Weekdays.FRIDAY:
        return 'FRIDAY';
      case Weekdays.SATURDAY:
        return 'SATURDAY';
      case Weekdays.UNKNOWN:
        return null;
    }
  }
}
