import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/validation/input_validators.dart';
import '../../core/network/supabase_service.dart';

/// ════════════════════════════════════════════════════════════════════
/// شاشة إعداد الملف الشخصي (إلزامية بعد أول تسجيل).
/// تشمل: الاسم الكامل + رقم الهاتف + اسم المستخدم + كلمة المرور.
/// هذه البيانات تُميّز الحساب وتضمن عدم تكراره.
/// ════════════════════════════════════════════════════════════════════
class SetupProfileScreen extends StatefulWidget {
  const SetupProfileScreen({super.key});

  @override
  State<SetupProfileScreen> createState() => _SetupProfileScreenState();
}

class _SetupProfileScreenState extends State<SetupProfileScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  bool _usernameAvailable = false;
  bool _checkingUsername = false;
  bool _checkFailed = false;

  @override
  void initState() {
    super.initState();
    // نعبّئ الهاتف إذا كان موجوداً (تسجيل SMS)
    final user = context.read<AuthProvider>().userModel;
    if (user != null && user.ph.isNotEmpty) {
      _phoneController.text = user.ph;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
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
          _checkFailed = false;
          _checkingUsername = false;
        });
      }
      return;
    }
    setState(() {
      _checkingUsername = true;
      _checkFailed = false;
    });
    try {
      final res = await SupabaseService().invokeFunction('user-account', body: {'action': 'check_username', 'username': usr});
      final data = res.data is Map ? Map<String, dynamic>.from(res.data) : null;
      final ok = data != null && data['success'] == true && data['available'] == true;
      if (mounted) {
        setState(() {
          _usernameAvailable = ok;
          _checkFailed = false;
          _checkingUsername = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _usernameAvailable = false;
          _checkFailed = true;
          _checkingUsername = false;
        });
      }
    }
  }

  Future<void> _submit() async {
    // 1) الاسم الكامل
    final name = _nameController.text.trim();
    if (name.length < 2) {
      _snack('يرجى إدخال الاسم الكامل (حرفين على الأقل)');
      return;
    }

    // 2) رقم الهاتف
    final phone = InputValidators.normalizeDigits(_phoneController.text.trim());
    if (!RegExp(r'^09[3-9]\d{7}$').hasMatch(phone)) {
      _snack('يرجى إدخال رقم هاتف سوري صحيح (09xxxxxxxx)');
      return;
    }

    // 3) اسم المستخدم
    final username = _usernameController.text.trim().toLowerCase();
    final usernameError = InputValidators.validateRequiredUsername(username);
    if (usernameError != null) {
      _snack(usernameError);
      return;
    }
    if (_checkFailed) {
      _snack('تعذر التحقق من توفر اسم المستخدم، يرجى فحص الاتصال بالإنترنت');
      return;
    }
    if (!_usernameAvailable) {
      _snack('اسم المستخدم محجوز أو غير صالح، اختر اسماً آخر');
      return;
    }

    // 4) كلمة المرور
    final password = _passwordController.text;
    final passwordError = InputValidators.validatePassword(password);
    if (passwordError != null) {
      _snack(passwordError);
      return;
    }
    if (password != _confirmPasswordController.text) {
      _snack('كلمتا المرور غير متطابقتين');
      return;
    }

    // 🛡️ تأكيد حفظ البيانات
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
      _snack('انتهت صلاحية الجلسة، أعد تسجيل الدخول');
      return;
    }

    try {
      // خطوة 1: حفظ الاسم والهاتف
      final profileRes = await SupabaseService().invokeFunction('user-account', body: {
        'action': 'update_profile',
        'user_uid': user.uid,
        'payload': {'nm': name, 'ph': phone},
      });
      final profileData = profileRes.data is Map ? Map<String, dynamic>.from(profileRes.data) : null;
      if (profileData == null || profileData['success'] == false) {
        final err = profileData?['error']?.toString() ?? 'UPDATE_FAILED';
        throw Exception(err);
      }

      // خطوة 2: حفظ اسم المستخدم وكلمة المرور
      final res = await SupabaseService().invokeFunction('user-account', body: {
        'action': 'register_password',
        'user_uid': user.uid,
        'username': username,
        'password': password,
      });

      final data = res.data is Map ? Map<String, dynamic>.from(res.data) : null;
      if (data == null || data['success'] == false) {
        final err = data?['error']?.toString() ?? 'REGISTRATION_FAILED';
        throw Exception(err);
      }

      await auth.refreshUser();
      if (!mounted) return;
      setState(() => _loading = false);

      AppTheme.showSnackBar(context,
        const SnackBar(
          content: Text('✅ تم إنشاء وتأمين حسابك بنجاح'),
          backgroundColor: Colors.green,
        ),
      );

      _navigateByRole(auth);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      final msg = e.toString();
      if (msg.contains('USERNAME_TAKEN')) {
        _snack('اسم المستخدم محجوز، اختر اسماً آخر');
      } else if (msg.contains('PASSWORD_TOO_SHORT') || msg.contains('6') || msg.contains('8')) {
        _snack('كلمة المرور قصيرة، يجب أن تكون 8 أحرف على الأقل');
      } else if (msg.contains('USERNAME_INVALID_CHARS')) {
        _snack('اسم المستخدم يحتوي أحرفاً غير مسموحة');
      } else if (msg.contains('USERNAME_LENGTH')) {
        _snack('اسم المستخدم يجب أن يكون بين 3 و 30 حرفاً');
      } else if (msg.contains('PHONE_INVALID') || msg.contains('PHONE_REQUIRED')) {
        _snack('رقم الهاتف غير صالح');
      } else if (msg.contains('AUTH_TOKEN_REQUIRED') || msg.contains('401') || msg.contains('403')) {
        _snack('انتهت صلاحية الجلسة، الرجاء إعادة تسجيل الدخول');
      } else {
        _snack('حدث خطأ أثناء إعداد الحساب، حاول مرة أخرى');
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
    AppTheme.showSnackBar(context, SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
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
                    'إعداد بيانات الحساب',
                    style: TextStyle(
                        color: AppTheme.textWhite,
                        fontSize: 22,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'جميع الحقول إلزامية — تُستخدم لتمييز حسابك وحمايته',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.textGrey, fontSize: 13),
                  ),
                ]),
              ),
              const SizedBox(height: 24),

              // ─── الاسم الكامل ───
              const Text('الاسم الكامل *',
                  style: TextStyle(
                      color: AppTheme.primaryGold,
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                style: const TextStyle(color: AppTheme.textWhite),
                decoration: InputDecoration(
                  hintText: 'مثلاً: أحمد محمد',
                  prefixIcon: const Icon(Icons.person_outline,
                      color: AppTheme.primaryGold),
                  filled: true,
                  fillColor: AppTheme.surfaceBlack,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),

              // ─── رقم الهاتف ───
              const Text('رقم الهاتف *',
                  style: TextStyle(
                      color: AppTheme.primaryGold,
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
              const SizedBox(height: 8),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: AppTheme.textWhite),
                decoration: InputDecoration(
                  hintText: '09xxxxxxxx',
                  prefixIcon: const Icon(Icons.phone_outlined,
                      color: AppTheme.primaryGold),
                  filled: true,
                  fillColor: AppTheme.surfaceBlack,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),

              // ─── اسم المستخدم ───
              const Text('اسم المستخدم *',
                  style: TextStyle(
                      color: AppTheme.primaryGold,
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
              const SizedBox(height: 4),
              const Text(
                'أحرف عربية أو إنجليزية + أرقام + _ + . (3–30 حرف)',
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
                              _checkFailed
                                  ? Icons.error_outline
                                  : _usernameAvailable
                                      ? Icons.check_circle
                                      : Icons.cancel,
                              color: _checkFailed
                                  ? Colors.orange
                                  : _usernameAvailable
                                      ? Colors.green
                                      : Colors.red,
                              size: 20)
                          : null,
                  filled: true,
                  fillColor: AppTheme.surfaceBlack,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onChanged: (_) => _checkUsername(),
              ),
              const SizedBox(height: 16),

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
                  hintText: '8 أحرف على الأقل',
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
                  filled: true,
                  fillColor: AppTheme.surfaceBlack,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),

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
                  filled: true,
                  fillColor: AppTheme.surfaceBlack,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 24),

              // ─── تنبيه حفظ البيانات ───
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGold.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppTheme.primaryGold.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: AppTheme.primaryGold, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'احفظ اسم المستخدم وكلمة المرور في مكان آمن — ستستخدمهما للدخول مستقبلاً',
                        style: TextStyle(
                            color: AppTheme.textGrey, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

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
