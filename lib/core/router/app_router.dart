import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

// === Splash ===
import '../../screens/splash_screen.dart';

// === Visitor ===
import '../../screens/visitor/home_screen.dart';
import '../../screens/visitor/offer_detail_screen.dart';
import '../../screens/visitor/search_screen.dart';

// === Auth ===
import '../../screens/auth/login_screen.dart';
import '../../screens/auth/otp_verification_screen.dart';
import '../../screens/auth/setup_profile_screen.dart';
import '../../screens/auth/check_email_screen.dart';

// === User ===
import '../../screens/user/user_home_screen.dart';
import '../../screens/user/my_offers_screen.dart';
import '../../screens/user/add_offer_screen.dart';
import '../../screens/user/my_requests_screen.dart';
import '../../screens/user/my_appointments_screen.dart';
import '../../screens/user/favorites_screen.dart';
import '../../screens/user/profile_screen.dart';
import '../../screens/user/account_info_screen.dart';
import '../../screens/user/settings_screen.dart';
import '../../screens/user/notifications_screen.dart';
import '../../screens/user/add_request_screen.dart';
import '../../screens/user/packages_screen.dart';
import '../../screens/user/payment_screen.dart';
import '../../screens/user/edit_offer_screen.dart';
import '../../screens/user/become_broker_screen.dart';
import '../../screens/user/request_detail_screen.dart';
import '../../screens/user/referral_screen.dart';
import '../../screens/user/my_ratings_screen.dart';
import '../../screens/user/my_payments_screen.dart';
import '../../screens/user/boost_offer_screen.dart';

// === Broker ===
import '../../screens/broker/broker_dashboard_screen.dart';
import '../../screens/broker/broker_offers_screen.dart';
import '../../screens/broker/broker_appointments_screen.dart';
import '../../screens/broker/broker_deals_screen.dart';
import '../../screens/broker/broker_stats_screen.dart';
import '../../screens/photographer/photographer_tasks_screen.dart';

// === Executor ===
import '../../screens/executor/my_tasks_screen.dart';
import '../../screens/executor/execute_task_screen.dart';

// === Employee ===
import '../../screens/employee/employee_home_screen.dart';

// === Admin ===
import '../../screens/admin/admin_dashboard_screen.dart';
import '../../screens/admin/admin_add_offer_screen.dart';
import '../../screens/admin/requests_management_screen.dart';
import '../../screens/admin/completion_requests_screen.dart';
import '../../screens/admin/office_operations_screen.dart';
import '../../screens/admin/permissions_management_screen.dart';
import '../../screens/admin/users_management_screen.dart';
import '../../screens/admin/user_details_screen.dart';
import '../../screens/admin/offers_review_screen.dart';
import '../../screens/admin/media_review_screen.dart';
import '../../screens/admin/photography_management_screen.dart';
import '../../screens/admin/verifications_review_screen.dart';
import '../../screens/admin/fraud_suspects_screen.dart';
import '../../screens/admin/appointments_management_screen.dart';
import '../../screens/admin/deals_management_screen.dart';
import '../../screens/admin/payments_screen.dart';
import '../../screens/admin/reports_screen.dart';
import '../../screens/admin/config_editor_screen.dart';
import '../../screens/admin/analytics_screen.dart';
import '../../providers/auth_provider.dart';
import '../services/permission_service.dart';

class AppRouter {
  static String? _adminRoutePermission(String path) {
    if (path == '/admin/dashboard') return null;
    if (path == '/admin/office-operations') return PermissionKeys.officeOperations;
    if (path == '/admin/permissions') return PermissionKeys.managePermissions;
    if (path.startsWith('/admin/users') || path.startsWith('/admin/user/')) return PermissionKeys.manageUsers;
    if (path == '/admin/review-offers') return PermissionKeys.reviewOffers;
    if (path == '/admin/add-offer')   return PermissionKeys.reviewOffers;
    if (path == '/admin/requests')    return PermissionKeys.manageRequests;
    if (path == '/admin/review-verifications') return PermissionKeys.reviewVerifications;
    if (path == '/admin/media-review') return PermissionKeys.mediaReview;
    if (path == '/admin/photography-management') return PermissionKeys.photographyManagement;
    if (path == '/admin/fraud-suspects') return PermissionKeys.fraudSuspects;
    if (path == '/admin/appointments') return PermissionKeys.manageAppointments;
    if (path == '/admin/deals') return PermissionKeys.manageDeals;
    if (path == '/admin/payments') return PermissionKeys.managePayments;
    if (path == '/admin/reports') return PermissionKeys.manageReports;
    if (path == '/admin/config') return PermissionKeys.manageConfig;
    if (path == '/admin/analytics') return PermissionKeys.viewAnalytics;
    if (path == '/admin/completion-requests') return PermissionKeys.completionRequests;
    return null;
  }

