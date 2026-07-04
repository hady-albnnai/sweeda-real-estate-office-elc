import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/legal_provider.dart';
import '../../models/expediting_task_model.dart';

class LawyerDashboardScreen extends StatefulWidget {
  const LawyerDashboardScreen({super.key});

  @override
  State<LawyerDashboardScreen> createState() => _LawyerDashboardScreenState();
}

class _LawyerDashboardScreenState extends State<LawyerDashboardScreen> {
  final _whatsappCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _specCtrl = TextEditingController(text: 'عقارات وسيارات');
  final Map<String, List<String>> _avl = {'mon': ['10:00-14:00'], 'wed': ['16:00-19:00']};
  bool _savingProfile = false;

  @override
  void dispose() {
    _whatsappCtrl.dispose();
    _addressCtrl.dispose();
    _specCtrl.dispose();
    super.dispose();
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _saveProfile() async {
    final user = context.read<AuthProvider>().userModel;
    if (user == null) return;
    if (_whatsappCtrl.text.trim().isEmpty) {
      _snack('يرجى إدخال رقم الواتساب المعتمد للاستشارات');
      return;
    }
    setState(() => _savingProfile = true);
    final ok = await context.read<LegalProvider>().upsertLawyerProfile(
      targetUid: user.uid,
      whatsappPhone: _whatsappCtrl.text.trim(),
      officeAddress: _addressCtrl.text.trim(),
      specialization: _specCtrl.text.trim(),
      avl: _avl,
    );
    if (!mounted) return;
    setState(() => _savingProfile = false);
    _snack(ok ? '✅ تم تحديث ملف المحامي وجدول المواعيد بنجاح' : 'فشل التحديث');
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().userModel;

    return Scaffold(
      backgroundColor: AppTheme.deepBlack,
      appBar: AppBar(
        title: const Text('لوحة تحكم المحامي المختص ⚖️'),
        backgroundColor: AppTheme.deepBlack,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppTheme.surfaceBlack, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.primaryGold.withOpacity(0.4))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('مرحباً أستاذ، إدارة أوقات الدوام وبيانات الاتصال:', style: TextStyle(color: AppTheme.primaryGold, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _whatsappCtrl,
                    style: const TextStyle(color: AppTheme.textWhite),
                    decoration: const InputDecoration(labelText: 'رقم الواتساب المعتمد للاستشارات الصوتية', hintText: '+9639xxxxxxxx'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _addressCtrl,
                    style: const TextStyle(color: AppTheme.textWhite),
                    decoration: const InputDecoration(labelText: 'عنوان المكتب الحضوري', hintText: 'السويداء - الشارع المحوري...'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _specCtrl,
                    style: const TextStyle(color: AppTheme.textWhite),
                    decoration: const InputDecoration(labelText: 'التخصص الدقيق'),
                  ),
                  const SizedBox(height: 16),
                  const Text('جدول الأوقات المتاحة للمواعيد المكتبية (avl):', style: TextStyle(color: AppTheme.primaryGold, fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 8),
                  Text('الاثنين: 10:00-14:00 | الأربعاء: 16:00-19:00', style: const TextStyle(color: AppTheme.textGrey, fontSize: 13)),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _savingProfile ? null : _saveProfile,
                      icon: const Icon(Icons.save),
                      label: _savingProfile ? const CircularProgressIndicator(color: AppTheme.deepBlack) : const Text('حفظ تحديثات الملف والجدول', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text('📋 المهام المحالة لمعقبي المعاملات الميدانيين:', style: TextStyle(color: AppTheme.primaryGold, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: AppTheme.surfaceBlack, borderRadius: BorderRadius.circular(14)),
              child: const Center(
                child: Text('لا توجد مهام معقبين نشطة حالياً. عند طلب باقة التوثيق الشامل، سيتم إنشاء مهمة استخراج وإحالتها للمعقب الميداني.', style: TextStyle(color: AppTheme.textGrey, height: 1.5), textAlign: TextAlign.center),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
