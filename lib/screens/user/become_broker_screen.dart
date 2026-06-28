import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../core/network/supabase_service.dart';
import '../../core/theme/app_theme.dart';

/// شاشة التقدّم لتصبح وسيطاً
/// يرسل طلب للإدارة (sts=0) وتراجعه الإدارة لاحقاً
class BecomeBrokerScreen extends StatefulWidget {
  const BecomeBrokerScreen({super.key});

  @override
  State<BecomeBrokerScreen> createState() => _BecomeBrokerScreenState();
}

class _BecomeBrokerScreenState extends State<BecomeBrokerScreen> {
  final _businessNameCtrl = TextEditingController();
  final _experienceCtrl = TextEditingController();
  final _aboutCtrl = TextEditingController();
  int _category = 0; // 0=عقارات, 1=سيارات, 2=كلاهما
  bool _agreeTerms = false;
  bool _submitting = false;

  static const Map<int, String> _categories = {
    0: 'عقارات فقط',
    1: 'سيارات فقط',
    2: 'عقارات + سيارات',
  };

  @override
  void dispose() {
    _businessNameCtrl.dispose();
    _experienceCtrl.dispose();
    _aboutCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final auth = context.read<AuthProvider>();
    final user = auth.userModel;
    if (user == null) {
      _snack('يجب تسجيل الدخول أولاً');
      return;
    }

    if (_businessNameCtrl.text.trim().isEmpty) {
      _snack('يرجى إدخال الاسم التجاري');
      return;
    }
    // 🛡️ التوثيق إلزامي للوسطاء (LOGIC_SPEC §2.1)
    if (user.sid.isEmpty || user.img.isEmpty) {
      _snack(
          'التوثيق إلزامي للوسطاء: يجب رفع صورة الهوية + الرقم الوطني أولاً');
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) context.push('/setup-identity');
      });
      return;
    }
    if (!_agreeTerms) {
      _snack('يرجى الموافقة على الشروط والالتزامات');
      return;
    }

    setState(() => _submitting = true);

    try {
      // ✅ Secure via broker-actions Edge Function (submit_request)
      await SupabaseService().client.functions.invoke(
        'broker-actions',
        body: {
          'action': 'submit_request',
          'user_uid': user.uid,
          'business_name': _businessNameCtrl.text.trim(),
          'category': _category,
          'experience': _experienceCtrl.text.trim(),
          'about': _aboutCtrl.text.trim(),
        },
      );

      await auth.refreshUser();

      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          backgroundColor: AppTheme.surfaceBlack,
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 28),
              SizedBox(width: 8),
              Text('تم إرسال الطلب',
                  style: TextStyle(color: AppTheme.textWhite)),
            ],
          ),
          content: const Text(
            'تم إرسال طلبك للإدارة بنجاح ✅\n\n'
            'ستراجع الإدارة طلب الوساطة + توثيق هويتك معاً، وسيصلك إشعار بالنتيجة. '
            'عادة خلال 48 ساعة.',
            style: TextStyle(color: AppTheme.textGrey),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                context.go('/user/home');
              },
              child: const Text('حسناً',
                  style: TextStyle(color: AppTheme.primaryGold)),
            ),
          ],
        ),
      );
    } catch (e) {_snack('حدث خطأ، حاول مرة أخرى');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().userModel;
    final isAlreadyBroker = user?.isBroker == true;
    final hasPendingRequest =
        user?.brkNm.isNotEmpty == true && !isAlreadyBroker;

    return Scaffold(
      backgroundColor: AppTheme.deepBlack,
      appBar: AppBar(
        title: const Text('انضم كوسيط'),
        backgroundColor: AppTheme.deepBlack,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _heroCard(),
            const SizedBox(height: 20),
            if (isAlreadyBroker)
              _alreadyBrokerCard()
            else if (hasPendingRequest)
              _pendingCard()
            else
              _form(),
          ],
        ),
      ),
    );
  }

  Widget _heroCard() {
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
      child: const Column(
        children: [
          Icon(Icons.handshake, color: Colors.black87, size: 48),
          SizedBox(height: 8),
          Text('كن جزءاً من شبكة وسطائنا',
              style: TextStyle(
                  color: Colors.black,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          SizedBox(height: 6),
          Text(
            'احصل على عمولة من كل صفقة، صلاحيات أوسع لإدراج العروض، وأولوية بالظهور.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black87, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _alreadyBrokerCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green),
      ),
      child: Column(
        children: [
          const Icon(Icons.verified, color: Colors.green, size: 48),
          const SizedBox(height: 10),
          const Text('أنت وسيط مفعّل ✅',
              style: TextStyle(
                  color: Colors.green,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => context.go('/broker/dashboard'),
            icon: const Icon(Icons.dashboard, color: Colors.black),
            label: const Text('فتح لوحة الوسيط'),
          ),
        ],
      ),
    );
  }

  Widget _pendingCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange),
      ),
      child: const Column(
        children: [
          Icon(Icons.hourglass_top, color: Colors.orange, size: 48),
          SizedBox(height: 10),
          Text('طلبك قيد المراجعة ⏳',
              style: TextStyle(
                  color: Colors.orange,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          SizedBox(height: 6),
          Text(
            'لقد أرسلت طلباً سابقاً. سنبلغك بمجرد المراجعة.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textGrey),
          ),
        ],
      ),
    );
  }

  Widget _form() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // المزايا
        const Text('✨ مزايا الوسيط',
            style: TextStyle(
                color: AppTheme.primaryGold,
                fontWeight: FontWeight.bold,
                fontSize: 15)),
        const SizedBox(height: 8),
        _benefit('💰', 'حصة من كل صفقة عبر المكتب'),
        _benefit('📊', 'حصة 5 عروض و 5 طلبات (مقابل 1+3 للمستخدم العادي)'),
        _benefit('🎯', 'لوحة تحكم خاصة بالعروض والمواعيد والصفقات'),
        _benefit('📈', 'إحصائيات تفصيلية لأدائك'),
        _benefit('⭐', 'أولوية ظهور بنتائج البحث'),
        const SizedBox(height: 20),

        // النموذج
        const Text('📝 معلومات الطلب',
            style: TextStyle(
                color: AppTheme.primaryGold,
                fontWeight: FontWeight.bold,
                fontSize: 15)),
        const SizedBox(height: 12),
        _label('الاسم التجاري *'),
        TextField(
          controller: _businessNameCtrl,
          style: const TextStyle(color: AppTheme.textWhite),
          decoration: const InputDecoration(
            hintText: 'مثلاً: مكتب النور للعقارات',
            prefixIcon: Icon(Icons.business, color: AppTheme.primaryGold),
          ),
        ),
        const SizedBox(height: 16),

        _label('فئة الوساطة *'),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.surfaceBlack,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: _categories.entries
                .map((e) => RadioListTile<int>(
                      value: e.key,
                      groupValue: _category,
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _category = value);
                      },
                      title: Text(
                        e.value,
                        style: const TextStyle(color: AppTheme.textWhite),
                      ),
                      activeColor: AppTheme.primaryGold,
                      dense: true,
                    ))
                .toList(),
          ),
        ),
        const SizedBox(height: 16),

        _label('سنوات الخبرة (اختياري)'),
        TextField(
          controller: _experienceCtrl,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: AppTheme.textWhite),
          decoration: const InputDecoration(
            hintText: 'مثلاً: 5',
            prefixIcon: Icon(Icons.work_history,
                color: AppTheme.primaryGold),
          ),
        ),
        const SizedBox(height: 16),

        _label('نبذة عنك (اختياري)'),
        TextField(
          controller: _aboutCtrl,
          maxLines: 4,
          style: const TextStyle(color: AppTheme.textWhite),
          decoration: const InputDecoration(
            hintText: 'تحدّث عن خبرتك ومناطق عملك...',
          ),
        ),
        const SizedBox(height: 20),

        // الشروط
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.surfaceBlack,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              const Text(
                '⚠️ شروط والتزامات الوسيط:\n• الالتزام بالأمانة والصدق في العروض\n• تسجيل العمولات للمكتب\n• الاستجابة لطلبات العملاء بسرعة\n• عدم تجاوز الصلاحيات المخوّلة',
                style: TextStyle(color: AppTheme.textGrey, fontSize: 12),
              ),
              const SizedBox(height: 10),
              CheckboxListTile(
                value: _agreeTerms,
                onChanged: (v) =>
                    setState(() => _agreeTerms = v ?? false),
                title: const Text(
                  'أوافق على الشروط والالتزامات',
                  style: TextStyle(
                      color: AppTheme.textWhite, fontSize: 13),
                ),
                activeColor: AppTheme.primaryGold,
                checkColor: Colors.black,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _submitting ? null : _submit,
            icon: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.black))
                : const Icon(Icons.send, color: Colors.black),
            label: const Text('إرسال الطلب للإدارة',
                style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 15)),
          ),
        ),
      ],
    );
  }

  Widget _benefit(String emoji, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
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

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(
                color: AppTheme.primaryGold,
                fontWeight: FontWeight.bold,
                fontSize: 13)),
      );
}
