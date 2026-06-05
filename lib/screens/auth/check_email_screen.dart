import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';

/// شاشة "تحقق من بريدك" — تظهر بعد إرسال Magic Link.
/// المستخدم يفتح إيميله، يضغط الرابط، فيُفتح التطبيق عبر deep link
/// ويتم إكمال تسجيل الدخول تلقائياً.
class CheckEmailScreen extends StatelessWidget {
  const CheckEmailScreen({super.key});

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
                  onPressed: () {
                    if (auth.currentEmail != null) {
                      auth.sendEmailMagicLink(auth.currentEmail!);
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('تم إعادة إرسال الرابط')));
                    }
                  },
                  icon: const Icon(Icons.refresh, color: Colors.black),
                  label: const Text('إعادة الإرسال'),
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
