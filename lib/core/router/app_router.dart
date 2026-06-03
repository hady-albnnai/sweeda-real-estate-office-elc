import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../screens/visitor/home_screen.dart';
import '../../screens/visitor/offer_detail_screen.dart';
import '../../screens/visitor/search_screen.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/auth/otp_verification_screen.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/',
    routes: [
      // Visitor Routes
      GoRoute(
        path: '/',
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
      
      // User Routes (Stubs for now, will be implemented in later phases)
      GoRoute(
        path: '/user/home',
        builder: (context, state) => const Scaffold(body: Center(child: Text('User Home'))),
      ),
      
      // Broker Routes (Stubs)
      GoRoute(
        path: '/broker/dashboard',
        builder: (context, state) => const Scaffold(body: Center(child: Text('Broker Dashboard'))),
      ),
      
      // Admin Routes (Stubs)
      GoRoute(
        path: '/admin/dashboard',
        builder: (context, state) => const Scaffold(body: Center(child: Text('Admin Dashboard'))),
      ),
    ],
  );
}
