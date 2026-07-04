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

class _LawyerDashboardScreenState extends State<LawyerDashboardScreen>
    with SingleTickerProviderStateMixin {
  final _whatsappCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _taskPropertyCtrl = TextEditingController();
  final _taskZoneCtrl = TextEditingController();
  final _taskNotesCtrl = TextEditingController();
  bool _savingProfile = false;
  bool _creatingTask = false;
  String? _selectedExpediterUid;
  int _selectedItemType = 0;
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    final user = context.read<AuthProvider>().userModel;
    if (user == null) return;
    final legal = context.read<LegalProvider>();
    final hasProfile = await legal.checkLawyerProfile(user.uid);
    if (hasProfile) {
      legal.fetchAvailableExpediters();
      legal.fetchLawyerAppointments();
      legal.fetchLawyerTasks();
    }
  }

  @override
  void dispose() {
    _whatsappCtrl.dispose(); _addressCtrl.dispose();
    _taskPropertyCtrl.dispose(); _taskZoneCtrl.dispose(); _taskNotesCtrl.dispose();
    _tabCtrl.dispose();
    super.dispose();
  }

  void _snack(String m, {Color? bg}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: bg ?? AppTheme.primaryGold));
  }

  Future<void> _saveProfile() async {
    final user = context.read<AuthProvider>().userModel;
    if (user == null) return;
    if (_whatsappCtrl.text.trim().isEmpty) { _snack('يرجى إدخال رقم الواتساب', bg: AppTheme.errorRed); return; }
    setState(() => _savingProfile = true);
    final ok = await context.read<LegalProvider>().upsertLawyerProfile(
      targetUid: user.uid, whatsappPhone: _whatsappCtrl.text.trim(), officeAddress: _addressCtrl.text.trim());
    if (!mounted) return; setState(() => _savingProfile = false);
    if (ok) { _snack('✅ تم حفظ البيانات');
      context.read<LegalProvider>().fetchAvailableExpediters();
      context.read<LegalProvider>().fetchLawyerAppointments();
      context.read<LegalProvider>().fetchLawyerTasks();
    } else { _snack('فشل الحفظ', bg: AppTheme.errorRed); }
  }

  Future<void> _createTask() async {
    if (_selectedExpediterUid == null) { _snack('يرجى اختيار معقب', bg: AppTheme.errorRed); return; }
    setState(() => _creatingTask = true);
    final ok = await context.read<LegalProvider>().createExpeditingTask(
      expediterUid: _selectedExpediterUid!, itemType: _selectedItemType,
      targetPropertyNum: _taskPropertyCtrl.text.trim(), targetZone: _taskZoneCtrl.text.trim(),
      notes: _taskNotesCtrl.text.trim());
    if (!mounted) return; setState(() => _creatingTask = false);
    if (ok) { _snack('✅ تم إرسال المهمة');
      _taskPropertyCtrl.clear(); _taskZoneCtrl.clear(); _taskNotesCtrl.clear();
      setState(() => _selectedExpediterUid = null);
    } else { _snack('فشل إنشاء المهمة', bg: AppTheme.errorRed); }
  }

  @override
  Widget build(BuildContext context) {
    final legal = context.watch<LegalProvider>();
    if (!legal.profileSetupComplete) return _buildSetupScreen();
    return Scaffold(
      backgroundColor: AppTheme.deepBlack,
      appBar: AppBar(title: const Text('⚖️ لوحة المحامي'), backgroundColor: AppTheme.deepBlack,
        bottom: TabBar(controller: _tabCtrl, indicatorColor: AppTheme.primaryGold,
          labelColor: AppTheme.primaryGold, unselectedLabelColor: AppTheme.textGrey,
          tabs: const [
            Tab(icon: Icon(Icons.calendar_month), text: 'مواعيدي'),
            Tab(icon: Icon(Icons.add_task), text: 'إضافة مهمة'),
            Tab(icon: Icon(Icons.assignment), text: 'المهام المرسلة'),
          ])),
      body: TabBarView(controller: _tabCtrl, children: [
        _buildAppointmentsTab(legal), _buildCreateTaskTab(legal), _buildSentTasksTab(legal),
      ]),
    );
  }

  Widget _buildSetupScreen() {
    return Scaffold(
      backgroundColor: AppTheme.deepBlack,
      appBar: AppBar(title: const Text('⚖️ مرحباً أستاذ'), backgroundColor: AppTheme.deepBlack),
      body: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(children: [
        const SizedBox(height: 20),
        Container(padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: AppTheme.surfaceBlack, borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.primaryGold.withOpacity(0.3))),
          child: Column(children: [
            const Icon(Icons.gavel, size: 50, color: AppTheme.primaryGold), const SizedBox(height: 12),
            const Text('أهلاً بك في نظام المحامي المختص', style: TextStyle(color: AppTheme.primaryGold, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8), const Text('يرجى إعداد رقم الواتساب المعتمد للاستشارات الصوتية', style: TextStyle(color: AppTheme.textGrey, fontSize: 14), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            TextField(controller: _whatsappCtrl, style: const TextStyle(color: AppTheme.textWhite),
              decoration: const InputDecoration(labelText: 'رقم الواتساب المعتمد *', hintText: '+9639xxxxxxxx',
                prefixIcon: Icon(Icons.phone_android, color: AppTheme.primaryGold)),
              keyboardType: TextInputType.phone),
            const SizedBox(height: 16),
            TextField(controller: _addressCtrl, style: const TextStyle(color: AppTheme.textWhite),
              decoration: const InputDecoration(labelText: 'عنوان المكتب (اختياري)', hintText: 'مقر الشركة',
                prefixIcon: Icon(Icons.location_on, color: AppTheme.primaryGold))),
            const SizedBox(height: 24),
            SizedBox(width: double.infinity, height: 50, child: ElevatedButton.icon(
              onPressed: _savingProfile ? null : _saveProfile,
              icon: _savingProfile ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save),
              label: Text(_savingProfile ? 'جاري الحفظ...' : 'حفظ ومتابعة', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGold, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))),
          ])),
      ])),
    );
  }

  Widget _buildAppointmentsTab(LegalProvider legal) {
    final apps = legal.lawyerAppointments;
    if (apps.isEmpty) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.event_busy, size: 60, color: AppTheme.textGrey.withOpacity(0.4)),
      const SizedBox(height: 12), const Text('لا توجد مواعيد حالياً', style: TextStyle(color: AppTheme.textGrey, fontSize: 16)),
    ]));
    return RefreshIndicator(onRefresh: () => legal.fetchLawyerAppointments(),
      child: ListView.builder(padding: const EdgeInsets.all(16), itemCount: apps.length,
        itemBuilder: (_, i) { final a = apps[i]; return _apptCard(a); }));
  }

  Widget _apptCard(Map<String, dynamic> a) {
    final sts = a['sts']?.toString() ?? '0';
    final c = sts == '0' ? Colors.orange : sts == '1' ? Colors.green : sts == '2' ? Colors.blue : Colors.red;
    return Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppTheme.surfaceBlack, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.withOpacity(0.3))),
      child: Row(children: [
        Container(width: 4, height: 60, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(4))),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(a['client_name']?.toString() ?? '', style: const TextStyle(color: AppTheme.textWhite, fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 4), Text(a['client_phone']?.toString() ?? '', style: const TextStyle(color: AppTheme.textGrey, fontSize: 13)),
          const SizedBox(height: 4), Text(a['dt']?.toString().substring(0, 16) ?? '', style: const TextStyle(color: AppTheme.primaryGold, fontSize: 12)),
        ])),
        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(color: c.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
          child: Text(sts == '0' ? 'انتظار' : sts == '1' ? 'مؤكد' : sts == '2' ? 'مكتمل' : 'ملغي', style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.bold))),
      ]));
  }

  Widget _buildCreateTaskTab(LegalProvider legal) {
    final expediters = legal.availableExpediters;
    return SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('📋 تكليف معقب معاملات', style: TextStyle(color: AppTheme.primaryGold, fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 16), const Text('نوع المعاملة:', style: TextStyle(color: AppTheme.textGrey, fontSize: 14)), const SizedBox(height: 8),
      Row(children: [
        Expanded(child: _Chip(label: '🏠 عقار', selected: _selectedItemType == 0, onTap: () => setState(() => _selectedItemType = 0))),
        const SizedBox(width: 12),
        Expanded(child: _Chip(label: '🚗 سيارة', selected: _selectedItemType == 1, onTap: () => setState(() => _selectedItemType = 1))),
      ]), const SizedBox(height: 16), const Text('المعقب المكلف:', style: TextStyle(color: AppTheme.textGrey, fontSize: 14)), const SizedBox(height: 8),
      expediters.isEmpty
          ? Container(padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppTheme.surfaceBlack, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orange.withOpacity(0.3))),
              child: const Row(children: [Icon(Icons.info_outline, color: Colors.orange, size: 18), SizedBox(width: 10),
                Expanded(child: Text('لا يوجد معقبين متاحين. أضف معقباً من إدارة الموظفين أولاً.', style: TextStyle(color: AppTheme.textGrey, fontSize: 13)))]))
          : DropdownButtonFormField<String>(value: _selectedExpediterUid, dropdownColor: AppTheme.surfaceBlack,
              style: const TextStyle(color: AppTheme.textWhite),
              decoration: const InputDecoration(labelText: 'اختر المعقب', prefixIcon: Icon(Icons.person_search, color: AppTheme.primaryGold)),
              items: expediters.map((e) => DropdownMenuItem(value: e['id']?.toString(), child: Text('${e['nm']} (${e['ph']})'))).toList(),
              onChanged: (v) => setState(() => _selectedExpediterUid = v)),
      const SizedBox(height: 16),
      if (_selectedItemType == 0) ...[
        TextField(controller: _taskPropertyCtrl, style: const TextStyle(color: AppTheme.textWhite),
          decoration: const InputDecoration(labelText: 'رقم العقار', hintText: 'مثال: 12345')),
        const SizedBox(height: 12),
        TextField(controller: _taskZoneCtrl, style: const TextStyle(color: AppTheme.textWhite),
          decoration: const InputDecoration(labelText: 'المنطقة العقارية', hintText: 'مثال: السويداء')),
      ],
      if (_selectedItemType == 1)
        TextField(controller: _taskPropertyCtrl, style: const TextStyle(color: AppTheme.textWhite),
          decoration: const InputDecoration(labelText: 'رقم المركبة/اللوحة', hintText: 'مثال: 123456')),
      const SizedBox(height: 12),
      TextField(controller: _taskNotesCtrl, style: const TextStyle(color: AppTheme.textWhite), maxLines: 3,
        decoration: const InputDecoration(labelText: 'تعليمات إضافية', hintText: 'ملاحظات للمعقب...')),
      const SizedBox(height: 24),
      SizedBox(width: double.infinity, height: 50, child: ElevatedButton.icon(
        onPressed: _creatingTask ? null : _createTask,
        icon: _creatingTask ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send),
        label: Text(_creatingTask ? 'جاري الإرسال...' : 'إرسال المهمة للمعقب', style: const TextStyle(fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGold, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))),
    ]));
  }

  Widget _buildSentTasksTab(LegalProvider legal) {
    final tasks = legal.lawyerTasks;
    if (tasks.isEmpty) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.assignment_late, size: 60, color: AppTheme.textGrey.withOpacity(0.4)),
      const SizedBox(height: 12), const Text('لا توجد مهام مرسلة', style: TextStyle(color: AppTheme.textGrey, fontSize: 16)),
      const SizedBox(height: 6), const Text('المهام المرسلة للمعقبين ستظهر هنا', style: TextStyle(color: AppTheme.textGrey, fontSize: 13)),
    ]));
    return RefreshIndicator(onRefresh: () => legal.fetchLawyerTasks(),
      child: ListView.builder(padding: const EdgeInsets.all(16), itemCount: tasks.length, itemBuilder: (_, i) {
        final t = tasks[i]; final done = t.checklist.where((c) => c.status == 2).length;
        final total = t.checklist.length; final c = t.status == 0 ? Colors.orange : t.status == 1 ? Colors.blue : Colors.green;
        return Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppTheme.surfaceBlack, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.withOpacity(0.3))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Icon(Icons.assignment, color: c, size: 20), const SizedBox(width: 8),
              Expanded(child: Text(
                t.status == 0 ? 'قيد الانتظار' : t.status == 1 ? 'قيد الاستخراج' : t.status == 2 ? 'مكتملة' : 'معتمدة 🎉',
                style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: 14))),
              Text(t.itemType == 0 ? '🏠 عقار' : '🚗 سيارة', style: const TextStyle(color: AppTheme.primaryGold, fontSize: 12))]),
            if (t.targetPropertyNum.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('رقم: ${t.targetPropertyNum} | ${t.targetZone}', style: const TextStyle(color: AppTheme.textGrey, fontSize: 13))],
            const SizedBox(height: 6),
            Row(children: [Icon(Icons.checklist, size: 16, color: AppTheme.primaryGold), const SizedBox(width: 6),
              Text('$done / $total وثائق', style: const TextStyle(color: AppTheme.textGrey, fontSize: 13)),
              if (t.status == 3) ...[const SizedBox(width: 8),
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: Colors.green.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                  child: const Text('معتمد', style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold)))],
            ]),
          ]));
      }));
  }
}

class _Chip extends StatelessWidget {
  final String label; final bool selected; final VoidCallback onTap;
  const _Chip({required this.label, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: onTap, child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: selected ? AppTheme.primaryGold.withOpacity(0.2) : AppTheme.surfaceBlack,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: selected ? AppTheme.primaryGold : AppTheme.textGrey.withOpacity(0.3), width: selected ? 2 : 1)),
      child: Center(child: Text(label, style: TextStyle(color: selected ? AppTheme.primaryGold : AppTheme.textGrey,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal, fontSize: 15)))));
  }
}
