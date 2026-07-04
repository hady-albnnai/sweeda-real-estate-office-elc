import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/network/supabase_service.dart';
import 'core/constants/supabase_constants.dart';
import 'providers/auth_provider.dart';
import 'providers/config_provider.dart';
import 'providers/offer_provider.dart';
import 'providers/request_provider.dart';
import 'providers/appointment_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/payment_provider.dart';
import 'providers/admin_provider.dart';
import 'providers/broker_provider.dart';
import 'providers/photography_provider.dart';
import 'providers/executor_provider.dart';
import 'providers/legal_provider.dart';
import 'services/notification_service.dart';

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
  void _listenAuthChanges() {
    _authSub?.cancel();
    _authSub = SupabaseService().auth.onAuthStateChange.listen((data) {
      final event = data.event;
      if (event == AuthChangeEvent.signedIn) {
        final session = data.session;
        if (session?.user.email != null &&
            !session!.user.email!.endsWith('@whatsapp.local')) {
          if (!mounted) return;
          // إيميل حقيقي → magic link
          final auth = context.read<AuthProvider>();
          auth.handleEmailSession().then((ok) {
            if (!mounted || !ok) return;
            final go = AppRouter.router;
            if (auth.isNewUser) {
              go.go('/setup-profile');
            } else if (auth.isSenior) {
              go.go('/admin/dashboard');
            } else if (auth.isEmployee) {
              go.go('/employee/home');
            } else if (auth.isSupervisor) {
              go.go('/executor/tasks');
            } else if (auth.isPhotographer) {
              go.go('/photographer/tasks');
            } else if (auth.isBroker) {
              go.go('/broker/dashboard');
            } else {
              go.go('/user/home');
            }
          });
        }
      }
    });
  }

  Future<void> _initializeApp() async {
    try {
      await SupabaseService.initialize(
          url: supabaseUrl, publishableKey: supabasePublishableKey);
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
        ChangeNotifierProvider(create: (_) => PhotographyProvider()),
        ChangeNotifierProvider(create: (_) => ExecutorProvider()),
        ChangeNotifierProvider(create: (_) => LegalProvider()),
      ],
      child: Builder(builder: (ctx) {
        // ربط الـ listener مرة واحدة بعد ما يتوفر context الموجود فيه AuthProvider
        if (_initialized && _authSub == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _listenAuthChanges();
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
