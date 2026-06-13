import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import 'package:go_router/go_router.dart';

/// شاشة تسجيل الدخول الموحّدة:
///   • تبويبة: اسم مستخدم/رقم هاتف + كلمة مرور (الافتراضية)
///   • تبويبة: واتساب OTP (للتسجيل أول مرة أو نسيان كلمة المرور)
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  final _identifierCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    _identifierCtrl.dispose();
    _passwordCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  // ───────── تسجيل دخول بكلمة مرور ─────────
  Future<void> _loginWithPassword() async {
    final identifier = _identifierCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (identifier.isEmpty) {
      _toast('أدخل اسم المستخدم أو رقم الهاتف');
      return;
    }
    if (password.isEmpty) {
      _toast('أدخل كلمة المرور');
      return;
    }

    setState(() => _loading = true);
    final auth = context.read<AuthProvider>();
    final ok = await auth.loginWithPassword(identifier, password);
    if (!mounted) return;
    setState(() => _loading = false);

    if (ok) {
      _navigateByRole(auth);
    } else {
      _toast(auth.lastError ?? 'فشل تسجيل الدخول');
    }
  }

  // ───────── واتساب OTP ─────────
  Future<void> _sendWhatsApp() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.length != 10) {
      _toast('يرجى إدخال رقم هاتف صحيح (10 أرقام)');
      return;
    }
    setState(() => _loading = true);
    final auth = context.read<AuthProvider>();
    final ok = await auth.sendWhatsAppOTP(phone);
    if (!mounted) return;
    setState(() => _loading = false);
    if (ok) {
      context.push('/otp');
    } else {
      _toast('حدث خطأ في إرسال الرمز عبر واتساب');
    }
  }

  void _navigateByRole(AuthProvider auth) {
    if (auth.isNewUser) {
      context.go('/setup-profile');
    } else if (auth.isSenior) {
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
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        // ─── خلفية ───
        Positioned(
          top: -100,
          right: -100,
          child: CircleAvatar(
            radius: 150,
            backgroundColor: AppTheme.primaryGold.withValues(alpha: 0.08),
          ),
        ),
        Positioned(
          bottom: -80,
          left: -80,
          child: CircleAvatar(
            radius: 120,
            backgroundColor: AppTheme.primaryGold.withValues(alpha: 0.04),
          ),
        ),
        SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                // ─── الشعار ───
                Center(
                  child: Column(children: [
                    Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryGold.withValues(alpha: 0.2),
                            blurRadius: 25,
                            spreadRadius: 3,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: Image.asset('assets/images/logo_app.png',
                            fit: BoxFit.cover),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text('مرحباً بك',
                        style: TextStyle(
                            color: AppTheme.textWhite,
                            fontSize: 24,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    const Text('سجّل دخولك للمتابعة',
                        style: TextStyle(
                            color: AppTheme.textGrey, fontSize: 14)),
                  ]),
                ),
                const SizedBox(height: 28),

                // ─── التبويبات ───
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceBlack,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: TabBar(
                    controller: _tab,
                    indicator: BoxDecoration(
                      color: AppTheme.primaryGold,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    indicatorPadding: const EdgeInsets.all(4),
                    labelColor: Colors.black,
                    unselectedLabelColor: AppTheme.textGrey,
                    labelStyle: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13),
                    dividerColor: Colors.transparent,
                    tabs: const [
                      Tab(
                        icon: Icon(Icons.lock_outline, size: 18),
                        text: 'كلمة مرور',
                        iconMargin: EdgeInsets.only(bottom: 2),
                      ),
                      Tab(
                        icon: Icon(Icons.chat_outlined, size: 18),
                        text: 'واتساب',
                        iconMargin: EdgeInsets.only(bottom: 2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),

                // ─── محتوى التبويبات ───
                SizedBox(
                  height: 300,
                  child: TabBarView(
                    controller: _tab,
                    children: [
                      _passwordTab(),
                      _whatsappTab(),
                    ],
                  ),
                ),

                const SizedBox(height: 12),
                Center(
                  child: Text(
                    'بتسجيلك توافق على شروط الاستخدام وسياسة الخصوصية.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: AppTheme.textGrey.withValues(alpha: 0.6),
                        fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  تبويبة كلمة المرور
  // ═══════════════════════════════════════════════════════════════

  Widget _passwordTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('اسم المستخدم أو رقم الهاتف',
            style: TextStyle(
                color: AppTheme.primaryGold,
                fontWeight: FontWeight.bold,
                fontSize: 13)),
        const SizedBox(height: 8),
        TextField(
          controller: _identifierCtrl,
          textAlign: TextAlign.left,
          style: const TextStyle(color: AppTheme.textWhite),
          decoration: InputDecoration(
            hintText: 'مثال: ahmed123 أو 09XXXXXXXX',
            hintStyle: TextStyle(
                color: AppTheme.textGrey.withValues(alpha: 0.5),
                fontSize: 13),
            prefixIcon: const Icon(Icons.person_outline,
                color: AppTheme.primaryGold, size: 20),
          ),
        ),
        const SizedBox(height: 14),
        const Text('كلمة المرور',
            style: TextStyle(
                color: AppTheme.primaryGold,
                fontWeight: FontWeight.bold,
                fontSize: 13)),
        const SizedBox(height: 8),
        TextField(
          controller: _passwordCtrl,
          obscureText: _obscure,
          textAlign: TextAlign.left,
          style: const TextStyle(color: AppTheme.textWhite),
          decoration: InputDecoration(
            hintText: '••••••',
            hintStyle: TextStyle(
                color: AppTheme.textGrey.withValues(alpha: 0.5)),
            prefixIcon: const Icon(Icons.lock_outline,
                color: AppTheme.primaryGold, size: 20),
            suffixIcon: IconButton(
              icon: Icon(
                _obscure
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: AppTheme.textGrey,
                size: 20,
              ),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
          onSubmitted: (_) => _loginWithPassword(),
        ),

        // نسيت كلمة المرور
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () {
              _tab.animateTo(1);
              _toast('سجّل دخولك عبر واتساب لإعادة تعيين كلمة المرور');
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 4),
            ),
            child: const Text(
              'هل نسيت كلمة المرور؟',
              style: TextStyle(
                color: AppTheme.primaryGold,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),

        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: _loading ? null : _loginWithPassword,
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.black))
                : const Icon(Icons.login_rounded, color: Colors.black,
                    size: 20),
            label: const Text('تسجيل الدخول',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),

        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: () => _tab.animateTo(1),
            child: Text(
              'ليس لديك حساب؟ سجّل عبر واتساب',
              style: TextStyle(
                color: AppTheme.textGrey.withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  تبويبة واتساب
  // ═══════════════════════════════════════════════════════════════

  Widget _whatsappTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('رقم الموبايل',
            style: TextStyle(
                color: AppTheme.primaryGold,
                fontWeight: FontWeight.bold,
                fontSize: 13)),
        const SizedBox(height: 8),
        TextField(
          controller: _phoneCtrl,
          keyboardType: TextInputType.phone,
          textAlign: TextAlign.left,
          style: const TextStyle(color: AppTheme.textWhite),
          decoration: InputDecoration(
            hintText: '09XXXXXXXX',
            hintStyle: TextStyle(
                color: AppTheme.textGrey.withValues(alpha: 0.5)),
            prefixIcon: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              alignment: Alignment.center,
              width: 60,
              child: const Text('+963',
                  style: TextStyle(
                      color: AppTheme.primaryGold,
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 60),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'سيصلك رمز تحقق عبر واتساب لتسجيل الدخول.\n'
          'إذا كنت مستخدم جديد، ستتمكن من إنشاء اسم مستخدم وكلمة مرور.',
          style: TextStyle(
              color: AppTheme.textGrey.withValues(alpha: 0.6),
              fontSize: 11,
              height: 1.5),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: _loading ? null : _sendWhatsApp,
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.black))
                : const Icon(Icons.chat_rounded, color: Colors.black,
                    size: 20),
            label: const Text('إرسال عبر واتساب',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: TextButton(
            onPressed: () => _tab.animateTo(0),
            child: Text(
              'لديك حساب؟ ادخل بكلمة المرور',
              style: TextStyle(
                color: AppTheme.textGrey.withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
