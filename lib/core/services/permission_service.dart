import '../../models/user_model.dart';

class PermissionKeys {
  static const adminDashboard = 'admin_dashboard';
  static const officeOperations = 'office_operations';
  static const manageUsers = 'manage_users';
  static const managePermissions = 'manage_permissions';
  static const reviewOffers = 'review_offers';
  static const reviewVerifications = 'review_verifications';
  static const mediaReview = 'media_review';
  static const photographyManagement = 'photography_management';
  static const photographerTasks = 'photographer_tasks';
  static const fraudSuspects = 'fraud_suspects';
  static const manageAppointments = 'manage_appointments';
  static const manageDeals = 'manage_deals';
  static const managePayments = 'manage_payments';
  static const manageReports = 'manage_reports';
  static const manageConfig = 'manage_config';
  static const viewAnalytics = 'view_analytics';
  static const brokerDashboard = 'broker_dashboard';
  static const brokerOffers = 'broker_offers';
  static const brokerAppointments = 'broker_appointments';
  static const brokerDeals = 'broker_deals';
  static const brokerStats = 'broker_stats';
  static const userHome = 'user_home';
  static const userOffers = 'user_offers';
  static const userRequests = 'user_requests';
  static const userAppointments = 'user_appointments';
  static const userProfile = 'user_profile';
}

class AppPermission {
  final String key;
  final String title;
  final String group;
  final int minimumRoleForDefault;

  const AppPermission({
    required this.key,
    required this.title,
    required this.group,
    required this.minimumRoleForDefault,
  });
}

class PermissionService {
  static const permissions = <AppPermission>[
    AppPermission(key: PermissionKeys.adminDashboard, title: 'لوحة الإدارة', group: 'الإدارة', minimumRoleForDefault: 2),
    AppPermission(key: PermissionKeys.officeOperations, title: 'عمليات المكتب', group: 'الإدارة', minimumRoleForDefault: 2),
    AppPermission(key: PermissionKeys.manageUsers, title: 'إدارة المستخدمين', group: 'الإدارة', minimumRoleForDefault: 2),
    AppPermission(key: PermissionKeys.managePermissions, title: 'إدارة الصلاحيات', group: 'الإدارة', minimumRoleForDefault: 3),
    AppPermission(key: PermissionKeys.reviewOffers, title: 'مراجعة العروض', group: 'الإدارة', minimumRoleForDefault: 2),
    AppPermission(key: PermissionKeys.reviewVerifications, title: 'طلبات التوثيق', group: 'الإدارة', minimumRoleForDefault: 2),
    AppPermission(key: PermissionKeys.mediaReview, title: 'إدارة الوسائط والتصوير', group: 'الإدارة', minimumRoleForDefault: 2),
    AppPermission(key: PermissionKeys.photographyManagement, title: 'إدارة مهام التصوير', group: 'التصوير', minimumRoleForDefault: 2),
    AppPermission(key: PermissionKeys.photographerTasks, title: 'مهام المصور', group: 'التصوير', minimumRoleForDefault: 99),
    AppPermission(key: PermissionKeys.fraudSuspects, title: 'كشف الاحتيال', group: 'الإدارة', minimumRoleForDefault: 2),
    AppPermission(key: PermissionKeys.manageAppointments, title: 'إدارة المواعيد', group: 'التشغيل', minimumRoleForDefault: 2),
    AppPermission(key: PermissionKeys.manageDeals, title: 'إدارة الصفقات', group: 'التشغيل', minimumRoleForDefault: 2),
    AppPermission(key: PermissionKeys.managePayments, title: 'إدارة المدفوعات', group: 'التشغيل', minimumRoleForDefault: 2),
    AppPermission(key: PermissionKeys.manageReports, title: 'التبليغات', group: 'التشغيل', minimumRoleForDefault: 2),
    AppPermission(key: PermissionKeys.manageConfig, title: 'إعدادات التطبيق', group: 'الإعدادات', minimumRoleForDefault: 4),
    AppPermission(key: PermissionKeys.viewAnalytics, title: 'التحليلات', group: 'الإدارة', minimumRoleForDefault: 2),
    AppPermission(key: PermissionKeys.brokerDashboard, title: 'لوحة الوسيط', group: 'الوسيط', minimumRoleForDefault: 1),
    AppPermission(key: PermissionKeys.brokerOffers, title: 'عروض الوسيط', group: 'الوسيط', minimumRoleForDefault: 1),
    AppPermission(key: PermissionKeys.brokerAppointments, title: 'مواعيد الوسيط', group: 'الوسيط', minimumRoleForDefault: 1),
    AppPermission(key: PermissionKeys.brokerDeals, title: 'صفقات الوسيط', group: 'الوسيط', minimumRoleForDefault: 1),
    AppPermission(key: PermissionKeys.brokerStats, title: 'إحصائيات الوسيط', group: 'الوسيط', minimumRoleForDefault: 1),
    AppPermission(key: PermissionKeys.userHome, title: 'واجهة المستخدم', group: 'المستخدم', minimumRoleForDefault: 0),
    AppPermission(key: PermissionKeys.userOffers, title: 'عروضي', group: 'المستخدم', minimumRoleForDefault: 0),
    AppPermission(key: PermissionKeys.userRequests, title: 'طلباتي', group: 'المستخدم', minimumRoleForDefault: 0),
    AppPermission(key: PermissionKeys.userAppointments, title: 'مواعيدي', group: 'المستخدم', minimumRoleForDefault: 0),
    AppPermission(key: PermissionKeys.userProfile, title: 'الملف الشخصي', group: 'المستخدم', minimumRoleForDefault: 0),
  ];

  static List<String> defaultsForRole(int role) {
    return permissions
        .where((permission) => role >= permission.minimumRoleForDefault)
        .map((permission) => permission.key)
        .toList(growable: false);
  }

  static List<String> effectivePermissions(UserModel? user) {
    if (user == null) return const [];
    if (user.perm.isNotEmpty) return user.perm;
    return defaultsForRole(user.role);
  }

  static bool has(UserModel? user, String permission) {
    return effectivePermissions(user).contains(permission);
  }

  static Map<String, List<AppPermission>> grouped() {
    final map = <String, List<AppPermission>>{};
    for (final permission in permissions) {
      map.putIfAbsent(permission.group, () => <AppPermission>[]).add(permission);
    }
    return map;
  }
}
