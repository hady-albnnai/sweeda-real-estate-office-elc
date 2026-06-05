import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/network/supabase_service.dart';
import 'providers/auth_provider.dart';
import 'providers/config_provider.dart';
import 'providers/offer_provider.dart';
import 'providers/request_provider.dart';
import 'providers/appointment_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/payment_provider.dart';
import 'providers/admin_provider.dart';
import 'providers/broker_provider.dart';
import 'services/notification_service.dart';

/// Supabase Configuration
const String supabaseUrl = 'https://vsgkgnjtebjxyqwpuopz.supabase.co';
const String supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZzZ2tnbmp0ZWJqeHlxd3B1b3B6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA1NzA1MzYsImV4cCI6MjA5NjE0NjUzNn0.1i81x_ne8_AciPMWaRxc-8Z-no-lXudLATKcE0A4tUw';

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _initialized = false;
  String? _initError;
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  /// يستمع لتغيرات auth — ينفّذ تلقائياً تسجيل دخول الإيميل
  /// بعد ما يفتح المستخدم الـ Magic Link.
  void _listenAuthChanges(BuildContext ctx) {
    _authSub?.cancel();
    _authSub = SupabaseService().auth.onAuthStateChange.listen((data) async {
      final event = data.event;
      if (event == AuthChangeEvent.signedIn) {
        final session = data.session;
        if (session?.user.email != null &&
            !session!.user.email!.endsWith('@whatsapp.local')) {
          // إيميل حقيقي → magic link
          final auth = ctx.read<AuthProvider>();
          final ok = await auth.handleEmailSession();
          if (ok && mounted) {
            final go = AppRouter.router;
            if (auth.isNewUser) {
              go.go('/setup-profile');
            } else {
              go.go('/');
            }
          }
        }
      }
    });
  }

  Future<void> _initializeApp() async {
    try {
      await SupabaseService.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
      await NotificationService.initialize();
      if (mounted) setState(() => _initialized = true);
      // ملاحظة: الـ listener يُربط بأول build (له context)
    } catch (e) {
      if (mounted) setState(() => _initError = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ConfigProvider()),
        ChangeNotifierProvider(create: (_) => OfferProvider()),
        ChangeNotifierProvider(create: (_) => RequestProvider()),
        ChangeNotifierProvider(create: (_) => AppointmentProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => PaymentProvider()),
        ChangeNotifierProvider(create: (_) => AdminProvider()),
        ChangeNotifierProvider(create: (_) => BrokerProvider()),
      ],
      child: Builder(builder: (ctx) {
        // ربط الـ listener مرة واحدة بعد ما يتوفر context الموجود فيه AuthProvider
        if (_initialized && _authSub == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _listenAuthChanges(ctx);
          });
        }
        return MaterialApp.router(
        title: 'المكتب العقاري الالكتروني',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        routerConfig: AppRouter.router,
        locale: const Locale('ar', 'SY'),
        builder: (context, child) {
          if (_initError != null) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(
                backgroundColor: AppTheme.deepBlack,
                body: Center(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 60),
                    const SizedBox(height: 20),
                    const Text('حدث خطأ في التهيئة', style: TextStyle(color: AppTheme.textWhite, fontSize: 18)),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 30),
                      child: Text(_initError!, style: const TextStyle(color: AppTheme.textGrey, fontSize: 12), textAlign: TextAlign.center),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(onPressed: () => setState(() { _initError = null; _initializeApp(); }), child: const Text('إعادة المحاولة')),
                  ]),
                ),
              ),
            );
          }
          return Directionality(textDirection: TextDirection.rtl, child: child!);
        },
      );
      }),
    );
  }
}
