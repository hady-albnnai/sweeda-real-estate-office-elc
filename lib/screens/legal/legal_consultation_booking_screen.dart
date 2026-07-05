import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../providers/auth_provider.dart';
import '../../providers/legal_provider.dart';

class LegalConsultationBookingScreen extends StatefulWidget {
  const LegalConsultationBookingScreen({super.key});

  @override
  State<LegalConsultationBookingScreen> createState() => _LegalConsultationBookingScreenState();
}

class _LegalConsultationBookingScreenState extends State<LegalConsultationBookingScreen> {
  int _selectedService = 0; // 0: هاتفية 50 ألف، 1: مكتبية 200 ألف، 2: باقة التوثيق الشامل 700 ألف
  final _subjectCtrl = TextEditingController();
  bool _submitting = false;

  final List<Map<String, dynamic>> _services = [
    {
      'title': 'استشارة هاتفية صوتية عبر واتساب',
      'price': 50000,
      'duration': '15 دقيقة',
      'icon': Icons.phone_in_talk,
      'desc': 'تواصل صوتي مباشر بالرسائل الصوتية (Voice Notes) عبر واتساب مع المحامي المخصص للإجابة عن استفساراتك القانونية وحل النزاعات السريعة.',
    },
    {
      'title': 'جلسة استشارة مكتبية حضورية',
      'price': 200000,
      'duration': 'لغاية ساعة واحدة',
      'icon': Icons.business,
      'desc': 'اجتماع حضوري وجهاً لوجه في مكتب المستشار القانوني لدراسة الملفات المعقدة، فرز الإرث، وتدقيق المستندات الأصلية ومناقشة تفاصيل العقود.',
    },
    {
      'title': 'باقة التوثيق الشامل وتنظيم العقود',
      'price': 700000,
      'duration': 'باقة قطعية متكاملة',
      'icon': Icons.verified_user,
      'desc': 'الخدمة الملكية الشاملة: تتضمن استخراج وتدقيق كافة الثبوتيات الرسمية (بيانات عقارية، براءة ذمة، كشوفات مرورية) وتنظيم عقود البيع أو الإيجار القطعية المحكمة 100%.',
    },
  ];

  @override
  void dispose() {
    _subjectCtrl.dispose();
    super.dispose();
  }

  void _snack(String m) {
    if (!mounted) return;
    AppTheme.showSnackBar(context, SnackBar(content: Text(m)));
  }

  Future<void> _submit() async {
    if (_subjectCtrl.text.trim().isEmpty) {
      _snack('يرجى إدخال ملخص موضوع الاستشارة أو المعاملة');
      return;
    }
    setState(() => _submitting = true);
    await Future.delayed(const Duration(milliseconds: 800)); // محاكاة حجز الطلب المالي
    if (!mounted) return;
    setState(() => _submitting = false);
    _snack('✅ تم إنشاء الطلب، يرجى رفع إيصال الدفع لتأكيد الموعد');
    context.push('/user/payment');
  }

  Future<void> _openLawyerWhatsapp(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse('https://wa.me/$cleanPhone?text=${Uri.encodeComponent("مرحباً أستاذ، استشارتي المعتمدة من مكتب عقارات السويداء بخصوص: ${_subjectCtrl.text.trim()}")}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _snack('تعذّر فتح تطبيق واتساب');
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeLawyers = context.watch<LegalProvider>().activeLawyers;

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      appBar: AppBar(
        title: const Text('القسم القانوني والاستشارات ⚖️'),
        backgroundColor: AppTheme.scaffoldBackground,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primaryGold.withOpacity(0.15), AppTheme.surfaceBlack],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.primaryGold.withOpacity(0.4)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.gavel, color: AppTheme.primaryGold, size: 36),
                  SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'مظلة أمان قانونية متكاملة بإشراف نخبة المحامين المعتمدين لدى مكتب عقارات السويداء لضمان حقوقك العقارية والمالية.',
                      style: TextStyle(color: AppTheme.textWhite, fontSize: 13, height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text('اختر الخدمة القانونية المطلوبة:', style: TextStyle(color: AppTheme.primaryGold, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...List.generate(_services.length, (i) {
              final s = _services[i];
              final selected = _selectedService == i;
              return GestureDetector(
                onTap: () => setState(() => _selectedService = i),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: selected ? AppTheme.primaryGold.withOpacity(0.12) : AppTheme.surfaceBlack,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: selected ? AppTheme.primaryGold : Colors.white12, width: selected ? 2 : 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(s['icon'] as IconData, color: AppTheme.primaryGold, size: 24),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              s['title'] as String,
                              style: const TextStyle(color: AppTheme.textWhite, fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: AppTheme.primaryGold, borderRadius: BorderRadius.circular(20)),
                            child: Text(
                              AppUtils.formatPrice(s['price'] as num),
                              style: const TextStyle(color: AppTheme.deepBlack, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(s['desc'] as String, style: const TextStyle(color: AppTheme.textGrey, fontSize: 12, height: 1.5)),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 20),
            const Text('ملخص الموضوع أو المعاملة:', style: TextStyle(color: AppTheme.primaryGold, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            TextField(
              controller: _subjectCtrl,
              maxLines: 4,
              style: const TextStyle(color: AppTheme.textWhite),
              decoration: InputDecoration(
                hintText: 'اكتب تفاصيل استفسارك أو رقم العقار/السيارة المطلوب تنظيم عقدها...',
                hintStyle: const TextStyle(color: AppTheme.textGrey),
                filled: true,
                fillColor: AppTheme.surfaceBlack,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: const Icon(Icons.verified_user),
                label: _submitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: AppTheme.deepBlack, strokeWidth: 2))
                    : const Text('تأكيد الطلب والمتابعة للدفع', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
            if (activeLawyers.isNotEmpty && _selectedService == 0) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.green.withOpacity(0.4))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('💬 الاتصال الفوري المعتمد (بعد اعتماد الدفع):', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    const Text('بمجرد قيام الإدارة بتدقيق الإيصال، يُفتح لك زر التواصل المباشر بالرسائل الصوتية عبر واتساب مع المحامي المخصص:', style: TextStyle(color: AppTheme.textWhite, fontSize: 12, height: 1.4)),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _openLawyerWhatsapp(activeLawyers.first.whatsappPhone),
                        icon: const Icon(Icons.chat),
                        label: const Text('تحدث صوتياً عبر واتساب مع المحامي المخصص 💬'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