  static String? _brokerRoutePermission(String path) {
    if (path == '/broker/dashboard') return PermissionKeys.brokerDashboard;
    if (path == '/broker/offers') return PermissionKeys.brokerOffers;
    if (path == '/broker/appointments') return PermissionKeys.brokerAppointments;
    if (path == '/broker/deals') return PermissionKeys.brokerDeals;
    if (path == '/broker/stats') return PermissionKeys.brokerStats;
    return null;
  }


  static String? _userRoutePermission(String path) {
    if (path == '/user/home') return PermissionKeys.userHome;
    if (path == '/user/my-offers' ||
        path == '/user/add-offer' ||
        path.startsWith('/user/edit-offer/') ||
        path.startsWith('/user/boost-offer/')) {
      return PermissionKeys.userOffers;
    }
    if (path == '/user/my-requests' ||
        path == '/user/add-request' ||
        path.startsWith('/user/request/')) {
      return PermissionKeys.userRequests;
    }
    if (path == '/user/my-appointments') return PermissionKeys.userAppointments;
    if (path == '/user/profile' ||
        path == '/user/account-info' ||
        path == '/user/settings' ||
        path == '/user/notifications' ||
        path == '/user/packages' ||
        path == '/user/payment' ||
        path == '/user/become-broker' ||
        path == '/user/referral' ||
        path == '/user/my-ratings' ||
        path == '/user/my-payments' ||
        path == '/user/favorites') {
      return PermissionKeys.userProfile;
    }
    return null;
  }

  static final GoRouter router = GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final path = state.uri.path;

      // السبلاش والصفحات العامة تبقى متاحة دائماً.
      final isPublicPath = path == '/splash' ||
          path == '/home' ||
          path == '/search' ||
          path.startsWith('/offer/') ||
          path == '/login' ||
          path == '/otp' ||
          path == '/check-email';
      if (isPublicPath) return null;

      final auth = context.read<AuthProvider>();
      final isLoggedIn = auth.isLoggedIn;

      if (!isLoggedIn) {
        return '/login';
      }

      // إكمال الملف الشخصي مسموح للمستخدم الجديد فقط بعد تسجيل الدخول.
      if (path == '/setup-profile') return null;

      if (path.startsWith('/admin')) {
        // موظف المكتب فما فوق (role >= 4) — المشرف والمصور لا يصلون
        if (!(auth.isEmployee || auth.isSenior)) {
          return auth.isBroker ? '/broker/dashboard' : '/user/home';
        }
        final requiredPermission = _adminRoutePermission(path);
        if (requiredPermission != null &&
            !PermissionService.has(auth.userModel, requiredPermission)) {
          return '/admin/dashboard';
        }
      }

      if (path.startsWith('/broker')) {
        final requiredPermission = _brokerRoutePermission(path);
        if (!(auth.isBroker || auth.isAdmin) ||
            (requiredPermission != null &&
                !PermissionService.has(auth.userModel, requiredPermission))) {
          return '/user/home';
        }
      }

      if (path.startsWith('/employee')) {
        if (!auth.isEmployee && !auth.isSenior) {
          return '/user/home';
        }
      }

      if (path.startsWith('/executor')) {
        // المنفذ = مشرف ميداني (role=3) أو من لديه صلاحية إدارية
        if (!auth.isAdmin && !auth.isSupervisor) {
          return '/user/home';
        }
      }

