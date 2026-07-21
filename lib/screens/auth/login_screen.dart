import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/e2e.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.startInSignUpMode = false});
  final bool startInSignUpMode;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // 0: مغلق، 1: تسجيل جديد، 2: تسجيل دخول
  int _activeSection = 0;
  // 1: هاتف، 2: إيميل
  int _signupMethod = 0;

  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  bool _obs = true;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    // تفعيل القسم المناسب حسب التوجيه
    _activeSection = widget.startInSignUpMode ? 1 : 2;
  }

  @override
  void dispose() {
    _userCtrl.dispose(); _passCtrl.dispose(); _phoneCtrl.dispose(); _emailCtrl.dispose();
    super.dispose();
  }

  // ── العمليات الوظيفية ──
  Future<void> _login() async {
    if (_userCtrl.text.isEmpty || _passCtrl.text.isEmpty) { _snack('أدخل بيانات الدخول'); return; }
    setState(() => _loading = true);
    final auth = context.read<AuthProvider>();
    final ok = await auth.loginWithPassword(_userCtrl.text.trim(), _passCtrl.text);
    if (mounted) setState(() => _loading = false);
    if (!ok) {
      _snack(auth.lastError ?? 'خطأ في الاسم أو كلمة المرور');
    } else {
      if (mounted) {
        if (auth.isLawyer) {
          context.go('/lawyer/dashboard');
        } else if (auth.isExpediter) {
          context.go('/expediter/tasks');
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
    }
  }

  Future<void> _forgot() async {
    final ph = _userCtrl.text.trim();
    if (ph.length != 10 || !ph.startsWith('09')) { _snack('أدخل رقم هاتفك في خانة الدخول أولاً'); return; }
    setState(() => _loading = true);
    final ok = await context.read<AuthProvider>().sendSMSOTP(ph);
    if (mounted) setState(() => _loading = false);
    if (ok) context.push('/otp');
  }

  Future<void> _regSMS() async {
    if (_phoneCtrl.text.length != 10 || !_phoneCtrl.text.startsWith('09')) { _snack('أدخل رقم هاتف صحيح'); return; }
    setState(() => _loading = true);
    final ok = await context.read<AuthProvider>().sendSMSOTP(_phoneCtrl.text.trim(), isSignUp: true);
    if (mounted) setState(() => _loading = false);
    if (ok) {
      context.push('/otp');
    } else {
      final auth = context.read<AuthProvider>();
      if (auth.lastError != null) _snack(auth.lastError!);
    }
  }

  Future<void> _regMail() async {
    if (_emailCtrl.text.isEmpty || !_emailCtrl.text.contains('@')) { _snack('أدخل بريداً صحيحاً'); return; }
    setState(() => _loading = true);
    final ok = await context.read<AuthProvider>().sendEmailMagicLink(_emailCtrl.text.trim());
    if (mounted) setState(() => _loading = false);
    if (ok) context.push('/check-email');
  }

  void _snack(String m) => AppTheme.showSnackBar(context, SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final sz = MediaQuery.sizeOf(context);
    final logoSize = (sz.shortestSide * 0.95).clamp(300.0, 550.0);

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(children: [
            const SizedBox(height: 20),
            // 🔥 شعار السبلاش الضخم جداً
            Hero(tag: 'logo', child: Container(
              width: logoSize, height: logoSize * 0.72,
              decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: AppTheme.primaryGold.withOpacity(0.2), blurRadius: 100, spreadRadius: 25)]),
              child: Stack(alignment: Alignment.center, children: [
                Container(width: logoSize * 0.72, height: logoSize * 0.72, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppTheme.primaryGold.withOpacity(0.4), width: 3.5))),
                Container(width: logoSize * 0.65, height: logoSize * 0.65, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppTheme.surfaceBlack), padding: const EdgeInsets.all(35), child: Image.asset('assets/images/logo_app.png', fit: BoxFit.contain)),
              ]),
            )),
            const SizedBox(height: 10),
            Text('المكتب العقاري الإلكتروني', style: GoogleFonts.cairo(color: AppTheme.primaryGold, fontSize: 26, fontWeight: FontWeight.w900)),
            const SizedBox(height: 50),

            // ── القائمة 1: تسجيل الدخول ──
            _buildBlock(
              id: 2, title: 'تسجيل الدخول', icon: Icons.login_rounded, isGold: false,
              child: Column(children: [
                _input(_userCtrl, 'اسم المستخدم أو الهاتف', Icons.person_outline, e2eId: 'e2e_login_username'),
                const SizedBox(height: 12),
                _input(_passCtrl, 'كلمة المرور', Icons.lock_outline, isPass: true, obs: _obs, onT: () => setState(() => _obs = !_obs), e2eId: 'e2e_login_password'),
                const SizedBox(height: 20),
                _btn(label: 'دخول', onTap: _login, e2eId: 'e2e_login_button'),
                TextButton(onPressed: _forgot, child: const Text('هل نسيت كلمة المرور؟ استعادة بـ SMS', style: TextStyle(color: AppTheme.primaryGold, decoration: TextDecoration.underline, fontSize: 13))),
              ]),
            ),

            const SizedBox(height: 16),

            // ── القائمة 2: تسجيل حساب جديد ──
            _buildBlock(
              id: 1, title: 'تسجيل حساب جديد', icon: Icons.person_add_alt_1_outlined, isGold: true,
              child: Column(children: [
                // أ. هاتف
                _buildOption(
                  id: 1, title: 'عن طريق رقم الهاتف', icon: Icons.phone_android,
                  child: Column(children: [
                    const Text('سيصلك رمز تفعيل برسالة نصية SMS', style: TextStyle(color: Colors.black87, fontSize: 11)),
                    const SizedBox(height: 12),
                    _input(_phoneCtrl, '09XXXXXXXX', Icons.phone_iphone, dark: true),
                    const SizedBox(height: 12),
                    _btn(label: 'إرسال رمز التفعيل SMS', onTap: _regSMS, dark: true),
                  ]),
                ),
                const SizedBox(height: 12),
                // ب. إيميل
                _buildOption(
                  id: 2, title: 'عن طريق الإيميل', icon: Icons.alternate_email,
                  child: Column(children: [
                    const Text('سيصلك رابط تفعيل إلى بريدك الإلكتروني', style: TextStyle(color: Colors.black87, fontSize: 11)),
                    const SizedBox(height: 12),
                    _input(_emailCtrl, 'example@mail.com', Icons.email_outlined, dark: true),
                    const SizedBox(height: 12),
                    _btn(label: 'إرسال رابط التفعيل', onTap: _regMail, dark: true),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 60),
          ]),
        ),
      ),
    );
  }

  Widget _buildBlock({required int id, required String title, required IconData icon, required bool isGold, required Widget child}) {
    final open = _activeSection == id;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(color: isGold ? AppTheme.primaryGold : AppTheme.surfaceBlack, borderRadius: BorderRadius.circular(24), border: Border.all(color: AppTheme.primaryGold.withOpacity(0.5), width: 2)),
      child: Column(children: [
        InkWell(
          onTap: () => setState(() { _activeSection = open ? 0 : id; if (id == 1) _signupMethod = 0; }),
          borderRadius: BorderRadius.circular(24),
          child: Padding(padding: const EdgeInsets.all(20), child: Row(children: [
            Icon(icon, color: isGold ? Colors.black : AppTheme.primaryGold, size: 28),
            const SizedBox(width: 16),
            Text(title, style: TextStyle(color: isGold ? Colors.black : AppTheme.textWhite, fontSize: 18, fontWeight: FontWeight.w900)),
            const Spacer(),
            Icon(open ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: isGold ? Colors.black : AppTheme.textGrey),
          ])),
        ),
        if (open) Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 20), child: child),
      ]),
    );
  }

  Widget _buildOption({required int id, required String title, required IconData icon, required Widget child}) {
    final sel = _signupMethod == id;
    return Container(
      decoration: BoxDecoration(color: Colors.black.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
      child: Column(children: [
        ListTile(
          onTap: () => setState(() => _signupMethod = sel ? 0 : id),
          leading: Icon(icon, color: Colors.black87),
          title: Text(title, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 14)),
          trailing: Icon(sel ? Icons.radio_button_checked : Icons.radio_button_off, color: Colors.black87),
        ),
        if (sel) Padding(padding: const EdgeInsets.fromLTRB(12, 0, 12, 16), child: child),
      ]),
    );
  }

  Widget _input(TextEditingController c, String h, IconData i, {bool isPass = false, bool? obs, VoidCallback? onT, bool dark = false, String? e2eId}) {
    final field = TextField(
      controller: c, obscureText: obs ?? false, textAlign: TextAlign.left,
      style: TextStyle(color: dark ? Colors.black : AppTheme.textWhite, fontWeight: FontWeight.bold),
      decoration: InputDecoration(
        hintText: h, prefixIcon: Icon(i, color: dark ? Colors.black45 : AppTheme.primaryGold),
        fillColor: dark ? Colors.white.withOpacity(0.8) : AppTheme.surfaceBlack,
        suffixIcon: isPass ? IconButton(icon: Icon(obs! ? Icons.visibility_off : Icons.visibility, color: AppTheme.textGrey), onPressed: onT) : null,
      ),
    );
    return e2eId == null ? field : E2E(id: e2eId, child: field);
  }

  Widget _btn({required String label, required VoidCallback? onTap, bool dark = false, String? e2eId}) {
    final button = SizedBox(width: double.infinity, height: 56, child: ElevatedButton(
      onPressed: _loading ? null : onTap,
      style: ElevatedButton.styleFrom(backgroundColor: dark ? Colors.black : Colors.white, foregroundColor: dark ? Colors.white : Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
      child: _loading ? const CircularProgressIndicator(color: Colors.grey) : Text(label, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
    ));
    return e2eId == null ? button : E2E(id: e2eId, button: true, child: button);
  }
}
