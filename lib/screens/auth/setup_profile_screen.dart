import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/validation/input_validators.dart';
import '../../core/network/supabase_service.dart';

/// ════════════════════════════════════════════════════════════════════
/// شاشة إعداد اسم المستخدم + كلمة المرور (إلزامية بعد أول تسجيل عبر OTP).
/// الهوية (رقم وطني + صورة) تُترك لخيار التوثيق لاحقاً.
/// ════════════════════════════════════════════════════════════════════
class SetupProfileScreen extends StatefulWidget {
  const SetupProfileScreen({super.key});

  @override
  State<SetupProfileScreen> createState() => _SetupProfileScreenState();
}

class _SetupProfileScreenState extends State<SetupProfileScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  bool _usernameAvailable = false;
  bool _checkingUsername = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  /// فحص توفر اسم المستخدم لحظياً
  Future<void> _checkUsername() async {
    final usr = _usernameController.text.trim().toLowerCase();
    if (usr.length < 3) {
      if (mounted) {
        setState(() {
          _usernameAvailable = false;
          _checkingUsername = false;
        });
      }
      return;
    }
    setState(() => _checkingUsername = true);
    try {
      final res = await SupabaseService().client.functions.invoke('user-account', body: {'action': 'check_username', 'username': usr}); final data = res.data as Map; final ok = data['success'] == true && data['available'] == true;
      if (mounted) {
        setState(() {
          _usernameAvailable = ok == true;
          _checkingUsername = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _checkingUsername = false);
    }
  }

  Future<void> _submit() async {
    final username = _usernameController.text.trim().toLowerCase();
    final password = _passwordController.text;

    final usernameError = InputValidators.validateRequiredUsername(username);
    if (usernameError != null) {
      _snack(usernameError);
      return;
    }
    if (!_usernameAvailable) {
      _snack('اسم المستخدم محجوز، اختر اسماً آخر');
      return;
    }
    final passwordError = InputValidators.validatePassword(password);
    if (passwordError != null) {
      _snack(passwordError);
      return;
    }
    if (password != _confirmPasswordController.text) {
      _snack('كلمتا المرور غير متطابقتين');
      return;
    }

    // 🛡️ طلب حفظ البيانات (User Requirement)
    final save = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceBlack,
        title: const Text('تأكيد حفظ البيانات', style: TextStyle(color: AppTheme.textWhite)),
        content: const Text(
          'هل قمت بحفظ اسم المستخدم وكلمة المرور في مكان آمن؟\nستحتاج إليهما للدخول مستقبلاً.',
          style: TextStyle(color: AppTheme.textGrey),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('انتظر')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('نعم، حفظتها')),
        ],
      ),
    );

    if (save != true) return;

    setState(() => _loading = true);
    final auth = context.read<AuthProvider>();
    final user = auth.userModel;
    if (user == null) {
      setState(() => _loading = false);
      _snack('انتهت الجلسة، أعد تسجيل الدخول');
      return;
    }

    try {
      await SupabaseService().client.functions.invoke('user-account', body: {'action': 'register_password', 'p_user_uid': user.uid, 'p_username': username, 'p_password': password});

      await auth.refreshUser();
      if (!mounted) return;
      setState(() => _loading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ تم إنشاء وتأمين حسابك بنجاح'),
          backgroundColor: Colors.green,
        ),
      );

      _navigateByRole(auth);
    } catch (e) {
      setState(() => _loading = false);
      final msg = e.toString();
      if (msg.contains('USERNAME_TAKEN')) {
        _snack('اسم المستخدم محجوز، اختر اسماً آخر');
      } else {
        _snack('حدث خطأ، حاول مرة أخرى');
      }
    }
  }

  void _navigateByRole(AuthProvider auth) {
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
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.deepBlack,
      appBar: AppBar(
        title: const Text('إعداد الحساب'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── أيقونة + عنوان ───
              Center(
                child: Column(children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGold.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.lock_person_outlined,
                        color: AppTheme.primaryGold, size: 36),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'إعداد بيانات الدخول',
                    style: TextStyle(
                        color: AppTheme.textWhite,
                        fontSize: 22,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'اختر اسم مستخدم وكلمة مرور لتسجيل الدخول لاحقاً',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.textGrey, fontSize: 13),
                  ),
                ]),
              ),
              const SizedBox(height: 28),

              // ─── اسم المستخدم ───
              const Text('اسم المستخدم *',
                  style: TextStyle(
                      color: AppTheme.primaryGold,
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
              const SizedBox(height: 4),
              const Text(
                'أحرف إنجليزية + أرقام + _ + . (3–30 حرف)',
                style: TextStyle(color: AppTheme.textGrey, fontSize: 11),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _usernameController,
                textAlign: TextAlign.left,
                textDirection: TextDirection.ltr,
                style: const TextStyle(
                    color: AppTheme.textWhite, letterSpacing: 1),
                decoration: InputDecoration(
                  hintText: 'مثلاً: ahmed_123',
                  prefixIcon: const Icon(Icons.alternate_email,
                      color: AppTheme.primaryGold),
                  suffixIcon: _checkingUsername
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppTheme.primaryGold)),
                        )
                      : _usernameController.text.trim().length >= 3
                          ? Icon(
                              _usernameAvailable
                                  ? Icons.check_circle
                                  : Icons.cancel,
                              color: _usernameAvailable
                                  ? Colors.green
                                  : Colors.red,
                              size: 20)
                          : null,
                ),
                onChanged: (_) => _checkUsername(),
              ),
              const SizedBox(height: 18),

              // ─── كلمة المرور ───
              const Text('كلمة المرور *',
                  style: TextStyle(
                      color: AppTheme.primaryGold,
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
              const SizedBox(height: 8),
              TextField(
                controller: _passwordController,
                obscureText: _obscure,
                textAlign: TextAlign.left,
                textDirection: TextDirection.ltr,
                style: const TextStyle(color: AppTheme.textWhite),
                decoration: InputDecoration(
                  hintText: '6 أحرف على الأقل',
                  prefixIcon: const Icon(Icons.lock_outline,
                      color: AppTheme.primaryGold),
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
              ),
              const SizedBox(height: 18),

              // ─── تأكيد كلمة المرور ───
              const Text('تأكيد كلمة المرور *',
                  style: TextStyle(
                      color: AppTheme.primaryGold,
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
              const SizedBox(height: 8),
              TextField(
                controller: _confirmPasswordController,
                obscureText: _obscure,
                textAlign: TextAlign.left,
                textDirection: TextDirection.ltr,
                style: const TextStyle(color: AppTheme.textWhite),
                decoration: InputDecoration(
                  hintText: 'أعد إدخال كلمة المرور',
                  prefixIcon: const Icon(Icons.lock_rounded,
                      color: AppTheme.primaryGold),
                ),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 28),

              // ─── زر الإرسال ───
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _submit,
                  icon: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.black),
                        )
                      : const Icon(Icons.check_rounded, color: Colors.black),
                  label: const Text('حفظ ومتابعة',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 14),
              const Center(
                child: Text(
                  '🔒 بياناتك مشفّرة ومحفوظة بأمان',
                  style: TextStyle(color: AppTheme.textGrey, fontSize: 11),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
