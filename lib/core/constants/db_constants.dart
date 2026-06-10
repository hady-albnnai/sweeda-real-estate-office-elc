/// أسماء الجداول في Supabase
class DbTables {
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
  static const String appConfig = 'app_config';
  static const String otpCodes = 'otp_codes';
  static const String userDevices = 'user_devices';
  static const String photographyTasks = 'photography_tasks';
}

/// أسماء دوال PostgreSQL
class DbFunctions {
  static const String generateOtp = 'generate_otp';
  static const String verifyOtp = 'verify_otp';
  static const String upsertUserAfterOtp = 'upsert_user_after_otp';
  static const String getUserByEmail = 'get_user_by_email';
  static const String getUserByPhone = 'get_user_by_phone';
  static const String checkOfferDuplicate = 'check_offer_duplicate';
  static const String calculateCommission = 'calculate_commission';
  static const String updateUserBadge = 'update_user_badge';
  static const String getPendingOffersCount = 'get_pending_offers_count';
  static const String addPoints = 'add_points';
  static const String awardPointsSafe = 'award_points_safe';
  static const String approvePaymentFinal = 'approve_payment_final';
  static const String expireOffers = 'expire_offers';
  static const String sendAppointmentReminders = 'send_appointment_reminders';
  static const String createUserFromPhone = 'create_user_from_phone';
  // === المرحلة 10: stats triggers + إحالة + تسجيل دخول أسبوعي ===
  static const String registerWeeklyLogin = 'register_weekly_login';
  static const String applyReferral = 'apply_referral';
  // === المرحلة C: ترقيات العروض (spd) ===
  static const String purchaseOfferBoost = 'purchase_offer_boost';
  static const String expireOfferBoosts = 'expire_offer_boosts';
  // === المرحلة E2: Firebase FCM ===
  static const String getUserDeviceTokens = 'get_user_device_tokens';
  static const String notifyUser = 'notify_user';
  // === المرحلة E2+: ربط الإشعارات بالأحداث ===
  static const String sendPushNotification = 'send_push_notification';
  // ملاحظة: trg_* triggers تعمل تلقائياً من السيرفر — لا تُستدعى من Flutter
  // تفعّل عند: تغيير offer.sts/i_pub, INSERT/UPDATE appointment, UPDATE deal.sts, UPDATE payment.sts
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

/// حالات العرض
class OfferStatus {
  static const int draft = 0;
  static const int review = 1;
  static const int published = 2;
  static const int rejected = 3;
  static const int expired = 4;
  static const int reserved = 5;
  static const int completed = 6;
}

/// حالات المستخدم
class UserStatus {
  static const int active = 0;
  static const int frozen = 1;
  static const int banned = 2;
}

/// الأدوار
class UserRole {
  static const int user = 0;
  static const int broker = 1;
  static const int supervisor = 2;
  static const int deputy = 3;
  static const int manager = 4;
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

/// نوع العملة
class Currency {
  static const int dollar = 0;
  static const int lbp = 1;
}