      if (path.startsWith('/photographer')) {
        // المصور يصل إذا كان role = photographer أو لديه صلاحية مهام المصور
        if (!auth.isPhotographer &&
            !PermissionService.has(auth.userModel, PermissionKeys.photographerTasks)) {
          return '/home';
        }
      }

      if (path.startsWith('/user')) {
        // منع الإدارة من شاشات الباقات/الدفع/الإحالة
        if (auth.isAdmin && (
            path == '/user/packages' ||
            path == '/user/payment' ||
            path == '/user/referral' ||
            path == '/user/my-payments')) {
          return auth.isSenior ? '/admin/dashboard' : '/employee/home';
        }
        final requiredPermission = _userRoutePermission(path);
        if (requiredPermission != null &&
            !PermissionService.has(auth.userModel, requiredPermission)) {
          return '/home';
        }
      }

      return null;
    },
    routes: [
      // ═══════════════════════════════════════
      // 🎬 SPLASH
      // ═══════════════════════════════════════
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),

      // ═══════════════════════════════════════
      // 🌐 VISITOR (زائر)
      // ═══════════════════════════════════════
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/search',
        builder: (context, state) => const SearchScreen(),
      ),
      GoRoute(
        path: '/offer/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return OfferDetailScreen(offerId: id);
        },
      ),

      // ═══════════════════════════════════════
      // 🔐 AUTH (مصادقة)
      // ═══════════════════════════════════════
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/otp',
        builder: (context, state) => const OtpVerificationScreen(),
      ),
      GoRoute(
        path: '/setup-profile',
        builder: (context, state) => const SetupProfileScreen(),
      ),
      GoRoute(
        path: '/check-email',
        builder: (context, state) => const CheckEmailScreen(),
      ),

      // ═══════════════════════════════════════
      // 👤 USER (مستخدم) — ✅ كامل
      // ═══════════════════════════════════════
      GoRoute(
        path: '/user/home',
        builder: (context, state) => const UserHomeScreen(),
      ),
      GoRoute(
        path: '/user/my-offers',
        builder: (context, state) => const MyOffersScreen(),
      ),
      GoRoute(
        path: '/user/add-offer',
        builder: (context, state) => const AddOfferScreen(),
      ),
      GoRoute(
        path: '/user/my-requests',
        builder: (context, state) => const MyRequestsScreen(),
      ),
      GoRoute(
        path: '/user/add-request',
        builder: (context, state) => const AddRequestScreen(),
      ),
      GoRoute(
        path: '/user/my-appointments',
        builder: (context, state) => const MyAppointmentsScreen(),
      ),
      GoRoute(
        path: '/user/favorites',
        builder: (context, state) => const FavoritesScreen(),
      ),
      GoRoute(
        path: '/user/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/user/account-info',
        builder: (context, state) => const AccountInfoScreen(),
      ),
      GoRoute(
        path: '/user/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/user/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/user/packages',
        builder: (context, state) => const PackagesScreen(),
      ),
      GoRoute(
        path: '/user/payment',
        builder: (context, state) {
          final pkg = int.tryParse(state.uri.queryParameters['pkg'] ?? '0') ?? 0;
          // amt لا يُستخدم بعد الآن — السعر يُجلب من Config في PaymentScreen
          return PaymentScreen(packageId: pkg);
        },
      ),
      GoRoute(
        path: '/user/edit-offer/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return EditOfferScreen(offerId: id);
        },
      ),
      GoRoute(
        path: '/user/become-broker',
        builder: (context, state) => const BecomeBrokerScreen(),
      ),
      GoRoute(
        path: '/user/request/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return RequestDetailScreen(requestId: id);
        },
      ),
      GoRoute(
        path: '/user/referral',
        builder: (context, state) => const ReferralScreen(),
      ),
      GoRoute(
        path: '/user/my-ratings',
        builder: (context, state) => const MyRatingsScreen(),
      ),
      GoRoute(
        path: '/user/my-payments',
        builder: (context, state) => const MyPaymentsScreen(),
      ),
      GoRoute(
        path: '/user/boost-offer/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return BoostOfferScreen(offerId: id);
        },
      ),

      // ═══════════════════════════════════════
      // 🤝 BROKER (وسيط/سمسار)
      // ═══════════════════════════════════════
      GoRoute(
        path: '/broker/dashboard',
        builder: (context, state) => const BrokerDashboardScreen(),
      ),
      GoRoute(
        path: '/broker/offers',
        builder: (context, state) => const BrokerOffersScreen(),
      ),
      GoRoute(
        path: '/broker/appointments',
        builder: (context, state) => const BrokerAppointmentsScreen(),
      ),
      GoRoute(
        path: '/broker/deals',
        builder: (context, state) => const BrokerDealsScreen(),
      ),
      GoRoute(
        path: '/broker/stats',
        builder: (context, state) => const BrokerStatsScreen(),
      ),

      // ═══════════════════════════════════════
      // 📸 PHOTOGRAPHER
      // ═══════════════════════════════════════
      GoRoute(
        path: '/photographer/tasks',
        builder: (context, state) => const PhotographerTasksScreen(),
      ),

      // ═══════════════════════════════════════
      // 🏢 EMPLOYEE (موظف المكتب)
      // ═══════════════════════════════════════
      GoRoute(
        path: '/employee/home',
        builder: (context, state) => const EmployeeHomeScreen(),
      ),

      // ═══════════════════════════════════════
      // 👷 EXECUTOR (المنفذ الميداني)
      // ═══════════════════════════════════════
      GoRoute(
        path: '/executor/tasks',
        builder: (context, state) => const MyTasksScreen(),
      ),
      GoRoute(
        path: '/executor/execute/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return ExecuteTaskScreen(appointmentId: id);
        },
      ),

      // ═══════════════════════════════════════
      // 🛡️ ADMIN (إدارة)
      // ═══════════════════════════════════════
      GoRoute(
        path: '/admin/dashboard',
        builder: (context, state) => const AdminDashboardScreen(),
      ),
      GoRoute(
        path: '/admin/office-operations',
        builder: (context, state) => const OfficeOperationsScreen(),
      ),
      GoRoute(
        path: '/admin/permissions',
        builder: (context, state) => const PermissionsManagementScreen(),
      ),
      GoRoute(
        path: '/admin/users',
        builder: (context, state) => const UsersManagementScreen(),
      ),
      GoRoute(
        path: '/admin/user/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return UserDetailsScreen(userId: id);
        },
      ),
      GoRoute(
        path: '/admin/review-offers',
        builder: (context, state) => const OffersReviewScreen(),
      ),
      GoRoute(
        path: '/admin/add-offer',
        builder: (context, state) => const AdminAddOfferScreen(),
      ),
      GoRoute(
        path: '/admin/photography-management',
        builder: (context, state) => const PhotographyManagementScreen(),
      ),
      GoRoute(
        path: '/admin/media-review',
        builder: (context, state) => const MediaReviewScreen(),
      ),
      GoRoute(
        path: '/admin/review-verifications',
        builder: (context, state) => const VerificationsReviewScreen(),
      ),
      GoRoute(
        path: '/admin/fraud-suspects',
        builder: (context, state) => const FraudSuspectsScreen(),
      ),
      GoRoute(
        path: '/admin/appointments',
        builder: (context, state) => const AppointmentsManagementScreen(),
      ),
      GoRoute(
        path: '/admin/deals',
        builder: (context, state) => const DealsManagementScreen(),
      ),
      GoRoute(
        path: '/admin/payments',
        builder: (context, state) => const PaymentsScreen(),
      ),
      GoRoute(
        path: '/admin/reports',
        builder: (context, state) => const ReportsScreen(),
      ),
      GoRoute(
        path: '/admin/requests',
        builder: (context, state) => const RequestsManagementScreen(),
      ),
      GoRoute(
        path: '/admin/config',
        builder: (context, state) => const ConfigEditorScreen(),
      ),
      GoRoute(
        path: '/admin/analytics',
        builder: (context, state) => const AnalyticsScreen(),
      ),
      GoRoute(
        path: '/admin/completion-requests',
        builder: (context, state) => const CompletionRequestsScreen(),
      ),
    ],
  );
}
