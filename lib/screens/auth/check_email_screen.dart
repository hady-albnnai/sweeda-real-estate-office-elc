import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';

/// شاشة "تحقق من بريدك" — تظهر بعد إرسال Magic Link.
/// المستخدم يفتح إيميله، يضغط الرابط، فيُفتح التطبيق عبر deep link
/// ويتم إكمال تسجيل الدخول تلقائياً.
class CheckEmailScreen extends StatefulWidget {
  const CheckEmailScreen({super.key});

  @override
  State<CheckEmailScreen> createState() => _CheckEmailScreenState();
}

class _CheckEmailScreenState extends State<CheckEmailScreen> {
  Timer? _resendTimer;
  int _resendCooldown = 0;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    // بدء فترة التبريد الأولى (60 ثانية بعد الإرسال الأولي)
    _startResendCooldown();
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    super.dispose();
  }

  void _startResendCooldown() {
    setState(() => _resendCooldown = 60);
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCooldown <= 1) {
        timer.cancel();
        if (mounted) setState(() => _resendCooldown = 0);
      } else {
        if (mounted) setState(() => _resendCooldown--);
      }
    });
  }

  Future<void> _resendLink() async {
    final auth = context.read<AuthProvider>();
    if (auth.currentEmail == null) return;

    setState(() => _sending = true);
    final ok = await auth.sendEmailMagicLink(auth.currentEmail!);
    if (!mounted) return;
    setState(() => _sending = false);

    if (ok) {
      _startResendCooldown();
      if (mounted) {
        AppTheme.showSnackBar(context,
            const SnackBar(content: Text('تم إعادة إرسال الرابط')));
      }
    } else {
      if (mounted) {
        AppTheme.showSnackBar(
            context,
            const SnackBar(
                content: Text('فشل إعادة الإرسال، حاول بعد قليل'),
                backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios),
              onPressed: () => context.pop())),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.mark_email_unread,
                  color: AppTheme.primaryGold, size: 88),
              const SizedBox(height: 24),
              const Text('تحقّق من بريدك الإلكتروني',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: AppTheme.textWhite,
                      fontSize: 24,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text(
                'أرسلنا رابط تسجيل دخول إلى:\n${auth.currentEmail ?? ''}\n\nافتح بريدك واضغط الرابط لإكمال الدخول.',
                textAlign: TextAlign.center,
                style:
                    const TextStyle(color: AppTheme.textGrey, fontSize: 14),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _resendCooldown > 0 || _sending
                      ? null
                      : _resendLink,
                  icon: _sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.black),
                        )
                      : const Icon(Icons.refresh, color: Colors.black),
                  label: Text(_resendCooldown > 0
                      ? 'إعادة الإرسال بعد $_resendCooldown ثانية'
                      : 'إعادة الإرسال'),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => context.go('/login'),
                child: const Text('تغيير طريقة التسجيل',
                    style: TextStyle(color: AppTheme.primaryGold)),
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceBlack,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: AppTheme.primaryGold, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'لم يصل الرابط؟ تحقّق من مجلد الـ Spam / غير المرغوب فيه.',
                        style:
                            TextStyle(color: AppTheme.textGrey, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
