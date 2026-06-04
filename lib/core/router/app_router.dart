import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../screens/splash_screen.dart';
import '../screens/visitor/home_screen.dart';
import '../screens/visitor/offer_detail_screen.dart';
import '../screens/visitor/search_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/otp_verification_screen.dart';
import '../screens/admin/offers_review_screen.dart';
import '../screens/broker/broker_appointments_screen.dart';
import '../screens/user/my_offers_screen.dart';
import '../screens/user/add_offer_screen.dart';
import '../screens/auth/setup_profile_screen.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/splash',
    routes: [
      // Splash Screen
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),

      // Visitor Routes
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

      // Auth Routes
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

      // User Routes
      GoRoute(
        path: '/user/home',
        builder: (context, state) => const Scaffold(body: Center(child: Text('User Home'))),
      ),
      GoRoute(
        path: '/user/my-offers',
        builder: (context, state) => const MyOffersScreen(),
      ),
      GoRoute(
        path: '/user/add-offer',
        builder: (context, state) => const AddOfferScreen(),
      ),

      // Broker Routes
      GoRoute(
        path: '/broker/dashboard',
        builder: (context, state) => const Scaffold(body: Center(child: Text('Broker Dashboard'))),
      ),
      GoRoute(
        path: '/broker/appointments',
        builder: (context, state) => const BrokerAppointmentsScreen(),
      ),

      // Admin Routes
      GoRoute(
        path: '/admin/dashboard',
        builder: (context, state) => const Scaffold(body: Center(child: Text('Admin Dashboard'))),
      ),
      GoRoute(
        path: '/admin/review-offers',
        builder: (context, state) => const OffersReviewScreen(),
      ),
    ],
  );
}
