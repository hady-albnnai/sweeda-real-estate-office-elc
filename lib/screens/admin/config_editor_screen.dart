import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/config_provider.dart';
import '../../core/theme/app_theme.dart';

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
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ConfigProvider>();

    return Scaffold(
      backgroundColor: AppTheme.deepBlack,
      appBar: AppBar(
        title: const Text('إعدادات التطبيق'),
        backgroundColor: AppTheme.deepBlack,
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

    final ok = await prov.updateConfig(current);
    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? 'تم حفظ الإعدادات ✅' : 'فشل الحفظ ❌')),
      );
    }
  }
}
