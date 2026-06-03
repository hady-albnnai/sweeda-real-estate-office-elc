import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import 'package:go_router/go_router.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final TextEditingController phoneController = TextEditingController();

    return Scaffold(
      body: Stack(
        children: [
          // Background dark
          Container(
            color: AppTheme.deepBlack,
          ),
          Padding(
            padding: const EdgeInsets.all(30.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo/Header
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppTheme.primaryGold,
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryGold.withOpacity(0.3),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/images/logo.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),
                      const Text(
                        'المكتب العقاري الالكتروني',
                        style: TextStyle(
                          color: AppTheme.primaryGold,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 15),
                      const Text(
                        'مرحباً بك مجدداً',
                        style: TextStyle(
                          color: AppTheme.textWhite,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        'سجل دخولك للمتابعة',
                        style: TextStyle(color: AppTheme.textGrey, fontSize: 16),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 50),
                // Phone Input
                const Text(
                  'رقم الموبايل',
                  style: TextStyle(color: AppTheme.primaryGold, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  textAlign: TextAlign.left,
                  style: const TextStyle(color: AppTheme.textWhite),
                  decoration: InputDecoration(
                    hintText: '09XXXXXXXX',
                    prefixIcon: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        '+963',
                        style: const TextStyle(color: AppTheme.primaryGold, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                // Login Button
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (phoneController.text.length == 10) {
                        bool success = await authProvider.sendOTP(phoneController.text);
                        if (success) {
                          context.push('/otp');
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('حدث خطأ في إرسال الرمز')),
                          );
                        }
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('يرجى إدخال رقم هاتف صحيح')),
                        );
                      }
                    },
                    child: const Text('إرسال رمز التحقق'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
