import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import 'package:go_router/go_router.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final ctrl = TextEditingController();
    return Scaffold(
      body: Stack(children: [
        Positioned(top: -100, right: -100, child: CircleAvatar(radius: 150, backgroundColor: AppTheme.primaryGold.withOpacity(0.1))),
        Positioned(bottom: -80, left: -80, child: CircleAvatar(radius: 120, backgroundColor: AppTheme.primaryGold.withOpacity(0.05))),
        Padding(padding: const EdgeInsets.all(30.0),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Column(children: [
                Container(
                  width: 220, height: 220,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(28),
                    boxShadow: [BoxShadow(color: AppTheme.primaryGold.withOpacity(0.25), blurRadius: 30, spreadRadius: 4)]),
                  child: ClipRRect(borderRadius: BorderRadius.circular(28),
                    child: Image.asset('assets/images/logo_app.png', fit: BoxFit.cover))),
                const SizedBox(height: 24),
                const Text('مرحباً بك مجدداً', style: TextStyle(color: AppTheme.textWhite, fontSize: 28, fontWeight: FontWeight.bold)),
                const Text('سجل دخولك للمتابعة', style: TextStyle(color: AppTheme.textGrey, fontSize: 16)),
              ])),
              const SizedBox(height: 50),
              const Text('رقم الموبايل', style: TextStyle(color: AppTheme.primaryGold, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              TextField(controller: ctrl, keyboardType: TextInputType.phone, textAlign: TextAlign.left,
                style: const TextStyle(color: AppTheme.textWhite),
                decoration: InputDecoration(hintText: '09XXXXXXXX',
                  prefixIcon: Container(padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: const Text('+963', style: TextStyle(color: AppTheme.primaryGold, fontWeight: FontWeight.bold))))),
              const SizedBox(height: 30),
              SizedBox(width: double.infinity, height: 55,
                child: ElevatedButton(onPressed: () async {
                  if (ctrl.text.length == 10) {
                    if (await auth.sendOTP(ctrl.text)) context.push('/otp');
                    else ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('حدث خطأ في إرسال الرمز')));
                  } else ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى إدخال رقم هاتف صحيح')));
                }, child: const Text('إرسال رمز التحقق'))),
            ])),
      ]),
    );
  }
}
