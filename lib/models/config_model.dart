import 'dart:convert';

/// نموذج Config — يُحمّل من Firestore عند بدء التشغيل
class ConfigModel {
  final Map<String, dynamic> data;
  final DateTime? loadedAt;

  ConfigModel({required this.data, this.loadedAt});

  factory ConfigModel.fromJson(Map<String, dynamic> json) {
    return ConfigModel(data: json, loadedAt: DateTime.now());
  }

  // --- نقاط الاكتساب ---
  int get signupPoints => _getNested('pts.sgn', 1000);
  int get weeklyLoginPoints => _getNested('pts.wkL', 500);
  int get addOfferPoints => _getNested('pts.addO', 500);
  int get attendancePoints => _getNested('pts.att', 300);
  int get dealDonePoints => _getNested('pts.dlD', 2000);

  // --- العقوبات ---
  int get noShowPenalty => _getNested('pen.noSh', -500);
  int get banPenalty => _getNested('pen.ban', -40000);

  // --- العمولة ---
  int get sellCommission => _getNested('com.sl', 3);
  int get matchingMultiplier => _getNested('com.ml', 2);

  // --- الحدود ---
  Map<String, dynamic> get userQuotas => _getNestedMap('qta.u', {'o': 1, 'r': 3, 'a': 3});
  Map<String, dynamic> get brokerQuotas => _getNestedMap('qta.b', {'o': 5, 'r': 5, 'a': 3});

  // --- الأنواع ---
  Map<String, dynamic> get propertyCategories => _getNestedMap('catProp', {});
  Map<String, dynamic> get vehicleCategories => _getNestedMap('catVeh', {});
  Map<String, dynamic> get documentTypes => _getNestedMap('docTp', {});
  List<dynamic> get locations => _getNestedList('locs', []);
  List<dynamic> get brands => _getNestedList('brnds', []);
  List<dynamic> get colors => _getNestedList('clrs', []);
  List<dynamic> get reportReasons => _getNestedList('rptRsn', []);

  // --- البادجات ---
  Map<String, dynamic> get badges => _getNestedMap('bdg', {});

  // --- الباقات ---
  Map<String, dynamic> get packages => _getNestedMap('pkg', {});

  // --- النصوص ---
  Map<String, dynamic> get texts => _getNestedMap('txts', {});

  // --- أدوات الوصول المتداخل ---
  int _getNested(String path, int defaultValue) {
    final keys = path.split('.');
    dynamic value = data;
    for (final key in keys) {
      if (value is Map && value.containsKey(key)) {
        value = value[key];
      } else {
        return defaultValue;
      }
    }
    return (value is num) ? value.toInt() : defaultValue;
  }

  Map<String, dynamic> _getNestedMap(String path, Map<String, dynamic> defaultValue) {
    final keys = path.split('.');
    dynamic value = data;
    for (final key in keys) {
      if (value is Map && value.containsKey(key)) {
        value = value[key];
      } else {
        return defaultValue;
      }
    }
    return Map<String, dynamic>.from(value as Map);
  }

  List<dynamic> _getNestedList(String path, List<dynamic> defaultValue) {
    final keys = path.split('.');
    dynamic value = data;
    for (final key in keys) {
      if (value is Map && value.containsKey(key)) {
        value = value[key];
      } else {
        return defaultValue;
      }
    }
    return (value as List);
  }

  String toJson() => jsonEncode(data);
}