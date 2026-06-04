import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import 'package:go_router/go_router.dart';

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

  @override
  void initState() { super.initState(); startTimer(); }
  void startTimer() {
    setState(() { _start = 60; _canResend = false; });
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_start == 0) { setState(() { _timer?.cancel(); _canResend = true; }); }
      else setState(() => _start--);
    });
  }
  @override
  void dispose() { _timer?.cancel(); for (var c in _ctrls) c.dispose(); for (var n in _nodes) n.dispose(); super.dispose(); }
  String get _otp => _ctrls.map((c) => c.text).join();

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios), onPressed: () => context.pop())),
      body: Padding(padding: const EdgeInsets.all(30.0),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text('تحقق من الرمز', style: TextStyle(color: AppTheme.textWhite, fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          const Text('أدخل الرمز المكون من 6 أرقام المرسل إلى هاتفك', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textGrey, fontSize: 16)),
          const SizedBox(height: 40),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: List.generate(6, (i) => SizedBox(
            width: 45,
            child: TextField(controller: _ctrls[i], focusNode: _nodes[i], textAlign: TextAlign.center,
              keyboardType: TextInputType.number, maxLength: 1,
              style: const TextStyle(color: AppTheme.primaryGold, fontSize: 20, fontWeight: FontWeight.bold),
              decoration: InputDecoration(counterText: '', filled: true, fillColor: AppTheme.surfaceBlack,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.primaryGold))),
              onChanged: (v) { if (v.isNotEmpty && i < 5) _nodes[i+1].requestFocus(); else if (v.isEmpty && i > 0) _nodes[i-1].requestFocus(); })))),
          const SizedBox(height: 40),
          SizedBox(width: double.infinity, height: 55,
            child: ElevatedButton(onPressed: () async {
              if (_otp.length == 6) {
                if (await auth.verifyOTP(_otp)) {
                  if (auth.isNewUser) context.push('/setup-profile'); else context.go('/');
                } else ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرمز غير صحيح')));
              } else ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى إكمال الرمز')));
            }, child: const Text('تحقق الآن'))),
          const SizedBox(height: 20),
          TextButton(onPressed: _canResend ? () { auth.sendOTP(auth.currentPhone ?? ''); startTimer(); } : null,
            child: Text(_canResend ? 'إعادة إرسال الرمز' : 'إعادة الإرسال خلال ${_start} ثانية',
              style: TextStyle(color: _canResend ? AppTheme.primaryGold : AppTheme.textGrey, fontWeight: FontWeight.bold))),
        ])),
    );
  }
}
