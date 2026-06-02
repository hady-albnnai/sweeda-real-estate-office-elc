/// أسماء مجموعات Firestore (Collection names)
/// استخدام أسماء قصيرة لتقليل حجم البيانات
class FirestoreCollections {
  static const String config = 'config';
  static const String users = 'users';
  static const String offers = 'offers';
  static const String requests = 'requests';
  static const String appointments = 'appointments';
  static const String notifications = 'notifications';
  static const String payments = 'payments';
  static const String reports = 'reports';
  static const String deals = 'deals';
  static const String activityLog = 'activity_log';
  static const String stats = 'stats';
}

/// مفاتيح Config
class ConfigKeys {
  static const String main = 'main';
  static const String pts = 'pts';
  static const String pen = 'pen';
  static const String spd = 'spd';
  static const String bdg = 'bdg';
  static const String pkg = 'pkg';
  static const String com = 'com';
  static const String qta = 'qta';
  static const String soc = 'soc';
  static const String ads = 'ads';
  static const String rptRsn = 'rptRsn';
  static const String txts = 'txts';
  static const String catProp = 'catProp';
  static const String catVeh = 'catVeh';
  static const String docTp = 'docTp';
  static const String locs = 'locs';
  static const String brnds = 'brnds';
  static const String clrs = 'clrs';
  static const String roles = 'roles';
}

/// حالات العرض (Offer Status)
class OfferStatus {
  static const int draft = 0;         // مسودة
  static const int review = 1;        // قيد المراجعة
  static const int published = 2;     // منشور
  static const int rejected = 3;      // مرفوض
  static const int expired = 4;       // منتهي
  static const int reserved = 5;      // محجوز
  static const int completed = 6;     // مكتمل
}

/// حالات المستخدم
class UserStatus {
  static const int active = 0;
  static const int frozen = 1;
  static const int banned = 2;
}

/// الأدوار
class UserRole {
  static const int user = 0;       // مستخدم
  static const int broker = 1;     // وسيط
  static const int supervisor = 2; // مشرف
  static const int deputy = 3;     // نائب
  static const int manager = 4;    // مدير
}

/// أنواع البادجات
class BadgeLevel {
  static const int newUser = 0;
  static const int bronze = 1;
  static const int silver = 2;
  static const int gold = 3;
  static const int diamond = 4;
}

/// أنواع الباقات
class PackageType {
  static const int free = 0;
  static const int silver = 1;
  static const int gold = 2;
}

/// أنواع الإشعارات
class NotificationType {
  static const int offers = 0;
  static const int requests = 1;
  static const int appointments = 2;
  static const int finance = 3;
  static const int account = 4;
  static const int rating = 5;
}
