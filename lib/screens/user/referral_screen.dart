import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../providers/auth_provider.dart';
import '../../providers/config_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/network/supabase_service.dart';

/// شاشة الإحالة (Referral)
/// كل مستخدم له كود فريد (أول 8 أحرف من uid).
/// عند تسجيل حساب جديد بهذا الكود → الطرفان يحصلان على pts.ref نقاط.
class ReferralScreen extends StatefulWidget {
  const ReferralScreen({super.key});

  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  int _referralCount = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final auth = context.read<AuthProvider>();
    final user = auth.userModel;
    if (user == null) return;
    try {
      final res = await SupabaseService()
          .client
          .from('users')
          .select('ref_cnt')
          .eq('id', user.uid)
          .maybeSingle();
      if (!mounted) return;
      setState(() {
        _referralCount = (res?['ref_cnt'] as int?) ?? 0;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  String _refCode(String uid) {
    return uid.replaceAll('-', '').substring(0, 8).toUpperCase();
  }

  String _refLink(String code) =>
      'https://sweeda-realestate.com/invite?code=$code';

  Future<void> _copyCode(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (mounted) {
      AppTheme.showSnackBar(context,
        const SnackBar(content: Text('✅ تم نسخ الكود'),
            duration: Duration(seconds: 1)),
      );
    }
  }

  Future<void> _share(String code) async {
    final link = _refLink(code);
    await SharePlus.instance.share(
      ShareParams(
        text: 'انضم للمكتب العقاري الالكتروني واحصل على نقاط ترحيب! 🎁\n\nاستخدم كود الدعوة: $code\nأو اضغط الرابط: $link',
        subject: 'دعوة إلى المكتب العقاري الالكتروني',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final config = context.watch<ConfigProvider>().config;
    final user = auth.userModel;
    final refPts = config?.data['pts']?['ref'] ?? 1500;

    if (user == null) {
      return const Scaffold(
        backgroundColor: AppTheme.scaffoldBackground,
        body: Center(
            child: Text('سجّل دخولك أولاً',
                style: TextStyle(color: AppTheme.textGrey))),
      );
    }

    final code = _refCode(user.uid);

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      appBar: AppBar(
        title: const Text('دعوة الأصدقاء'),
        backgroundColor: AppTheme.scaffoldBackground,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _heroCard(refPts),
            const SizedBox(height: 20),
            _codeCard(code),
            const SizedBox(height: 20),
            _statsCard(refPts),
            const SizedBox(height: 20),
            _howItWorksCard(refPts),
          ],
        ),
      ),
    );
  }

  Widget _heroCard(int refPts) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFD4AF37), Color(0xFFFFD700)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          const Icon(Icons.card_giftcard,
              color: Colors.black87, size: 48),
          const SizedBox(height: 8),
          const Text('ادعُ صديقاً واربحوا معاً!',
              style: TextStyle(
                  color: Colors.black,
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(
            '$refPts نقطة لك + $refPts لصديقك عند تسجيل حسابه',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black87, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _codeCard(String code) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBlack,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primaryGold.withOpacity(0.4)),
      ),
      child: Column(
        children: [
          const Text('كود الدعوة الخاص بك',
              style: TextStyle(color: AppTheme.textGrey, fontSize: 13)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: BoxDecoration(
              color: AppTheme.deepBlack,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.primaryGold),
            ),
            child: Text(
              code,
              style: const TextStyle(
                color: AppTheme.primaryGold,
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _copyCode(code),
                  icon: const Icon(Icons.copy,
                      color: AppTheme.primaryGold),
                  label: const Text('نسخ',
                      style: TextStyle(color: AppTheme.primaryGold)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.primaryGold),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _share(code),
                  icon: const Icon(Icons.share, color: Colors.black),
                  label: const Text('مشاركة',
                      style: TextStyle(
                          color: Colors.black, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statsCard(int refPts) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBlack,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                const Icon(Icons.people, color: AppTheme.primaryGold, size: 28),
                const SizedBox(height: 6),
                _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.primaryGold))
                    : Text('$_referralCount',
                        style: const TextStyle(
                            color: AppTheme.textWhite,
                            fontSize: 24,
                            fontWeight: FontWeight.bold)),
                const Text('أصدقاء انضمّوا',
                    style: TextStyle(
                        color: AppTheme.textGrey, fontSize: 11)),
              ],
            ),
          ),
          Container(width: 1, height: 50, color: AppTheme.textGrey),
          Expanded(
            child: Column(
              children: [
                const Icon(Icons.stars,
                    color: AppTheme.primaryGold, size: 28),
                const SizedBox(height: 6),
                Text('${_referralCount * refPts}',
                    style: const TextStyle(
                        color: AppTheme.textWhite,
                        fontSize: 24,
                        fontWeight: FontWeight.bold)),
                const Text('نقطة مكتسبة',
                    style: TextStyle(
                        color: AppTheme.textGrey, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _howItWorksCard(int refPts) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBlack,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🎯 كيف يعمل؟',
              style: TextStyle(
                  color: AppTheme.primaryGold,
                  fontWeight: FontWeight.bold,
                  fontSize: 14)),
          const SizedBox(height: 10),
          _step('1', 'شارك كودك مع أصدقائك'),
          _step('2', 'يسجّل صديقك حساب جديد ويدخل الكود'),
          _step('3', 'تحصلان كلاكما على $refPts نقطة فوراً'),
          _step('4', 'النقاط تُضاف لرصيدك تلقائياً'),
        ],
      ),
    );
  }

  Widget _step(String num, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: AppTheme.primaryGold,
            child: Text(num,
                style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 12)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    color: AppTheme.textWhite, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
