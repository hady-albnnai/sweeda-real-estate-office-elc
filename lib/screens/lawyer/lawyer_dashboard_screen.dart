import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_theme.dart';
import '../../core/network/supabase_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/legal_provider.dart';
import '../../models/expediting_task_model.dart';
import '../../widgets/e2e.dart';

class LawyerDashboardScreen extends StatefulWidget {
  const LawyerDashboardScreen({super.key});

  @override
  State<LawyerDashboardScreen> createState() => _LawyerDashboardScreenState();
}

class _LawyerDashboardScreenState extends State<LawyerDashboardScreen>
    with SingleTickerProviderStateMixin {
  final _whatsappCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  static const String _customDocsStorageKey = 'lawyer_expediting_custom_docs_v1';

  final _taskPropertyCtrl = TextEditingController();
  final _taskZoneCtrl = TextEditingController();
  final _taskNotesCtrl = TextEditingController();
  final _permanentDocTitleCtrl = TextEditingController();
  final _oneTimeDocTitleCtrl = TextEditingController();
  final List<Map<String, dynamic>> _selectedChecklist = [];
  final Map<int, List<Map<String, String>>> _customDocTemplates = {0: [], 1: []};

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
    _loadCustomDocumentTemplates();
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
    _permanentDocTitleCtrl.dispose();
    _oneTimeDocTitleCtrl.dispose();
    _tabCtrl.dispose();
    super.dispose();
  }

  void _snack(String m, {Color? bg}) {
    if (!mounted) return;
    AppTheme.showSnackBar(context,
      SnackBar(content: Text(m), backgroundColor: bg ?? AppTheme.primaryGold));
  }

  Future<void> _openAccountDetails() async {
    if (!mounted) return;
    context.push('/user/account-info');
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceBlack,
        title: const Text('تسجيل الخروج', style: TextStyle(color: AppTheme.textWhite)),
        content: const Text('هل تريد تسجيل الخروج من حساب المحامي؟', style: TextStyle(color: AppTheme.textGrey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء', style: TextStyle(color: AppTheme.textGrey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تسجيل خروج', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    await context.read<AuthProvider>().logout();
    if (!mounted) return;
    context.go('/user/profile');
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
                'action': 'change_password',
                'user_uid': user?.uid ?? '',
                'old_password': oldCtrl.text,
                'new_password': newCtrl.text,
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

  List<Map<String, String>> _baseDocumentTemplatesFor(int itemType) {
    if (itemType == 0) {
      return const [
        {'key': 'extract', 'title': 'إخراج قيد عقاري حديث'},
        {'key': 'area_stmt', 'title': 'بيان مساحة عقاري'},
        {'key': 'fin_clearance', 'title': 'براءة ذمة مالية وبلدية'},
        {'key': 'fin_record', 'title': 'قيد مالي للعقار'},
        {'key': 'sales_tax', 'title': 'ضريبة البيوع العقارية'},
        {'key': 'poa_chain', 'title': 'تسلسل وكالات كاتب بالعدل'},
      ];
    }
    return const [
      {'key': 'traffic_info', 'title': 'كشف اطلاع مروري'},
      {'key': 'traffic_clearance', 'title': 'براءة ذمة مرورية ومخالفات'},
      {'key': 'tech_inspect', 'title': 'كشف فني ومطابقة الأرقام'},
      {'key': 'title_deed', 'title': 'سند الملكية / ميكانيك المركبة'},
    ];
  }

  List<Map<String, String>> _documentTemplatesFor(int itemType) {
    return [
      ..._baseDocumentTemplatesFor(itemType),
      ...(_customDocTemplates[itemType] ?? const <Map<String, String>>[]),
    ];
  }

  bool _isBaseDocument(String key) {
    return _baseDocumentTemplatesFor(_selectedItemType).any((doc) => doc['key'] == key);
  }

  Future<void> _loadCustomDocumentTemplates() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_customDocsStorageKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final parsed = jsonDecode(raw);
      if (parsed is Map) {
        final loaded = <int, List<Map<String, String>>>{0: [], 1: []};
        for (final type in [0, 1]) {
          final list = parsed[type.toString()];
          if (list is List) {
            loaded[type] = list
                .whereType<Map>()
                .map((item) => {
                      'key': item['key']?.toString() ?? '',
                      'title': item['title']?.toString() ?? '',
                    })
                .where((item) => item['key']!.isNotEmpty && item['title']!.isNotEmpty)
                .toList();
          }
        }
        if (mounted) {
          setState(() {
            _customDocTemplates
              ..clear()
              ..addAll(loaded);
          });
        }
      }
    } catch (_) {
      // تجاهل كاش تالف.
    }
  }

  Future<void> _saveCustomDocumentTemplates() async {
    final prefs = await SharedPreferences.getInstance();
    final serializable = {
      '0': _customDocTemplates[0] ?? [],
      '1': _customDocTemplates[1] ?? [],
    };
    await prefs.setString(_customDocsStorageKey, jsonEncode(serializable));
  }

  Map<String, dynamic> _newChecklistItem(String key, String title) {
    return {
      'key': key,
      'title': title,
      'status': 0,
      'required_copies': 1,
      'lawyer_instructions': '',
    };
  }

  void _toggleDocumentForTask(Map<String, String> doc, bool selected) {
    final key = doc['key']!;
    final title = doc['title']!;
    setState(() {
      if (selected) {
        if (!_selectedChecklist.any((item) => item['key'] == key)) {
          _selectedChecklist.add(_newChecklistItem(key, title));
        }
      } else {
        _selectedChecklist.removeWhere((item) => item['key'] == key);
      }
    });
  }

  void _changeItemType(int type) {
    if (_selectedItemType == type) return;
    setState(() {
      _selectedItemType = type;
      _selectedChecklist.clear();
      _permanentDocTitleCtrl.clear();
      _oneTimeDocTitleCtrl.clear();
      _taskPropertyCtrl.clear();
      _taskZoneCtrl.clear();
    });
  }

  Future<void> _addPermanentDocumentTemplate() async {
    final title = _permanentDocTitleCtrl.text.trim();
    if (title.length < 2) {
      _snack('اكتب اسم الوثيقة التي تريد إضافتها للقائمة', bg: AppTheme.errorRed);
      return;
    }
    final exists = _documentTemplatesFor(_selectedItemType)
        .any((doc) => doc['title']?.trim() == title);
    if (exists) {
      _snack('هذه الوثيقة موجودة مسبقاً في القائمة', bg: AppTheme.errorRed);
      return;
    }
    final key = 'saved_${_selectedItemType}_${DateTime.now().microsecondsSinceEpoch}';
    setState(() {
      _customDocTemplates.putIfAbsent(_selectedItemType, () => []).add({'key': key, 'title': title});
      _permanentDocTitleCtrl.clear();
    });
    await _saveCustomDocumentTemplates();
    _snack('تمت إضافة الوثيقة للقائمة الدائمة');
  }

  Future<void> _deletePermanentDocumentTemplate(Map<String, String> doc) async {
    final key = doc['key'] ?? '';
    if (_isBaseDocument(key)) {
      _snack('لا يمكن حذف الوثائق الأساسية، يمكن حذف الوثائق المضافة فقط', bg: AppTheme.errorRed);
      return;
    }
    setState(() {
      _customDocTemplates[_selectedItemType]?.removeWhere((item) => item['key'] == key);
      _selectedChecklist.removeWhere((item) => item['key'] == key);
    });
    await _saveCustomDocumentTemplates();
    _snack('تم حذف الوثيقة من القائمة الدائمة');
  }

  void _addOneTimeDocument() {
    final title = _oneTimeDocTitleCtrl.text.trim();
    if (title.length < 2) {
      _snack('اكتب اسم الوثيقة الحرة المطلوبة لهذه المهمة', bg: AppTheme.errorRed);
      return;
    }
    final key = 'one_time_${DateTime.now().microsecondsSinceEpoch}';
    setState(() {
      _selectedChecklist.add(_newChecklistItem(key, title));
      _oneTimeDocTitleCtrl.clear();
    });
  }

  void _addAllDefaultDocuments() {
    setState(() {
      for (final doc in _documentTemplatesFor(_selectedItemType)) {
        if (!_selectedChecklist.any((item) => item['key'] == doc['key'])) {
          _selectedChecklist.add(_newChecklistItem(doc['key']!, doc['title']!));
        }
      }
    });
  }

  // ──────── إنشاء مهمة ────────
  Future<void> _createTask() async {
    if (_selectedExpediterUid == null) { _snack('يرجى اختيار معقب', bg: AppTheme.errorRed); return; }
    if (_selectedChecklist.isEmpty) { _snack('يرجى إضافة وثيقة واحدة على الأقل للمعقب', bg: AppTheme.errorRed); return; }
    setState(() => _creatingTask = true);
    final ok = await context.read<LegalProvider>().createExpeditingTask(
      expediterUid: _selectedExpediterUid!, itemType: _selectedItemType,
      targetPropertyNum: _taskPropertyCtrl.text.trim(), targetZone: _taskZoneCtrl.text.trim(),
      notes: _taskNotesCtrl.text.trim(),
      checklist: _selectedChecklist.map((item) => Map<String, dynamic>.from(item)).toList());
    if (!mounted) return; setState(() => _creatingTask = false);
    if (ok) {
      _snack('✅ تم إرسال المهمة');
      _taskPropertyCtrl.clear(); _taskZoneCtrl.clear(); _taskNotesCtrl.clear();
      setState(() {
        _selectedExpediterUid = null;
        _selectedChecklist.clear();
      });
    } else { _snack('فشل إنشاء المهمة', bg: AppTheme.errorRed); }
  }

  @override
  Widget build(BuildContext context) {
    final legal = context.watch<LegalProvider>();
    if (_checking) return const Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      body: Center(child: CircularProgressIndicator(color: AppTheme.primaryGold)),
    );
    if (!legal.profileSetupComplete) return _buildSetupScreen();

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      appBar: AppBar(
        title: const E2E(id: 'e2e_screen_lawyer_dashboard', child: Text('⚖️ لوحة المحامي')), backgroundColor: AppTheme.scaffoldBackground,
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle_outlined, color: AppTheme.primaryGold),
            tooltip: 'تفاصيل حسابي',
            onPressed: _openAccountDetails,
          ),
          IconButton(
            icon: const Icon(Icons.lock_outline, color: AppTheme.primaryGold),
            tooltip: 'تغيير كلمة المرور',
            onPressed: _showProfileDialog,
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            tooltip: 'تسجيل خروج',
            onPressed: _logout,
          ),
        ],
        bottom: TabBar(controller: _tabCtrl, indicatorColor: AppTheme.primaryGold,
          labelColor: AppTheme.primaryGold, unselectedLabelColor: AppTheme.textGrey,
          tabs: const [
            Tab(icon: E2E(id: 'e2e_lawyer_tab_appointments', button: true, child: Icon(Icons.calendar_month)), text: 'مواعيدي'),
            Tab(icon: E2E(id: 'e2e_lawyer_tab_create_task', button: true, child: Icon(Icons.add_task)), text: 'إضافة مهمة'),
            Tab(icon: E2E(id: 'e2e_lawyer_tab_sent_tasks', button: true, child: Icon(Icons.assignment)), text: 'المهام المرسلة'),
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
      backgroundColor: AppTheme.scaffoldBackground,
      appBar: AppBar(
        title: const Text('⚖️ مرحباً أستاذ'),
        backgroundColor: AppTheme.scaffoldBackground,
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle_outlined, color: AppTheme.primaryGold),
            tooltip: 'تفاصيل حسابي',
            onPressed: _openAccountDetails,
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            tooltip: 'تسجيل خروج',
            onPressed: _logout,
          ),
        ],
      ),
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
        Expanded(child: _Chip(label: '🏠 عقار', selected: _selectedItemType == 0, onTap: () => _changeItemType(0), e2eId: 'e2e_task_type_property')),
        const SizedBox(width: 12),
        Expanded(child: _Chip(label: '🚗 سيارة', selected: _selectedItemType == 1, onTap: () => _changeItemType(1), e2eId: 'e2e_task_type_vehicle')),
      ]), const SizedBox(height: 16), const Text('المعقب:', style: TextStyle(color: AppTheme.textGrey, fontSize: 14)),
      expediters.isEmpty
          ? Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppTheme.surfaceBlack, borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withOpacity(0.3))),
              child: const Row(children: [Icon(Icons.info_outline, color: Colors.orange, size: 18), SizedBox(width: 10),
                Expanded(child: Text('لا يوجد معقبين. أضف معقباً من إدارة الموظفين.', style: TextStyle(color: AppTheme.textGrey, fontSize: 13)))]))
          : E2E(
              id: 'e2e_lawyer_expediter_dropdown',
              child: DropdownButtonFormField<String>(value: _selectedExpediterUid, dropdownColor: AppTheme.surfaceBlack,
              style: const TextStyle(color: AppTheme.textWhite),
              decoration: const InputDecoration(labelText: 'اختر المعقب', prefixIcon: Icon(Icons.person_search, color: AppTheme.primaryGold)),
              items: expediters.map((e) => DropdownMenuItem(value: e['id']?.toString(), child: Text('${e['nm']} (${e['ph']})'))).toList(),
              onChanged: (v) => setState(() => _selectedExpediterUid = v)),
            ),
      const SizedBox(height: 16),
      if (_selectedItemType == 0) ...[
        E2E(id: 'e2e_task_property_number', child: TextField(controller: _taskPropertyCtrl, style: const TextStyle(color: AppTheme.textWhite),
          decoration: const InputDecoration(labelText: 'رقم العقار', hintText: '12345'))),
        const SizedBox(height: 12),
        E2E(id: 'e2e_task_property_zone', child: TextField(controller: _taskZoneCtrl, style: const TextStyle(color: AppTheme.textWhite),
          decoration: const InputDecoration(labelText: 'المنطقة العقارية', hintText: 'السويداء'))),
      ],
      if (_selectedItemType == 1)
        E2E(id: 'e2e_task_vehicle_number', child: TextField(controller: _taskPropertyCtrl, style: const TextStyle(color: AppTheme.textWhite),
          decoration: const InputDecoration(labelText: 'رقم المركبة', hintText: '123456'))),
      const SizedBox(height: 16),
      _buildChecklistSelector(),
      const SizedBox(height: 12),
      E2E(id: 'e2e_task_notes', child: TextField(controller: _taskNotesCtrl, style: const TextStyle(color: AppTheme.textWhite), maxLines: 3,
        decoration: const InputDecoration(labelText: 'تعليمات', hintText: 'ملاحظات للمعقب...'))),
      const SizedBox(height: 24),
      E2E(id: 'e2e_lawyer_send_task', button: true, child: SizedBox(width: double.infinity, height: 50, child: ElevatedButton.icon(
        onPressed: _creatingTask ? null : _createTask,
        icon: _creatingTask ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send),
        label: Text(_creatingTask ? 'جاري...' : 'إرسال للمعقب', style: const TextStyle(fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGold, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))))),
    ]));
  }

  Widget _buildChecklistSelector() {
    final docs = _documentTemplatesFor(_selectedItemType);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBlack,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primaryGold.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('الوثائق المطلوبة من المعقب:', style: TextStyle(color: AppTheme.primaryGold, fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('حدد وثيقة أو أكثر لنفس المهمة، ثم اضبط عدد النسخ والتعليمات لكل وثيقة.', style: TextStyle(color: AppTheme.textGrey, fontSize: 12, height: 1.35)),
          const SizedBox(height: 12),
          ...docs.map((doc) {
            final key = doc['key']!;
            final selected = _selectedChecklist.any((item) => item['key'] == key);
            final canDelete = !_isBaseDocument(key);
            return E2E(
              id: 'e2e_doc_$key',
              button: true,
              child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: selected ? AppTheme.primaryGold.withOpacity(0.1) : AppTheme.scaffoldBackground,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: selected ? AppTheme.primaryGold : AppTheme.textGrey.withOpacity(0.18)),
              ),
              child: Row(
                children: [
                  Checkbox(
                    value: selected,
                    activeColor: AppTheme.primaryGold,
                    onChanged: (value) => _toggleDocumentForTask(doc, value == true),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () => _toggleDocumentForTask(doc, !selected),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(doc['title']!, style: const TextStyle(color: AppTheme.textWhite, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                  if (canDelete)
                    IconButton(
                      tooltip: 'حذف من القائمة الدائمة',
                      onPressed: () => _deletePermanentDocumentTemplate(doc),
                      icon: const Icon(Icons.delete_outline, color: AppTheme.errorRed, size: 20),
                    ),
                ],
              ),
              ),
            );
          }),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _addAllDefaultDocuments,
            icon: const Icon(Icons.playlist_add_check, color: AppTheme.primaryGold),
            label: const Text('تحديد كل وثائق القائمة', style: TextStyle(color: AppTheme.primaryGold)),
            style: OutlinedButton.styleFrom(side: const BorderSide(color: AppTheme.primaryGold), minimumSize: const Size(double.infinity, 44)),
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white12),
          const SizedBox(height: 8),
          const Text('إضافة وثيقة دائمة للقائمة:', style: TextStyle(color: AppTheme.primaryGold, fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _permanentDocTitleCtrl,
                style: const TextStyle(color: AppTheme.textWhite),
                decoration: const InputDecoration(labelText: 'اسم الوثيقة الجديدة', hintText: 'تُحفظ في القائمة لهذا الجهاز'),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'إضافة للقائمة',
              onPressed: _addPermanentDocumentTemplate,
              icon: const Icon(Icons.add_circle, color: AppTheme.primaryGold, size: 30),
            ),
          ]),
          const SizedBox(height: 16),
          const Text('وثيقة لمرة واحدة لهذه المهمة فقط:', style: TextStyle(color: AppTheme.primaryGold, fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _oneTimeDocTitleCtrl,
                style: const TextStyle(color: AppTheme.textWhite),
                decoration: const InputDecoration(labelText: 'نص حر', hintText: 'لا تُحفظ في القائمة الدائمة'),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'إضافة للمهمة فقط',
              onPressed: _addOneTimeDocument,
              icon: const Icon(Icons.post_add, color: AppTheme.primaryGold, size: 30),
            ),
          ]),
          const SizedBox(height: 16),
          const Divider(color: Colors.white12),
          const SizedBox(height: 8),
          if (_selectedChecklist.isEmpty)
            const Text('لم تحدد أي وثيقة بعد. يجب تحديد وثيقة واحدة على الأقل.', style: TextStyle(color: AppTheme.textGrey, fontSize: 12))
          else ...[
            Text('الوثائق المحددة (${_selectedChecklist.length}):', style: const TextStyle(color: AppTheme.primaryGold, fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ..._selectedChecklist.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final title = item['title']?.toString() ?? '';
              final rawCopies = int.tryParse((item['required_copies'] ?? 1).toString()) ?? 1;
              final copies = rawCopies < 1 ? 1 : (rawCopies > 10 ? 10 : rawCopies);
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.scaffoldBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primaryGold.withOpacity(0.15)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(title, style: const TextStyle(color: AppTheme.textWhite, fontWeight: FontWeight.bold, fontSize: 13))),
                    IconButton(
                      onPressed: () => setState(() => _selectedChecklist.removeAt(index)),
                      icon: const Icon(Icons.delete_outline, color: AppTheme.errorRed, size: 20),
                    ),
                  ]),
                  DropdownButtonFormField<int>(
                    value: copies,
                    dropdownColor: AppTheme.surfaceBlack,
                    style: const TextStyle(color: AppTheme.textWhite),
                    decoration: const InputDecoration(labelText: 'عدد النسخ المطلوبة'),
                    items: List.generate(10, (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1} نسخة'))),
                    onChanged: (value) => setState(() => item['required_copies'] = value ?? 1),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    key: ValueKey('instr_${item['key']}'),
                    initialValue: item['lawyer_instructions']?.toString() ?? '',
                    maxLines: 2,
                    style: const TextStyle(color: AppTheme.textWhite),
                    decoration: const InputDecoration(labelText: 'تعليمات خاصة بهذه الوثيقة', hintText: 'مثال: نسختان مصدقتان / صورة واضحة / إحضار الأصل'),
                    onChanged: (value) => item['lawyer_instructions'] = value.trim(),
                  ),
                ]),
              );
            }),
          ],
        ],
      ),
    );
  }

  Future<void> _requestRevision(ExpeditingTaskModel task, ChecklistItemModel item) async {
    final ctrl = TextEditingController(text: item.revisionNotes);
    final notes = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceBlack,
        title: Text('إعادة ${item.title}', style: const TextStyle(color: AppTheme.primaryGold, fontSize: 16)),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          style: const TextStyle(color: AppTheme.textWhite),
          decoration: const InputDecoration(labelText: 'سبب الإعادة / المطلوب تصحيحه'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء', style: TextStyle(color: AppTheme.textGrey))),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('إرسال للمعقب')),
        ],
      ),
    );
    ctrl.dispose();
    if (notes == null || !mounted) return;
    final ok = await context.read<LegalProvider>().requestChecklistRevision(
      taskId: task.id,
      itemKey: item.key,
      notes: notes,
    );
    if (!mounted) return;
    if (ok) {
      _snack('تمت إعادة الوثيقة للمعقب مع التعليمات');
      if (Navigator.canPop(context)) Navigator.pop(context);
    } else {
      _snack(context.read<LegalProvider>().error ?? 'فشل طلب إعادة الوثيقة', bg: AppTheme.errorRed);
    }
  }

  void _showTaskReviewDialog(ExpeditingTaskModel task) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceBlack,
        title: Text('تفاصيل مهمة التعقيب', style: const TextStyle(color: AppTheme.primaryGold, fontSize: 16)),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(task.itemType == 0 ? 'نوع المهمة: عقار' : 'نوع المهمة: سيارة', style: const TextStyle(color: AppTheme.textWhite, fontWeight: FontWeight.bold)),
                if (task.targetPropertyNum.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text('الرقم/المرجع: ${task.targetPropertyNum}', style: const TextStyle(color: AppTheme.textGrey, fontSize: 12)),
                ],
                if (task.targetZone.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('المنطقة: ${task.targetZone}', style: const TextStyle(color: AppTheme.textGrey, fontSize: 12)),
                ],
                if (task.lawyerNotes.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text('تعليمات عامة: ${task.lawyerNotes}', style: const TextStyle(color: AppTheme.textGrey, fontSize: 12)),
                ],
                const SizedBox(height: 12),
                ...task.checklist.map((item) {
                  final imageUrl = item.attachmentSignedUrl.isNotEmpty
                      ? item.attachmentSignedUrl
                      : (item.attachmentUrl.startsWith('http') ? item.attachmentUrl : '');
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.scaffoldBackground,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: item.status == 2 ? Colors.green.withOpacity(0.45) : AppTheme.primaryGold.withOpacity(0.18)),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Icon(item.status == 2 ? Icons.check_circle : Icons.pending_actions, color: item.status == 2 ? Colors.green : AppTheme.primaryGold, size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text(item.title, style: const TextStyle(color: AppTheme.textWhite, fontWeight: FontWeight.bold))),
                      ]),
                      const SizedBox(height: 6),
                      Text('عدد النسخ المطلوبة: ${item.requiredCopies}', style: const TextStyle(color: AppTheme.primaryGold, fontSize: 12)),
                      if (item.lawyerInstructions.isNotEmpty) Text('تعليماتك: ${item.lawyerInstructions}', style: const TextStyle(color: AppTheme.textGrey, fontSize: 12)),
                      if (item.inputValue.isNotEmpty) Text('بيانات المعقب: ${item.inputValue}', style: const TextStyle(color: AppTheme.textWhite, fontSize: 12)),
                      if (item.notes.isNotEmpty) Text('ملاحظات المعقب: ${item.notes}', style: const TextStyle(color: AppTheme.textGrey, fontSize: 12)),
                      if (item.revisionNotes.isNotEmpty) Text('طلب إعادة سابق: ${item.revisionNotes}', style: const TextStyle(color: AppTheme.errorRed, fontSize: 12)),
                      if (imageUrl.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(imageUrl, height: 170, width: double.infinity, fit: BoxFit.cover),
                        ),
                      ] else ...[
                        const SizedBox(height: 8),
                        const Text('لا توجد صورة مرفقة بعد', style: TextStyle(color: AppTheme.errorRed, fontSize: 12)),
                      ],
                      if (task.status == 2) ...[
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () => _requestRevision(task, item),
                          icon: const Icon(Icons.replay, color: AppTheme.errorRed, size: 18),
                          label: const Text('إعادة هذا السند للمعقب', style: TextStyle(color: AppTheme.errorRed)),
                          style: OutlinedButton.styleFrom(side: const BorderSide(color: AppTheme.errorRed)),
                        ),
                      ],
                    ]),
                  );
                }),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق', style: TextStyle(color: AppTheme.textGrey))),
          if (task.status == 2)
            ElevatedButton(onPressed: () { Navigator.pop(ctx); _approveTask(task); }, child: const Text('اعتماد المهمة')),
        ],
      ),
    );
  }

  Future<void> _approveTask(ExpeditingTaskModel task) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceBlack,
        title: const Text('اعتماد مهمة التعقيب', style: TextStyle(color: AppTheme.primaryGold)),
        content: const Text(
          'هل تؤكد اعتماد إنجاز المعقب لهذه المهمة؟ سيتم إشعار المعقب بالاعتماد.',
          style: TextStyle(color: AppTheme.textGrey, height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء', style: TextStyle(color: AppTheme.textGrey))),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('اعتماد')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final ok = await context.read<LegalProvider>().approveExpeditingTask(taskId: task.id);
    if (!mounted) return;
    if (ok) {
      _snack('✅ تم اعتماد المهمة وإشعار المعقب');
    } else {
      _snack(context.read<LegalProvider>().error ?? 'فشل اعتماد المهمة', bg: AppTheme.errorRed);
    }
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
              if (t.status == 2) ...[
                const SizedBox(width: 8),
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: Colors.orange.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                  child: const Text('بانتظار اعتمادك', style: TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold)))],
              if (t.status == 3) ...[
                const SizedBox(width: 8),
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: Colors.green.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                  child: const Text('معتمد', style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold)))],
            ]),
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: OutlinedButton.icon(
              onPressed: () => _showTaskReviewDialog(t),
              icon: const Icon(Icons.visibility, color: AppTheme.primaryGold),
              label: const Text('فتح تفاصيل المهمة والوثائق', style: TextStyle(color: AppTheme.primaryGold, fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(side: const BorderSide(color: AppTheme.primaryGold)),
            )),
            if (t.status == 2) ...[
              const SizedBox(height: 8),
              SizedBox(width: double.infinity, child: ElevatedButton.icon(
                onPressed: () => _showTaskReviewDialog(t),
                icon: const Icon(Icons.verified, color: AppTheme.deepBlack),
                label: const Text('مراجعة ثم اعتماد إنجاز المعقب', style: TextStyle(color: AppTheme.deepBlack, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              )),
            ],
          ]));
      }));
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? e2eId;

  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.e2eId,
  });

  @override
  Widget build(BuildContext context) {
    final chip = GestureDetector(onTap: onTap, child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: selected ? AppTheme.primaryGold.withOpacity(0.2) : AppTheme.surfaceBlack,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: selected ? AppTheme.primaryGold : AppTheme.textGrey.withOpacity(0.3), width: selected ? 2 : 1)),
      child: Center(child: Text(label, style: TextStyle(color: selected ? AppTheme.primaryGold : AppTheme.textGrey,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal, fontSize: 15)))));
    return e2eId == null ? chip : E2E(id: e2eId!, button: true, child: chip);
  }
}
