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
    // تفعيل التصنيف المناسب تلقائياً حسب الوضع
    _activeCategory = _isSignUp ? 1 : 3;
  }

  @override
  void dispose() {
    _identifierCtrl.dispose();
    _passwordCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

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
          // ─── تأثير الإضاءة الخلفية ───
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
                        // 🛡️ شعار بتصميم السبلاش
                        Hero(
                          tag: 'logo',
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primaryGold.withValues(alpha: 0.15),
                                  blurRadius: 30,
                                ),
                              ],
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppTheme.primaryGold.withValues(alpha: 0.3),
                                      width: 1,
                                    ),
                                  ),
                                ),
                                Container(
                                  width: 112,
                                  height: 112,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppTheme.surfaceBlack,
                                  ),
                                  padding: const EdgeInsets.all(20),
                                  child: Image.asset('assets/images/logo_app.png', fit: BoxFit.contain),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),

                        // ─── وضع إنشاء حساب ───
                        if (_isSignUp) ...[
                          _authCategory(
                            id: 1,
                            title: 'عبر الواتساب (موصى به)',
                            subtitle: 'سجّل بلمحة بصر عبر تطبيق الواتساب',
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
                              _activeCategory = 3; // افتح كلمة المرور تلقائياً
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
                              _activeCategory = 1; // افتح واتساب تلقائياً
                            }),
                            child: const Text('ليس لديك حساب؟ أنشئ حساباً جديداً', style: TextStyle(color: AppTheme.textGrey, fontSize: 13)),
                          ),
                        ],
                        const SizedBox(height: 20),
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
