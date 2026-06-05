import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import 'package:go_router/go_router.dart';

/// شاشة تسجيل الدخول الموحّدة:
///   • تبويبة WhatsApp (افتراضية، بتستخدم رقم الموبايل + OTP عبر واتساب)
///   • تبويبة Email (Magic Link)
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

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

  Future<void> _sendMagicLink() async {
    final email = _emailCtrl.text.trim();
    if (!_isValidEmail(email)) {
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

  bool _isValidEmail(String s) =>
      RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$').hasMatch(s);

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        Positioned(
            top: -100,
            right: -100,
            child: CircleAvatar(
                radius: 150,
                backgroundColor: AppTheme.primaryGold.withOpacity(0.1))),
        Positioned(
            bottom: -80,
            left: -80,
            child: CircleAvatar(
                radius: 120,
                backgroundColor: AppTheme.primaryGold.withOpacity(0.05))),
        SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                Center(
                    child: Column(children: [
                  Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                              color: AppTheme.primaryGold.withOpacity(0.25),
                              blurRadius: 30,
                              spreadRadius: 4)
                        ]),
                    child: ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: Image.asset('assets/images/logo_app.png',
                            fit: BoxFit.cover)),
                  ),
                  const SizedBox(height: 20),
                  const Text('مرحباً بك مجدداً',
                      style: TextStyle(
                          color: AppTheme.textWhite,
                          fontSize: 26,
                          fontWeight: FontWeight.bold)),
                  const Text('سجّل دخولك للمتابعة',
                      style: TextStyle(
                          color: AppTheme.textGrey, fontSize: 15)),
                ])),
                const SizedBox(height: 30),
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
                    labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                    dividerColor: Colors.transparent,
                    tabs: const [
                      Tab(
                        icon: Icon(Icons.chat, size: 20),
                        text: 'واتساب',
                        iconMargin: EdgeInsets.only(bottom: 2),
                      ),
                      Tab(
                        icon: Icon(Icons.email, size: 20),
                        text: 'إيميل',
                        iconMargin: EdgeInsets.only(bottom: 2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // ─── محتوى التبويبات ───
                SizedBox(
                  height: 220,
                  child: TabBarView(
                    controller: _tab,
                    children: [
                      _whatsappTab(),
                      _emailTab(),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'بتسجيلك توافق على شروط الاستخدام وسياسة الخصوصية.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textGrey, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  Widget _whatsappTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('رقم الموبايل',
            style: TextStyle(
                color: AppTheme.primaryGold, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        TextField(
          controller: _phoneCtrl,
          keyboardType: TextInputType.phone,
          textAlign: TextAlign.left,
          style: const TextStyle(color: AppTheme.textWhite),
          decoration: InputDecoration(
            hintText: '09XXXXXXXX',
            prefixIcon: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              alignment: Alignment.center,
              width: 60,
              child: const Text('+963',
                  style: TextStyle(
                      color: AppTheme.primaryGold,
                      fontWeight: FontWeight.bold)),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 60),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'سترسل لك رسالة عبر واتساب تحتوي رمز تحقق.',
          style: TextStyle(color: AppTheme.textGrey, fontSize: 12),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _loading ? null : _sendWhatsApp,
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.black))
                : const Icon(Icons.chat, color: Colors.black),
            label: const Text('إرسال عبر واتساب'),
          ),
        ),
      ],
    );
  }

  Widget _emailTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('البريد الإلكتروني',
            style: TextStyle(
                color: AppTheme.primaryGold, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          textAlign: TextAlign.left,
          style: const TextStyle(color: AppTheme.textWhite),
          decoration: const InputDecoration(
            hintText: 'name@example.com',
            prefixIcon: Icon(Icons.email, color: AppTheme.primaryGold),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'سيتم إرسال رابط سحري إلى بريدك. اضغطه لتسجيل الدخول مباشرة.',
          style: TextStyle(color: AppTheme.textGrey, fontSize: 12),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _loading ? null : _sendMagicLink,
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.black))
                : const Icon(Icons.send, color: Colors.black),
            label: const Text('إرسال الرابط السحري'),
          ),
        ),
      ],
    );
  }
}
