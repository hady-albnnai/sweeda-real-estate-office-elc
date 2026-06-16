import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../core/theme/app_theme.dart';
import '../providers/config_provider.dart';
import '../providers/auth_provider.dart';
import '../services/fcm_service.dart';

// ============================================================
// ملاحظة للرجوع لها لاحقا:
// تحسينات مستقبلية مقترحة لشاشة السبلاش:
// 1. Progress Bar يعكس حالة تحميل البيانات
// 2. انيميشن خروج سلس (slide up او fade out)
// 3. اضافة Slogan تحت اسم التطبيق
// 4. دعم Android native splash screen
// 5. فحص حالة الاتصال بالانترنت قبل المتابعة
// 6. تحميل Config من Supabase قبل الانتقال للرئيسية
// 7. شاشة onboarding لاول مرة يفتح المستخدم التطبيق
// ============================================================

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.6, curve: Curves.easeIn)),
    );

    _scaleAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.2, 0.8, curve: Curves.elasticOut)),
    );

    _controller.forward();
    // نؤجّل التحميل لبعد اكتمال أول frame لتفادي
    // setState()/notifyListeners() أثناء البناء.
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  /// تحميل الإعدادات + فحص الجلسة ثم الانتقال
  Future<void> _bootstrap() async {
    final config = Provider.of<ConfigProvider>(context, listen: false);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    // نشغّل التحميل والحد الأدنى للعرض بالتوازي
    await Future.wait([
      config.loadConfig(),
      auth.checkAuthStatus(),
      Future.delayed(const Duration(milliseconds: 1800)),
    ]);
    if (!mounted) return;

    // تهيئة FCM بعد التحقق من المستخدم (لتسجيل التوكن مع uid لو مسجّل دخول)
    FCMService().setup();

    // التوجّه حسب حالة المستخدم
    if (auth.isLoggedIn) {
      if (auth.isSenior) {
        context.go('/admin/dashboard');
      } else if (auth.isEmployee) {
        context.go('/employee/home');
      } else if (auth.isSupervisor) {
        context.go('/executor/tasks');
      } else if (auth.isPhotographer) {
        context.go('/photographer/tasks');
      } else if (auth.isBroker) {
        context.go('/broker/dashboard');
      } else {
        context.go('/user/home');
      }
    } else {
      context.go('/home'); // شاشة الزائر
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final logoSize = (screenSize.shortestSide * 0.68).clamp(220.0, 420.0);

    return Scaffold(
      backgroundColor: AppTheme.deepBlack,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Opacity(
              opacity: _fadeAnimation.value,
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: logoSize,
                      height: logoSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.primaryGold, width: 2.5),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryGold.withValues(alpha: 0.25),
                            blurRadius: 25,
                            spreadRadius: 5,
                          ),
                          BoxShadow(
                            color: AppTheme.primaryGold.withValues(alpha: 0.1),
                            blurRadius: 50,
                            spreadRadius: 10,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Container(
                          color: AppTheme.surfaceBlack,
                          padding: EdgeInsets.all(logoSize * 0.06),
                          child: Image.asset(
                            'assets/images/logo_app.png',
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.apartment_rounded,
                              size: logoSize * 0.48,
                              color: AppTheme.primaryGold,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: screenSize.height * 0.035),
                    const Text(
                      'المكتب العقاري الالكتروني',
                      style: TextStyle(
                        color: AppTheme.primaryGold,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'السويداء',
                      style: TextStyle(
                        color: AppTheme.primaryGold.withValues(alpha: 0.6),
                        fontSize: 13,
                        letterSpacing: 3,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'عقارات • سيارات • مواعيد معاينة',
                      style: TextStyle(
                        color: AppTheme.textGrey.withValues(alpha: 0.7),
                        fontSize: 11,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 45),
                    // شريط تقدّم بسيط بعرض ثابت
                    SizedBox(
                      width: 160,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          minHeight: 4,
                          backgroundColor: AppTheme.surfaceBlack,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppTheme.primaryGold.withValues(alpha: 0.85),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'جارٍ التحميل...',
                      style: TextStyle(
                        color: AppTheme.textGrey.withValues(alpha: 0.6),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
