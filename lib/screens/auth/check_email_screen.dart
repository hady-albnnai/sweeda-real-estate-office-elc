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
                backgroundColor: AppTheme.errorRed));
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
              AppTheme.gapHeightXXL,
              const Text('تحقّق من بريدك الإلكتروني',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: AppTheme.textWhite,
                      fontSize: AppTheme.fontSizeLarge,
                      fontWeight: FontWeight.bold)),
              AppTheme.gapHeightMedium,
              Text(
                'أرسلنا رابط تسجيل دخول إلى:\n${auth.currentEmail ?? ''}\n\nافتح بريدك واضغط الرابط لإكمال الدخول. إذا لم يظهر في الوارد خلال دقيقة افحص Spam / البريد غير المرغوب فيه.',
                textAlign: TextAlign.center,
                style:
                    const TextStyle(color: AppTheme.textGrey, fontSize: AppTheme.fontSizeMedium),
              ),
              if (auth.lastError != null) ...[
                AppTheme.gapHeightMedium,
                Container(
                  width: double.infinity,
                  padding: AppTheme.paddingAllMedium,
                  decoration: BoxDecoration(
                    color: AppTheme.errorRed.withOpacity(0.10),
                    borderRadius: AppTheme.borderRadiusMedium,
                    border: Border.all(color: AppTheme.errorRed.withOpacity(0.35)),
                  ),
                  child: Text(
                    auth.lastError!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.redAccent, fontSize: AppTheme.fontSizeSmall),
                  ),
                ),
              ],
              const const SizedBox(height: AppTheme.spacingXXXL),
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
              AppTheme.gapHeightMedium,
              TextButton(
                onPressed: () => context.go('/login'),
                child: const Text('تغيير طريقة التسجيل',
                    style: TextStyle(color: AppTheme.primaryGold)),
              ),
              const const SizedBox(height: AppTheme.spacingXXXL),
              Container(
                padding: AppTheme.paddingAllLarge,
                decoration: BoxDecoration(
                  color: AppTheme.warningOrange.withOpacity(0.10),
                  borderRadius: AppTheme.borderRadiusMedium,
                  border: Border.all(color: AppTheme.warningOrange.withOpacity(0.45)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: AppTheme.warningOrange, size: 20),
                    AppTheme.gapWidthSmall,
                    Expanded(
                      child: Text(
                        'مهم: أحياناً يصل رابط التفعيل إلى Spam / البريد غير المرغوب فيه. إذا لم تجده في الوارد، افتح هذا المجلد وانقل الرسالة إلى الوارد.',
                        style:
                            TextStyle(color: AppTheme.textWhite, fontSize: AppTheme.fontSizeSmall, height: 1.4),
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
