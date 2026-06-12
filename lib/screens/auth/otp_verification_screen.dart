import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import 'package:go_router/go_router.dart';

/// شاشة التحقق من رمز OTP الواتساب (6 أرقام).
class OtpVerificationScreen extends StatefulWidget {
  const OtpVerificationScreen({super.key});
  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _ctrls = List.generate(6, (_) => TextEditingController());
  final _nodes = List.generate(6, (_) => FocusNode());
  Timer? _timer;
  int _start = 60;
  bool _canResend = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    startTimer();
  }

  void startTimer() {
    setState(() {
      _start = 60;
      _canResend = false;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_start == 0) {
        setState(() {
          _timer?.cancel();
          _canResend = true;
        });
      } else {
        setState(() => _start--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var c in _ctrls) c.dispose();
    for (var n in _nodes) n.dispose();
    super.dispose();
  }

  String get _otp => _ctrls.map((c) => c.text).join();

  Future<void> _verify() async {
    if (_otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يرجى إكمال الرمز')));
      return;
    }
    setState(() => _loading = true);
    final auth = context.read<AuthProvider>();
    final ok = await auth.verifyWhatsAppOTP(_otp);
    if (!mounted) return;
    setState(() => _loading = false);
    if (ok) {
      if (auth.isNewUser) {
        context.go('/setup-profile');
      } else if (auth.isAdmin) {
        context.go('/admin/dashboard');
      } else if (auth.isPhotographer) {
        context.go('/photographer/tasks');
      } else if (auth.isBroker) {
        context.go('/broker/dashboard');
      } else {
        context.go('/user/home');
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('الرمز غير صحيح أو منتهي الصلاحية')));
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30),
          child: Column(children: [
            const SizedBox(height: 20),
            const Icon(Icons.chat, color: AppTheme.primaryGold, size: 56),
            const SizedBox(height: 16),
            const Text('تحقق من الرمز',
                style: TextStyle(
                    color: AppTheme.textWhite,
                    fontSize: 26,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text(
              'أدخل الرمز المكوّن من 6 أرقام المرسل عبر واتساب إلى\n${auth.currentPhone ?? ''}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textGrey, fontSize: 14),
            ),
            if (auth.currentOtp != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange),
                ),
                child: Text('🔧 وضع التطوير — الرمز: ${auth.currentOtp}',
                    style: const TextStyle(
                        color: Colors.orange, fontSize: 12)),
              ),
            ],
            const SizedBox(height: 32),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(
                    6,
                    (i) => SizedBox(
                          width: 45,
                          child: TextField(
                            controller: _ctrls[i],
                            focusNode: _nodes[i],
                            textAlign: TextAlign.center,
                            keyboardType: TextInputType.number,
                            maxLength: 1,
                            style: const TextStyle(
                                color: AppTheme.primaryGold,
                                fontSize: 20,
                                fontWeight: FontWeight.bold),
                            decoration: InputDecoration(
                                counterText: '',
                                filled: true,
                                fillColor: AppTheme.surfaceBlack,
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                        color: AppTheme.primaryGold))),
                            onChanged: (v) {
                              if (v.isNotEmpty && i < 5) {
                                _nodes[i + 1].requestFocus();
                              } else if (v.isEmpty && i > 0) {
                                _nodes[i - 1].requestFocus();
                              }
                              if (i == 5 && v.isNotEmpty && _otp.length == 6) {
                                _verify();
                              }
                            },
                          ),
                        )),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _loading ? null : _verify,
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.black))
                    : const Text('تحقق الآن'),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _canResend
                  ? () {
                      auth.sendWhatsAppOTP(auth.currentPhone ?? '');
                      startTimer();
                    }
                  : null,
              child: Text(
                  _canResend
                      ? 'إعادة إرسال الرمز'
                      : 'إعادة الإرسال خلال $_start ثانية',
                  style: TextStyle(
                      color: _canResend
                          ? AppTheme.primaryGold
                          : AppTheme.textGrey,
                      fontWeight: FontWeight.bold)),
            ),
          ]),
        ),
      ),
    );
  }
}
