import 'dart:convert';

class ConfigModel {
  final Map<String, dynamic> data;
  final DateTime? loadedAt;

  ConfigModel({required this.data, this.loadedAt});

  factory ConfigModel.fromJson(Map<String, dynamic> json) {
    return ConfigModel(data: json, loadedAt: DateTime.now());
  }

  int get signupPoints => _getNested('pts.sgn', 1000);
  int get weeklyLoginPoints => _getNested('pts.wkL', 100);
  int get addOfferPoints => _getNested('pts.addO', 500);
  int get dealDonePoints => _getNested('pts.dlD', 2000);
  int get sellCommission => _getNested('com.sl', 3);
  Map<String, dynamic> get userQuotas => _getNestedMap('qta.u', {'o': 1, 'r': 3, 'a': 3});
  Map<String, dynamic> get brokerQuotas => _getNestedMap('qta.b', {'o': 5, 'r': 5, 'a': 3});
  Map<String, dynamic> get propertyCategories => _getNestedMap('catProp', {});
  Map<String, dynamic> get vehicleCategories => _getNestedMap('catVeh', {});
  Map<String, dynamic> get documentTypes => _getNestedMap('docTp', {});
  Map<String, dynamic> get carDocumentTypes => _getNestedMap('carDocTp', {});
  Map<String, dynamic> get plateTypes => _getNestedMap('plateTp', {});
  List<dynamic> get locations => _getNestedList('locs', []);
  List<dynamic> get brands => _getNestedList('brnds', []);
  List<dynamic> get colors => _getNestedList('clrs', []);
  List<dynamic> get reportReasons => _getNestedList('rptRsn', []);
  Map<String, dynamic> get badges => _getNestedMap('bdg', {});
  Map<String, dynamic> get packages => _getNestedMap('pkg', {});

  /// عدد أيام السماح بعد انتهاء الباقة — يُقرأ من pkg.grace_days (افتراضي: 3)
  int get pkgGraceDays {
    final pkgMap = packages;
    final val = pkgMap['grace_days'];
    if (val is num) return val.toInt();
    return 3; // fallback آمن
  }

  Map<String, dynamic> get texts => _getNestedMap('txts', {});
  int get usdToSypRate => _getNested('fx.usd_syp', 15000);

  /// قنوات الدفع اليدوية (المرحلة 11)
  /// المفاتيح: haram | sham_cash | balance | bank
  /// كل قناة تحوي: enabled, name, icon, instructions + حقول خاصة بها
  Map<String, dynamic> get payChannels => _getNestedMap('payChannels', {});

  /// قائمة القنوات المفعّلة فقط (للعرض في شاشة الدفع)
  List<MapEntry<String, Map<String, dynamic>>> get enabledPayChannels {
    final all = payChannels;
    final result = <MapEntry<String, Map<String, dynamic>>>[];
    all.forEach((key, value) {
      if (value is Map && value['enabled'] == true) {
        result.add(MapEntry(key, Map<String, dynamic>.from(value)));
      }
    });
    return result;
  }

  int _getNested(String path, int defaultValue) {
    dynamic value = data;
    for (final key in path.split('.')) {
      if (value is Map && value.containsKey(key)) {
        value = value[key];
      } else return defaultValue;
    }
    return (value is num) ? value.toInt() : defaultValue;
  }

  Map<String, dynamic> _getNestedMap(String path, Map<String, dynamic> defaultValue) {
    dynamic value = data;
    for (final key in path.split('.')) {
      if (value is Map && value.containsKey(key)) {
        value = value[key];
      } else return defaultValue;
    }
    return (value is Map) ? Map<String, dynamic>.from(value) : defaultValue;
  }

  List<dynamic> _getNestedList(String path, List<dynamic> defaultValue) {
    dynamic value = data;
    for (final key in path.split('.')) {
      if (value is Map && value.containsKey(key)) {
        value = value[key];
      } else return defaultValue;
    }
    return (value is List) ? value : defaultValue;
  }

  String toJson() => jsonEncode(data);
}
