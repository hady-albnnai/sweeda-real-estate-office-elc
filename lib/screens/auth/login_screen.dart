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
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import 'package:go_router/go_router.dart';

class LoginScreen extends StatefulWidget {
  final bool startInSignUpMode;
  const LoginScreen({super.key, this.startInSignUpMode = false});
  
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late bool _isSignUp; 
  int _activeCategory = 0; // 0: none, 1: WhatsApp, 2: Email, 3: Password

  // ── Sign In fields ──
  final _identifierCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;

  // ── Sign Up fields ──
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _isSignUp = widget.startInSignUpMode;
  }

  @override
  void dispose() {
    _identifierCtrl.dispose();
    _passwordCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  // ... (نفس الدوال السابقة _loginWithPassword, _sendWhatsApp, _sendEmailLink, _navigateByRole)

  Future<void> _loginWithPassword() async {
    final identifier = _identifierCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (identifier.isEmpty || password.isEmpty) {
      _toast('أدخل كافة البيانات المطلوبة');
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

  Future<void> _sendWhatsApp() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.length != 10 || !phone.startsWith('09')) {
      _toast('أدخل رقم هاتف صحيح');
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
      _toast('فشل إرسال الرمز');
    }
  }

  Future<void> _sendEmailLink() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _toast('أدخل بريد إلكتروني صحيح');
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
      _toast('فشل إرسال الرابط');
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
      backgroundColor: AppTheme.deepBlack,
      body: Stack(
        children: [
          // ─── تأثير الإضاءة ───
          Positioned(
            top: -100,
            right: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [AppTheme.primaryGold.withValues(alpha: 0.1), Colors.transparent],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // ─── شريط العنوان ───
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, color: AppTheme.textGrey),
                        onPressed: () => context.pop(),
                      ),
                      const Spacer(),
                      Text(
                        _isSignUp ? 'إنشاء حساب جديد' : 'تسجيل الدخول',
                        style: const TextStyle(color: AppTheme.primaryGold, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const Spacer(),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        const SizedBox(height: 10),
                        // شعار صغير
                        Image.asset('assets/images/logo_app.png', height: 80),
                        const SizedBox(height: 30),

                        // ─── وضع إنشاء حساب ───
                        if (_isSignUp) ...[
                          _authCategory(
                            id: 1,
                            title: 'عبر الواتساب (موصى به)',
                            subtitle: 'سجّل دخولك بلمحة بصر عبر تطبيق الواتساب',
                            icon: Icons.chat_outlined,
                            color: Colors.green,
                            child: _buildWhatsAppForm(),
                          ),
                          const SizedBox(height: 16),
                          _authCategory(
                            id: 2,
                            title: 'عبر البريد الإلكتروني',
                            subtitle: 'استلم رابط دخول آمن على بريدك',
                            icon: Icons.alternate_email,
                            color: Colors.blue,
                            child: _buildEmailForm(),
                          ),
                          const SizedBox(height: 30),
                          TextButton(
                            onPressed: () => setState(() {
                              _isSignUp = false;
                              _activeCategory = 0;
                            }),
                            child: const Text('لديك حساب مسبق؟ سجل دخولك الآن', style: TextStyle(color: AppTheme.textGrey, fontSize: 13)),
                          ),
                        ] 
                        // ─── وضع تسجيل الدخول ───
                        else ...[
                          _authCategory(
                            id: 3,
                            title: 'بيانات الدخول التقليدية',
                            subtitle: 'اسم المستخدم وكلمة المرور',
                            icon: Icons.lock_outline,
                            color: AppTheme.primaryGold,
                            child: _buildPasswordForm(),
                          ),
                          const SizedBox(height: 16),
                          _authCategory(
                            id: 1,
                            title: 'دخول سريع عبر واتساب',
                            subtitle: 'في حال نسيت كلمة المرور',
                            icon: Icons.phonelink_ring_outlined,
                            color: Colors.green,
                            child: _buildWhatsAppForm(),
                          ),
                          const SizedBox(height: 30),
                          TextButton(
                            onPressed: () => setState(() {
                              _isSignUp = true;
                              _activeCategory = 0;
                            }),
                            child: const Text('ليس لديك حساب؟ أنشئ حساباً جديداً', style: TextStyle(color: AppTheme.textGrey, fontSize: 13)),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_loading)
            Container(
              color: Colors.black54,
              child: const Center(child: CircularProgressIndicator(color: AppTheme.primaryGold)),
            ),
        ],
      ),
    );
  }

  Widget _authCategory({
    required int id,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Widget child,
  }) {
    final isOpen = _activeCategory == id;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: AppTheme.surfaceBlack,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isOpen ? color.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.05)),
        boxShadow: [
          if (isOpen) BoxShadow(color: color.withValues(alpha: 0.1), blurRadius: 20)
        ],
      ),
      child: Column(
        children: [
          ListTile(
            onTap: () => setState(() => _activeCategory = isOpen ? 0 : id),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 22),
            ),
            title: Text(title, style: const TextStyle(color: AppTheme.textWhite, fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: Text(subtitle, style: const TextStyle(color: AppTheme.textGrey, fontSize: 11)),
            trailing: Icon(isOpen ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: AppTheme.textGrey),
          ),
          if (isOpen) Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 20), child: child),
        ],
      ),
    );
  }

  Widget _buildWhatsAppForm() {
    return Column(
      children: [
        const Divider(color: Colors.white10),
        const SizedBox(height: 12),
        TextField(
          controller: _phoneCtrl,
          keyboardType: TextInputType.phone,
          textAlign: TextAlign.left,
          style: const TextStyle(color: AppTheme.textWhite),
          decoration: const InputDecoration(
            hintText: '09XXXXXXXX',
            prefixIcon: Icon(Icons.phone_android, color: Colors.green, size: 18),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _loading ? null : _sendWhatsApp,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('إرسال الرمز', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildEmailForm() {
    return Column(
      children: [
        const Divider(color: Colors.white10),
        const SizedBox(height: 12),
        TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          textAlign: TextAlign.left,
          style: const TextStyle(color: AppTheme.textWhite),
          decoration: const InputDecoration(
            hintText: 'example@email.com',
            prefixIcon: Icon(Icons.mail_outline, color: Colors.blue, size: 18),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _loading ? null : _sendEmailLink,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: const Text('إرسال رابط التسجيل', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordForm() {
    return Column(
      children: [
        const Divider(color: Colors.white10),
        const SizedBox(height: 12),
        TextField(
          controller: _identifierCtrl,
          textAlign: TextAlign.left,
          style: const TextStyle(color: AppTheme.textWhite),
          decoration: const InputDecoration(
            hintText: 'اسم المستخدم أو الهاتف',
            prefixIcon: Icon(Icons.person_outline, color: AppTheme.primaryGold, size: 18),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _passwordCtrl,
          obscureText: _obscure,
          textAlign: TextAlign.left,
          style: const TextStyle(color: AppTheme.textWhite),
          decoration: InputDecoration(
            hintText: 'كلمة المرور',
            prefixIcon: const Icon(Icons.lock_outline, color: AppTheme.primaryGold, size: 18),
            suffixIcon: IconButton(
              icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, size: 18, color: AppTheme.textGrey),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _loading ? null : _loginWithPassword,
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGold),
            child: const Text('دخول', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
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
