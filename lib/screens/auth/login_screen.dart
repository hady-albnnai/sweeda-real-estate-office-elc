import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import 'package:go_router/go_router.dart';

/// ════════════════════════════════════════════════════════════════════
/// شاشة المصادقة الموحّدة:
///   • وضع «إنشاء حساب» (Sign Up): واتساب (أساسي) + إيميل (ثانوي)
///   • وضع «تسجيل الدخول» (Sign In): اسم مستخدم أو هاتف + كلمة مرور
///
/// التدفق:
///   Sign Up → واتساب/إيميل → OTP/Magic → شاشة إلزامية (اسم مستخدم + كلمة مرور)
///   Sign In → اسم المستخدم أو الهاتف + كلمة مرور → دخول مباشر
/// ════════════════════════════════════════════════════════════════════
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isSignUp = false; // true = إنشاء حساب، false = تسجيل الدخول

  // ── Sign In fields ──
  final _identifierCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;

  // ── Sign Up fields ──
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  bool _loading = false;

  @override
  void dispose() {
    _identifierCtrl.dispose();
    _passwordCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════════
  // Sign In — اسم مستخدم/هاتف + كلمة مرور
  // ══════════════════════════════════════════════════════════════════
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

  // ══════════════════════════════════════════════════════════════════
  // Sign Up — واتساب OTP
  // ══════════════════════════════════════════════════════════════════
  Future<void> _sendWhatsApp() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.length != 10 || !phone.startsWith('09')) {
      _toast('يرجى إدخال رقم هاتف صحيح (يبدأ بـ 09 ويتكون من 10 أرقام)');
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

  // ══════════════════════════════════════════════════════════════════
  // Sign Up — إيميل Magic Link
  // ══════════════════════════════════════════════════════════════════
  Future<void> _sendEmailLink() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _toast('يرجى إدخال بريد إلكتروني صحيح');
      return;
    }
    setState(() => _loading = true);
    final auth = context.read<AuthProvider>();
    final ok = await auth.sendEmailMagicLink(email);
    if (!mounted) return;
    setState(() => _loading = false);
    if (ok) {
      context.push('/check-email');
    } else {
      _toast('حدث خطأ في إرسال رابط التسجيل');
    }
  }

  // ══════════════════════════════════════════════════════════════════
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
        // ─── خلفية زخرفية ───
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
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),

                // ─── زر الرجوع ───
                if (Navigator.of(context).canPop())
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios,
                          color: AppTheme.textGrey, size: 20),
                      onPressed: () => context.pop(),
                    ),
                  ),

                // ─── الشعار ───
                Center(
                  child: Column(children: [
                    Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(26),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryGold.withValues(alpha: 0.2),
                            blurRadius: 25,
                            spreadRadius: 3,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(26),
                        child: Image.asset('assets/images/logo_app.png',
                            fit: BoxFit.cover),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _isSignUp ? 'أنشئ حسابك' : 'مرحباً بعودتك',
                      style: const TextStyle(
                          color: AppTheme.textWhite,
                          fontSize: 23,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isSignUp
                          ? 'سجّل برقمك للمتابعة'
                          : 'سجّل دخولك للمتابعة',
                      style: const TextStyle(
                          color: AppTheme.textGrey, fontSize: 13),
                    ),
                  ]),
                ),
                const SizedBox(height: 24),

                // ─── مفتاح التبديل Sign Up / Sign In ───
                _buildToggle(),

                const SizedBox(height: 24),

                // ─── المحتوى حسب الوضع ───
                _isSignUp ? _buildSignUpForm() : _buildSignInForm(),

                const SizedBox(height: 20),
                Center(
                  child: Text(
                    'بتسجيلك توافق على شروط الاستخدام وسياسة الخصوصية.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: AppTheme.textGrey.withValues(alpha: 0.6),
                        fontSize: 11),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // مفتاح التبديل
  // ══════════════════════════════════════════════════════════════════
  Widget _buildToggle() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceBlack,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(children: [
        Expanded(
          child: _toggleButton(
            label: 'تسجيل الدخول',
            icon: Icons.login_rounded,
            selected: !_isSignUp,
            onTap: () => setState(() => _isSignUp = false),
          ),
        ),
        Expanded(
          child: _toggleButton(
            label: 'إنشاء حساب',
            icon: Icons.person_add_alt_1_outlined,
            selected: _isSignUp,
            onTap: () => setState(() => _isSignUp = true),
          ),
        ),
      ]),
    );
  }

  Widget _toggleButton({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.all(4),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryGold : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 17,
                color: selected ? Colors.black : AppTheme.textGrey),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.black : AppTheme.textGrey,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // نموذج Sign In — اسم مستخدم/هاتف + كلمة مرور
  // ══════════════════════════════════════════════════════════════════
  Widget _buildSignInForm() {
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
            hintStyle:
                TextStyle(color: AppTheme.textGrey.withValues(alpha: 0.5)),
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

        // نسيت كلمة المرور → Sign Up (واتساب)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () {
              setState(() => _isSignUp = true);
              _toast('سجّل عبر واتساب لإعادة تعيين كلمة المرور');
            },
            style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 4)),
            child: const Text(
              'هل نسيت كلمة المرور؟',
              style: TextStyle(
                  color: AppTheme.primaryGold,
                  fontSize: 12,
                  fontWeight: FontWeight.w500),
            ),
          ),
        ),

        const SizedBox(height: 6),
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
                : const Icon(Icons.login_rounded,
                    color: Colors.black, size: 20),
            label: const Text('تسجيل الدخول',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),

        const SizedBox(height: 10),
        Center(
          child: TextButton(
            onPressed: () => setState(() => _isSignUp = true),
            child: Text(
              'ليس لديك حساب؟ أنشئ حساباً جديداً',
              style: TextStyle(
                  color: AppTheme.textGrey.withValues(alpha: 0.8),
                  fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // نموذج Sign Up — واتساب (أساسي) + إيميل (ثانوي)
  // ══════════════════════════════════════════════════════════════════
  Widget _buildSignUpForm() {
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
            hintStyle:
                TextStyle(color: AppTheme.textGrey.withValues(alpha: 0.5)),
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
        const SizedBox(height: 6),
        Text(
          'سيصلك رمز تحقق عبر واتساب. بعد التحقق ستختار اسم مستخدم وكلمة مرور.',
          style: TextStyle(
              color: AppTheme.textGrey.withValues(alpha: 0.6),
              fontSize: 11,
              height: 1.5),
        ),
        const SizedBox(height: 18),

        // زر واتساب (أساسي)
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
                : const Icon(Icons.chat_rounded,
                    color: Colors.black, size: 20),
            label: const Text('متابعة عبر واتساب',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),

        // فاصل
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 14),
          child: Row(children: [
            Expanded(child: Divider(color: AppTheme.textGrey, height: 1)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text('أو',
                  style: TextStyle(color: AppTheme.textGrey, fontSize: 12)),
            ),
            Expanded(child: Divider(color: AppTheme.textGrey, height: 1)),
          ]),
        ),

        // إيميل (ثانوي)
        const Text('البريد الإلكتروني',
            style: TextStyle(
                color: AppTheme.primaryGold,
                fontWeight: FontWeight.bold,
                fontSize: 13)),
        const SizedBox(height: 8),
        TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          textAlign: TextAlign.left,
          style: const TextStyle(color: AppTheme.textWhite),
          decoration: InputDecoration(
            hintText: 'example@email.com',
            hintStyle:
                TextStyle(color: AppTheme.textGrey.withValues(alpha: 0.5)),
            prefixIcon: const Icon(Icons.mail_outline,
                color: AppTheme.primaryGold, size: 20),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton.icon(
            onPressed: _loading ? null : _sendEmailLink,
            icon: const Icon(Icons.link_rounded,
                color: AppTheme.primaryGold, size: 20),
            label: const Text('إرسال رابط التسجيل',
                style: TextStyle(
                    color: AppTheme.primaryGold,
                    fontWeight: FontWeight.bold)),
          ),
        ),

        const SizedBox(height: 10),
        Center(
          child: TextButton(
            onPressed: () => setState(() => _isSignUp = false),
            child: Text(
              'لديك حساب؟ سجّل دخولك',
              style: TextStyle(
                  color: AppTheme.textGrey.withValues(alpha: 0.8),
                  fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }
}
