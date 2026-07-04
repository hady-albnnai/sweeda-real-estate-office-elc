import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/network/supabase_service.dart';
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
  bool _checking = true; // يمنع وميض شاشة الإعداد
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
    await legal.checkLawyerProfile(user.uid);
    if (legal.profileSetupComplete) {
      legal.fetchAvailableExpediters();
      legal.fetchLawyerAppointments();
      legal.fetchLawyerTasks();
    }
    if (mounted) setState(() => _checking = false);
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(m), backgroundColor: bg ?? AppTheme.primaryGold));
  }

  // ──────── حوار الملف الشخصي ────────
  void _showProfileDialog() {
    final user = context.read<AuthProvider>().userModel;
    final oldCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceBlack,
        title: const Row(children: [
          Icon(Icons.person, color: AppTheme.primaryGold, size: 22),
          SizedBox(width: 8),
          Text('الملف الشخصي', style: TextStyle(color: AppTheme.primaryGold, fontSize: 18)),
        ]),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(user?.nm ?? '', style: const TextStyle(color: AppTheme.textWhite, fontWeight: FontWeight.bold, fontSize: 16)),
            Text(user?.ph ?? '', style: const TextStyle(color: AppTheme.textGrey, fontSize: 14)),
            if (user?.usr != null && user!.usr!.isNotEmpty)
              Text('@${user.usr}', style: const TextStyle(color: AppTheme.primaryGold, fontSize: 13)),
            const SizedBox(height: 20), const Divider(color: AppTheme.textGrey),
            const Text('تغيير كلمة المرور', style: TextStyle(color: AppTheme.primaryGold, fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 12),
            TextField(controller: oldCtrl, style: const TextStyle(color: AppTheme.textWhite),
              decoration: const InputDecoration(labelText: 'كلمة المرور الحالية', prefixIcon: Icon(Icons.lock_outline, color: AppTheme.primaryGold)),
              obscureText: true),
            const SizedBox(height: 10),
            TextField(controller: newCtrl, style: const TextStyle(color: AppTheme.textWhite),
              decoration: const InputDecoration(labelText: 'كلمة المرور الجديدة', prefixIcon: Icon(Icons.lock, color: AppTheme.primaryGold)),
              obscureText: true),
            const SizedBox(height: 10),
            TextField(controller: confCtrl, style: const TextStyle(color: AppTheme.textWhite),
              decoration: const InputDecoration(labelText: 'تأكيد كلمة المرور', prefixIcon: Icon(Icons.lock, color: AppTheme.primaryGold)),
              obscureText: true),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء', style: TextStyle(color: AppTheme.textGrey))),
          ElevatedButton(onPressed: () async {
            if (newCtrl.text != confCtrl.text) { _snack('كلمتا المرور غير متطابقتين', bg: AppTheme.errorRed); return; }
            if (newCtrl.text.length < 8) { _snack('كلمة المرور أقل من 8 أحرف', bg: AppTheme.errorRed); return; }
            try {
              final res = await SupabaseService().invokeFunction('user-account', body: {
                'action': 'change_password', 'user_uid': user?.uid ?? '',
                'p_old_password': oldCtrl.text, 'p_new_password': newCtrl.text,
              });
              final d = res.data as Map?;
              if (d?['success'] == true) { Navigator.pop(ctx); _snack('✅ تم تغيير كلمة المرور'); }
              else { _snack(d?['error']?.toString() ?? 'فشل', bg: AppTheme.errorRed); }
            } catch (e) { _snack('خطأ: $e', bg: AppTheme.errorRed); }
          }, child: const Text('حفظ')),
        ],
      ),
    );
  }

  // ──────── حفظ الإعداد الأولي ────────
  Future<void> _saveProfile() async {
    final user = context.read<AuthProvider>().userModel;
    if (user == null) return;
    if (_whatsappCtrl.text.trim().isEmpty) { _snack('يرجى إدخال رقم الواتساب', bg: AppTheme.errorRed); return; }
    setState(() => _savingProfile = true);
    final ok = await context.read<LegalProvider>().upsertLawyerProfile(
      targetUid: user.uid, whatsappPhone: _whatsappCtrl.text.trim(), officeAddress: _addressCtrl.text.trim());
    if (!mounted) return; setState(() => _savingProfile = false);
    if (ok) {
      _snack('✅ تم حفظ البيانات');
      context.read<LegalProvider>().fetchAvailableExpediters();
      context.read<LegalProvider>().fetchLawyerAppointments();
      context.read<LegalProvider>().fetchLawyerTasks();
    } else { _snack('فشل الحفظ', bg: AppTheme.errorRed); }
  }

  // ──────── إنشاء مهمة ────────
  Future<void> _createTask() async {
    if (_selectedExpediterUid == null) { _snack('يرجى اختيار معقب', bg: AppTheme.errorRed); return; }
    setState(() => _creatingTask = true);
    final ok = await context.read<LegalProvider>().createExpeditingTask(
      expediterUid: _selectedExpediterUid!, itemType: _selectedItemType,
      targetPropertyNum: _taskPropertyCtrl.text.trim(), targetZone: _taskZoneCtrl.text.trim(),
      notes: _taskNotesCtrl.text.trim());
    if (!mounted) return; setState(() => _creatingTask = false);
    if (ok) {
      _snack('✅ تم إرسال المهمة');
      _taskPropertyCtrl.clear(); _taskZoneCtrl.clear(); _taskNotesCtrl.clear();
      setState(() => _selectedExpediterUid = null);
    } else { _snack('فشل إنشاء المهمة', bg: AppTheme.errorRed); }
  }

  @override
  Widget build(BuildContext context) {
    final legal = context.watch<LegalProvider>();
    if (_checking) return const Scaffold(
      backgroundColor: AppTheme.deepBlack,
      body: Center(child: CircularProgressIndicator(color: AppTheme.primaryGold)),
    );
    if (!legal.profileSetupComplete) return _buildSetupScreen();

    return Scaffold(
      backgroundColor: AppTheme.deepBlack,
      appBar: AppBar(
        title: const Text('⚖️ لوحة المحامي'), backgroundColor: AppTheme.deepBlack,
        actions: [
          IconButton(icon: const Icon(Icons.person_outline, color: AppTheme.primaryGold),
            tooltip: 'الملف الشخصي', onPressed: _showProfileDialog),
        ],
        bottom: TabBar(controller: _tabCtrl, indicatorColor: AppTheme.primaryGold,
          labelColor: AppTheme.primaryGold, unselectedLabelColor: AppTheme.textGrey,
          tabs: const [
            Tab(icon: Icon(Icons.calendar_month), text: 'مواعيدي'),
            Tab(icon: Icon(Icons.add_task), text: 'إضافة مهمة'),
            Tab(icon: Icon(Icons.assignment), text: 'المهام المرسلة'),
          ]),
      ),
      body: TabBarView(controller: _tabCtrl, children: [
        _buildAppointmentsTab(legal),
        _buildCreateTaskTab(legal),
        _buildSentTasksTab(legal),
      ]),
    );
  }

  // ──────── شاشة الإعداد الأولي ────────
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
            const Text('أهلاً بك', style: TextStyle(color: AppTheme.primaryGold, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('يرجى إعداد رقم الواتساب المعتمد', style: TextStyle(color: AppTheme.textGrey, fontSize: 14)),
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
              label: Text(_savingProfile ? 'جاري...' : 'حفظ ومتابعة', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGold,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))),
          ])),
      ])),
    );
  }

  // ──────── تبويب المواعيد ────────
  Widget _buildAppointmentsTab(LegalProvider legal) {
    final apps = legal.lawyerAppointments;
    if (apps.isEmpty) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.event_busy, size: 60, color: AppTheme.textGrey.withOpacity(0.4)),
      const SizedBox(height: 12), const Text('لا توجد مواعيد حالياً', style: TextStyle(color: AppTheme.textGrey, fontSize: 16)),
    ]));
    return RefreshIndicator(onRefresh: () => legal.fetchLawyerAppointments(),
      child: ListView.builder(padding: const EdgeInsets.all(16), itemCount: apps.length,
        itemBuilder: (_, i) => _apptCard(apps[i])));
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
          Text(a['client_phone']?.toString() ?? '', style: const TextStyle(color: AppTheme.textGrey, fontSize: 13)),
          Text(a['dt']?.toString().substring(0, 16) ?? '', style: const TextStyle(color: AppTheme.primaryGold, fontSize: 12)),
        ])),
        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(color: c.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
          child: Text(sts == '0' ? 'انتظار' : sts == '1' ? 'مؤكد' : sts == '2' ? 'مكتمل' : 'ملغي',
            style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.bold))),
      ]));
  }

  // ──────── تبويب إضافة مهمة ────────
  Widget _buildCreateTaskTab(LegalProvider legal) {
    final expediters = legal.availableExpediters;
    return SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('📋 تكليف معقب', style: TextStyle(color: AppTheme.primaryGold, fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 16), const Text('نوع المعاملة:', style: TextStyle(color: AppTheme.textGrey, fontSize: 14)),
      Row(children: [
        Expanded(child: _Chip(label: '🏠 عقار', selected: _selectedItemType == 0, onTap: () => setState(() => _selectedItemType = 0))),
        const SizedBox(width: 12),
        Expanded(child: _Chip(label: '🚗 سيارة', selected: _selectedItemType == 1, onTap: () => setState(() => _selectedItemType = 1))),
      ]), const SizedBox(height: 16), const Text('المعقب:', style: TextStyle(color: AppTheme.textGrey, fontSize: 14)),
      expediters.isEmpty
          ? Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppTheme.surfaceBlack, borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withOpacity(0.3))),
              child: const Row(children: [Icon(Icons.info_outline, color: Colors.orange, size: 18), SizedBox(width: 10),
                Expanded(child: Text('لا يوجد معقبين. أضف معقباً من إدارة الموظفين.', style: TextStyle(color: AppTheme.textGrey, fontSize: 13)))]))
          : DropdownButtonFormField<String>(value: _selectedExpediterUid, dropdownColor: AppTheme.surfaceBlack,
              style: const TextStyle(color: AppTheme.textWhite),
              decoration: const InputDecoration(labelText: 'اختر المعقب', prefixIcon: Icon(Icons.person_search, color: AppTheme.primaryGold)),
              items: expediters.map((e) => DropdownMenuItem(value: e['id']?.toString(), child: Text('${e['nm']} (${e['ph']})'))).toList(),
              onChanged: (v) => setState(() => _selectedExpediterUid = v)),
      const SizedBox(height: 16),
      if (_selectedItemType == 0) ...[
        TextField(controller: _taskPropertyCtrl, style: const TextStyle(color: AppTheme.textWhite),
          decoration: const InputDecoration(labelText: 'رقم العقار', hintText: '12345')),
        const SizedBox(height: 12),
        TextField(controller: _taskZoneCtrl, style: const TextStyle(color: AppTheme.textWhite),
          decoration: const InputDecoration(labelText: 'المنطقة العقارية', hintText: 'السويداء')),
      ],
      if (_selectedItemType == 1)
        TextField(controller: _taskPropertyCtrl, style: const TextStyle(color: AppTheme.textWhite),
          decoration: const InputDecoration(labelText: 'رقم المركبة', hintText: '123456')),
      const SizedBox(height: 12),
      TextField(controller: _taskNotesCtrl, style: const TextStyle(color: AppTheme.textWhite), maxLines: 3,
        decoration: const InputDecoration(labelText: 'تعليمات', hintText: 'ملاحظات للمعقب...')),
      const SizedBox(height: 24),
      SizedBox(width: double.infinity, height: 50, child: ElevatedButton.icon(
        onPressed: _creatingTask ? null : _createTask,
        icon: _creatingTask ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send),
        label: Text(_creatingTask ? 'جاري...' : 'إرسال للمعقب', style: const TextStyle(fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGold, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))),
    ]));
  }

  // ──────── تبويب المهام المرسلة ────────
  Widget _buildSentTasksTab(LegalProvider legal) {
    final tasks = legal.lawyerTasks;
    if (tasks.isEmpty) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.assignment_late, size: 60, color: AppTheme.textGrey.withOpacity(0.4)),
      const SizedBox(height: 12), const Text('لا توجد مهام', style: TextStyle(color: AppTheme.textGrey, fontSize: 16)),
    ]));
    return RefreshIndicator(onRefresh: () => legal.fetchLawyerTasks(),
      child: ListView.builder(padding: const EdgeInsets.all(16), itemCount: tasks.length, itemBuilder: (_, i) {
        final t = tasks[i]; final done = t.checklist.where((c) => c.status >= 2).length;
        final total = t.checklist.length; final c = t.status == 0 ? Colors.orange : t.status == 1 ? Colors.blue : Colors.green;
        return Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppTheme.surfaceBlack, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.withOpacity(0.3))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Icon(Icons.assignment, color: c, size: 20), const SizedBox(width: 8),
              Expanded(child: Text(
                t.status == 0 ? 'انتظار' : t.status == 1 ? 'قيد الاستخراج' : t.status == 2 ? 'مكتملة' : 'معتمدة 🎉',
                style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: 14))),
              Text(t.itemType == 0 ? '🏠 عقار' : '🚗 سيارة', style: const TextStyle(color: AppTheme.primaryGold, fontSize: 12))]),
            if (t.targetPropertyNum.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('رقم: ${t.targetPropertyNum} | ${t.targetZone}', style: const TextStyle(color: AppTheme.textGrey, fontSize: 13))],
            Row(children: [Icon(Icons.checklist, size: 16, color: AppTheme.primaryGold), const SizedBox(width: 6),
              Text('$done / $total وثائق', style: const TextStyle(color: AppTheme.textGrey, fontSize: 13)),
              if (t.status == 3) ...[
                const SizedBox(width: 8),
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
