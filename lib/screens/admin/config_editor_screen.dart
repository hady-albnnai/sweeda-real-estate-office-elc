import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/config_provider.dart';
import '../../core/theme/app_theme.dart';
import 'payment_channels_editor_screen.dart';

/// ⚙️ محرّر إعدادات التطبيق الديناميكية (app_config / key=main)
/// يعرض القيم الحالية ويسمح بتعديل النقاط/العمولة/الحصص بسرعة.
class ConfigEditorScreen extends StatefulWidget {
  const ConfigEditorScreen({super.key});

  @override
  State<ConfigEditorScreen> createState() => _ConfigEditorScreenState();
}

class _ConfigEditorScreenState extends State<ConfigEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  // متحكّمات الحقول الشائعة
  final _signupPts = TextEditingController();
  final _weeklyPts = TextEditingController();
  final _addOfferPts = TextEditingController();
  final _dealDonePts = TextEditingController();
  final _sellCom = TextEditingController();
  final _userOffersQuota = TextEditingController();
  final _brokerOffersQuota = TextEditingController();

  // ── Video request WhatsApp (مدير + نائب المدير فقط) ──
  final _videoWaNumber = TextEditingController();
  final _videoGroupLink = TextEditingController();

  // ── صفحات التواصل الاجتماعي (قابلة للتوسعة) ──
  final _facebookCtrl = TextEditingController();
  final _instagramCtrl = TextEditingController();
  final _developerPhoneCtrl = TextEditingController();
  bool _socialAutoPublish = false;
  // للصفحات الإضافية: نستخدم قائمة بسيطة (key: label, value: url)
  final List<Map<String, TextEditingController>> _extraSocialCtrls = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final prov = context.read<ConfigProvider>();
    await prov.loadConfig();
    final c = prov.config;
    if (c != null && mounted) {
      setState(() {
        _signupPts.text = '${c.signupPoints}';
        _weeklyPts.text = '${c.weeklyLoginPoints}';
        _addOfferPts.text = '${c.addOfferPoints}';
        _dealDonePts.text = '${c.dealDonePoints}';
        _sellCom.text = '${c.sellCommission}';
        _userOffersQuota.text = '${c.userQuotas['o'] ?? 1}';
        _brokerOffersQuota.text = '${c.brokerQuotas['o'] ?? 5}';

        // Video WhatsApp dedicated + group link (for video requests)
        final txts = c.texts;
        _videoWaNumber.text = (txts['videoRequestWhatsApp'] ?? '').toString();
        _videoGroupLink.text = (txts['videoRequestGroupLink'] ?? '').toString();

        // Social pages
        _facebookCtrl.text = c.facebookPage;
        _instagramCtrl.text = c.instagramPage;
        _developerPhoneCtrl.text = c.developerPhone;
        _socialAutoPublish = c.socialAutoPublish;

        // Extra social pages (socialPages)
        final extra = c.socialPages;
        _extraSocialCtrls.clear();
        extra.forEach((key, val) {
          final labelCtrl = TextEditingController(text: key);
          final urlCtrl = TextEditingController(text: val?.toString() ?? '');
          _extraSocialCtrls.add({'label': labelCtrl, 'url': urlCtrl});
        });
        if (_extraSocialCtrls.isEmpty) {
          _extraSocialCtrls.add({'label': TextEditingController(), 'url': TextEditingController()});
        }
      });
    }
  }

  @override
  void dispose() {
    for (final c in [
      _signupPts,
      _weeklyPts,
      _addOfferPts,
      _dealDonePts,
      _sellCom,
      _userOffersQuota,
      _brokerOffersQuota,
      _videoWaNumber,
      _videoGroupLink,
      _facebookCtrl,
      _instagramCtrl,
      _developerPhoneCtrl,
    ]) {
      c.dispose();
    }
    for (final map in _extraSocialCtrls) {
      map['label']?.dispose();
      map['url']?.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ConfigProvider>();

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      appBar: AppBar(
        title: const Text('إعدادات التطبيق'),
        backgroundColor: AppTheme.scaffoldBackground,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.primaryGold),
            onPressed: _load,
          ),
        ],
      ),
      body: prov.isLoading && prov.config == null
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryGold))
          : prov.config == null
              ? _error(prov.error)
              : Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _warning(),
                      const SizedBox(height: 16),
                      _section('⭐ النقاط'),
                      _numField('نقاط التسجيل', _signupPts),
                      _numField('نقاط الدخول الأسبوعي', _weeklyPts),
                      _numField('نقاط إضافة عرض', _addOfferPts),
                      _numField('نقاط إتمام صفقة', _dealDonePts),
                      const SizedBox(height: 20),
                      _section('💰 العمولة'),
                      _numField('عمولة البيع (%)', _sellCom),
                      const SizedBox(height: 20),
                      _section('📊 الحصص (عدد العروض)'),
                      _numField('حصة المستخدم', _userOffersQuota),
                      _numField('حصة الوسيط', _brokerOffersQuota),
                      const SizedBox(height: 20),

                      // ── 🎥 طلبات الفيديو (مدير + نائب المدير فقط)
                      _section('🎥 طلبات الفيديو (خاصة)'),
                      Container(
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.withOpacity(0.3)),
                        ),
                        child: const Text(
                          '⚠️ هذه الخانتان مخصصتان للمدير ونائب المدير فقط.\n'
                          '• الرقم الأول: الواتساب الخاص بطلبات الفيديو (يفضل).\n'
                          '• الرابط الثاني: مجموعة احتياطية في حال تم حظر الرقم.\n'
                          'يتم استخدامهما تلقائياً بعد حجز الموعد من زر "مشاهدة الفيديو".',
                          style: TextStyle(color: AppTheme.textWhite, fontSize: 12, height: 1.45),
                        ),
                      ),
                      TextFormField(
                        controller: _videoWaNumber,
                        keyboardType: TextInputType.phone,
                        style: const TextStyle(color: AppTheme.textWhite),
                        decoration: const InputDecoration(
                          labelText: 'رقم الواتساب المخصص لطلبات الفيديو (09xxxxxxxx أو +963...)',
                          hintText: '0933123456',
                          filled: true,
                          fillColor: AppTheme.surfaceBlack,
                          prefixIcon: Icon(Icons.phone, color: AppTheme.primaryGold),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _videoGroupLink,
                        style: const TextStyle(color: AppTheme.textWhite),
                        decoration: const InputDecoration(
                          labelText: 'رابط المجموعة الاحتياطي (في حال حظر الرقم)',
                          hintText: 'https://chat.whatsapp.com/XXXXX أو wa.me/963...',
                          filled: true,
                          fillColor: AppTheme.surfaceBlack,
                          prefixIcon: Icon(Icons.link, color: AppTheme.primaryGold),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ── 📣 صفحات التواصل الاجتماعي (فيسبوك + إنستغرام + قابلة للتوسعة)
                      _section('📣 صفحات التواصل الاجتماعي'),
                      Container(
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.withOpacity(0.3)),
                        ),
                        child: const Text(
                          '• روابط الصفحات الرسمية تظهر في "عن التطبيق".\n'
                          '• يمكنك إضافة صفحات جديدة (تيك توك، إلخ).\n'
                          '• النشر التلقائي يعتمد على i_soc في العرض + socTxt الجاهز.',
                          style: TextStyle(color: AppTheme.textWhite, fontSize: 12, height: 1.4),
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceBlack,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.blue.withOpacity(0.35)),
                        ),
                        child: SwitchListTile(
                          value: _socialAutoPublish,
                          onChanged: (value) => setState(() => _socialAutoPublish = value),
                          activeColor: AppTheme.primaryGold,
                          secondary: const Icon(Icons.auto_awesome, color: Colors.blue),
                          title: const Text('النشر التلقائي فور قبول العرض',
                              style: TextStyle(color: AppTheme.textWhite, fontWeight: FontWeight.bold)),
                          subtitle: const Text(
                            'عند تعطيله يبقى العرض في قائمة «جاهز للنشر» ويُنشر من الزر اليدوي.',
                            style: TextStyle(color: AppTheme.textGrey, fontSize: 11),
                          ),
                        ),
                      ),
                      TextFormField(
                        controller: _facebookCtrl,
                        style: const TextStyle(color: AppTheme.textWhite),
                        decoration: const InputDecoration(
                          labelText: 'رابط صفحة فيسبوك الرسمية',
                          hintText: 'https://facebook.com/sweeda.realestate',
                          filled: true,
                          fillColor: AppTheme.surfaceBlack,
                          prefixIcon: Icon(Icons.facebook, color: AppTheme.primaryGold),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _instagramCtrl,
                        style: const TextStyle(color: AppTheme.textWhite),
                        decoration: const InputDecoration(
                          labelText: 'رابط حساب إنستغرام الرسمي',
                          hintText: 'https://instagram.com/sweeda.realestate',
                          filled: true,
                          fillColor: AppTheme.surfaceBlack,
                          prefixIcon: Icon(Icons.camera_alt, color: AppTheme.primaryGold),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _developerPhoneCtrl,
                        keyboardType: TextInputType.phone,
                        style: const TextStyle(color: AppTheme.textWhite),
                        decoration: const InputDecoration(
                          labelText: 'رقم هاتف المطور (للتواصل في عن التطبيق)',
                          hintText: '0933123456',
                          filled: true,
                          fillColor: AppTheme.surfaceBlack,
                          prefixIcon: Icon(Icons.phone, color: AppTheme.primaryGold),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text('صفحات إضافية (تيك توك، إلخ — اكتب الاسم ثم الرابط):', style: TextStyle(color: AppTheme.textGrey, fontSize: 12)),
                      ..._extraSocialCtrls.map((ctrls) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  controller: ctrls['label']!,
                                  style: const TextStyle(color: AppTheme.textWhite),
                                  decoration: const InputDecoration(
                                    hintText: 'الاسم (مثل tiktok)',
                                    filled: true,
                                    fillColor: AppTheme.surfaceBlack,
                                    isDense: true,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 3,
                                child: TextFormField(
                                  controller: ctrls['url']!,
                                  style: const TextStyle(color: AppTheme.textWhite),
                                  decoration: const InputDecoration(
                                    hintText: 'الرابط الكامل',
                                    filled: true,
                                    fillColor: AppTheme.surfaceBlack,
                                    isDense: true,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.remove_circle, color: Colors.red),
                                onPressed: () {
                                  setState(() {
                                    _extraSocialCtrls.remove(ctrls);
                                    if (_extraSocialCtrls.isEmpty) {
                                      _extraSocialCtrls.add({'label': TextEditingController(), 'url': TextEditingController()});
                                    }
                                  });
                                },
                              ),
                            ],
                          ),
                        );
                      }),
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _extraSocialCtrls.add({'label': TextEditingController(), 'url': TextEditingController()});
                          });
                        },
                        icon: const Icon(Icons.add, color: AppTheme.primaryGold),
                        label: const Text('إضافة صفحة تواصل جديدة', style: TextStyle(color: AppTheme.primaryGold)),
                      ),
                      const SizedBox(height: 20),

                      _section('💳 قنوات الدفع'),
                      _navTile(
                        icon: Icons.payments,
                        title: 'إدارة قنوات الدفع',
                        subtitle: 'الهرم • شام كاش • تحويل رصيد • بنكي',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                const PaymentChannelsEditorScreen(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _saving ? null : _save,
                          icon: _saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: AppTheme.deepBlack))
                              : const Icon(Icons.save),
                          label: Text(_saving ? 'جارٍ الحفظ...' : 'حفظ التغييرات'),
                          style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14)),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _warning() => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.withOpacity(0.5)),
        ),
        child: const Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orange),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'هذه القيم تؤثّر على كل المستخدمين فوراً. عدّل بحذر.',
                style: TextStyle(color: AppTheme.textWhite, fontSize: 12),
              ),
            ),
          ],
        ),
      );

  Widget _error(String? msg) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: AppTheme.errorRed, size: 48),
              const SizedBox(height: 12),
              Text(msg ?? 'تعذّر تحميل الإعدادات',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.textGrey)),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _load, child: const Text('إعادة المحاولة')),
            ],
          ),
        ),
      );

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(title,
            style: const TextStyle(
                color: AppTheme.primaryGold,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
      );

  Widget _navTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBlack,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.primaryGold.withOpacity(0.3)),
      ),
      child: ListTile(
        leading: Icon(icon, color: AppTheme.primaryGold),
        title: Text(title,
            style: const TextStyle(
                color: AppTheme.textWhite, fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle,
            style: const TextStyle(color: AppTheme.textGrey, fontSize: 12)),
        trailing: const Icon(Icons.arrow_forward_ios,
            color: AppTheme.primaryGold, size: 16),
        onTap: onTap,
      ),
    );
  }

  Widget _numField(String label, TextEditingController ctrl) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ctrl,
        keyboardType: TextInputType.number,
        style: const TextStyle(color: AppTheme.textWhite),
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: AppTheme.surfaceBlack,
        ),
        validator: (v) {
          if (v == null || v.trim().isEmpty) return 'مطلوب';
          if (num.tryParse(v.trim()) == null) return 'رقم غير صالح';
          return null;
        },
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final prov = context.read<ConfigProvider>();
    // ندمج التعديلات فوق نسخة من الـ config الحالي للحفاظ على باقي المفاتيح
    final current = Map<String, dynamic>.from(prov.config?.data ?? {});

    final pts = Map<String, dynamic>.from(current['pts'] ?? {});
    pts['sgn'] = int.tryParse(_signupPts.text.trim()) ?? pts['sgn'];
    pts['wkL'] = int.tryParse(_weeklyPts.text.trim()) ?? pts['wkL'];
    pts['addO'] = int.tryParse(_addOfferPts.text.trim()) ?? pts['addO'];
    pts['dlD'] = int.tryParse(_dealDonePts.text.trim()) ?? pts['dlD'];
    current['pts'] = pts;

    final com = Map<String, dynamic>.from(current['com'] ?? {});
    com['sl'] = num.tryParse(_sellCom.text.trim()) ?? com['sl'];
    current['com'] = com;

    final qta = Map<String, dynamic>.from(current['qta'] ?? {});
    final qtaU = Map<String, dynamic>.from(qta['u'] ?? {});
    qtaU['o'] = int.tryParse(_userOffersQuota.text.trim()) ?? qtaU['o'];
    qta['u'] = qtaU;
    final qtaB = Map<String, dynamic>.from(qta['b'] ?? {});
    qtaB['o'] = int.tryParse(_brokerOffersQuota.text.trim()) ?? qtaB['o'];
    qta['b'] = qtaB;
    current['qta'] = qta;

    // ── حفظ حقول طلبات الفيديو (مدير + نائب) ──
    final txts = Map<String, dynamic>.from(current['txts'] ?? {});
    txts['videoRequestWhatsApp'] = _videoWaNumber.text.trim();
    txts['videoRequestGroupLink'] = _videoGroupLink.text.trim();

    // ── حفظ صفحات التواصل الاجتماعي ──
    txts['facebook'] = _facebookCtrl.text.trim();
    txts['instagram'] = _instagramCtrl.text.trim();
    txts['developerPhone'] = _developerPhoneCtrl.text.trim();

    // صفحات إضافية
    final extraSocial = <String, dynamic>{};
    for (final map in _extraSocialCtrls) {
      final lbl = map['label']!.text.trim();
      final url = map['url']!.text.trim();
      if (lbl.isNotEmpty && url.isNotEmpty) {
        extraSocial[lbl] = url;
      }
    }
    txts['socialPages'] = extraSocial;

    current['txts'] = txts;
    final socialPublishing = Map<String, dynamic>.from(
        current['socialPublishing'] ?? <String, dynamic>{});
    socialPublishing['autoPublish'] = _socialAutoPublish;
    current['socialPublishing'] = socialPublishing;

    final ok = await prov.updateConfig(current);
    if (mounted) {
      setState(() => _saving = false);
      AppTheme.showSnackBar(context,
        SnackBar(content: Text(ok ? 'تم حفظ الإعدادات ✅' : 'فشل الحفظ ❌')),
      );
    }
  }
}
