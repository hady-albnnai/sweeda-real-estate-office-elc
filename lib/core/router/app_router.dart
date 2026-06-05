import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
import '../../screens/user/settings_screen.dart';
import '../../screens/user/notifications_screen.dart';
import '../../screens/user/add_request_screen.dart';
import '../../screens/user/packages_screen.dart';
import '../../screens/user/payment_screen.dart';
import '../../screens/user/edit_offer_screen.dart';
import '../../screens/user/become_broker_screen.dart';
import '../../screens/user/request_detail_screen.dart';
import '../../screens/user/referral_screen.dart';
import '../../screens/user/boost_offer_screen.dart';

// === Broker ===
import '../../screens/broker/broker_dashboard_screen.dart';
import '../../screens/broker/broker_offers_screen.dart';
import '../../screens/broker/broker_appointments_screen.dart';
import '../../screens/broker/broker_deals_screen.dart';
import '../../screens/broker/broker_stats_screen.dart';

// === Admin ===
import '../../screens/admin/admin_dashboard_screen.dart';
import '../../screens/admin/users_management_screen.dart';
import '../../screens/admin/offers_review_screen.dart';
import '../../screens/admin/appointments_management_screen.dart';
import '../../screens/admin/deals_management_screen.dart';
import '../../screens/admin/payments_screen.dart';
import '../../screens/admin/reports_screen.dart';
import '../../screens/admin/config_editor_screen.dart';
import '../../screens/admin/analytics_screen.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/splash',
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
          final amt =
              double.tryParse(state.uri.queryParameters['amt'] ?? '0') ?? 0;
          return PaymentScreen(packageId: pkg, amount: amt);
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
      // 🛡️ ADMIN (إدارة)
      // ═══════════════════════════════════════
      GoRoute(
        path: '/admin/dashboard',
        builder: (context, state) => const AdminDashboardScreen(),
      ),
      GoRoute(
        path: '/admin/users',
        builder: (context, state) => const UsersManagementScreen(),
      ),
      GoRoute(
        path: '/admin/review-offers',
        builder: (context, state) => const OffersReviewScreen(),
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
        path: '/admin/config',
        builder: (context, state) => const ConfigEditorScreen(),
      ),
      GoRoute(
        path: '/admin/analytics',
        builder: (context, state) => const AnalyticsScreen(),
      ),
    ],
  );
}
