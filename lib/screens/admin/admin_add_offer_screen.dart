import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import '../../providers/offer_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/config_provider.dart';
import '../../core/constants/db_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/business_service.dart';
import '../../core/network/supabase_service.dart';
import '../../models/offer_model.dart';
import '../../models/user_model.dart';
import '../../services/storage_service.dart';
import '../../widgets/location_picker.dart';

/// شاشة إضافة عرض من الإدارة
/// - تختلف عن شاشة المستخدم في: اختيار صاحب العرض + حفظ added_by
/// - من يصل إليها: role >= UserRole.minAdmin فقط
/// - added_by = uid الموظف/المدير — يظهر فقط في لوحة الإدارة
class AdminAddOfferScreen extends StatefulWidget {
  const AdminAddOfferScreen({super.key});

  @override
  State<AdminAddOfferScreen> createState() => _AdminAddOfferScreenState();
}

class _AdminAddOfferScreenState extends State<AdminAddOfferScreen> {
  static const String _customCityOption = '__custom_city__';

  // ── الخطوات ──
  int _currentStep = 0;

  // ── بيانات العرض ──
  int? _selectedType;
  int? _selectedTrans;
  int? _selectedMainCat;
  int? _selectedSubCat;
  String? _selectedCityArea;
  int _cur = Currency.lbp;
  final _priceCtrl     = TextEditingController();
  final _locCtrl       = TextEditingController();
  final _descCtrl      = TextEditingController();
  final _specCtrl      = TextEditingController();
  final _ttlCtrl       = TextEditingController();
  final _customSubCtrl = TextEditingController();
  final _contactPhCtrl = TextEditingController();
  final _customCityCtrl = TextEditingController();

  // ── صاحب العرض ──
  UserModel? _selectedOwner;
  List<UserModel> _users = [];
  bool _loadingUsers = true;
  final _ownerSearchCtrl = TextEditingController();

  // ── الوسائط ──
  final List<XFile> _pickedImages = [];
  XFile? _docImage;
  LatLng? _pickedLocation;
  int? _selectedDocType;

  // ── المواعيد المتاحة (avl) ──
  static const _weekDays = [
    ('mon', 'الاثنين'), ('tue', 'الثلاثاء'), ('wed', 'الأربعاء'),
    ('thu', 'الخميس'),  ('fri', 'الجمعة'),    ('sat', 'السبت'),
    ('sun', 'الأحد'),
  ];
  final Map<String, bool> _avlDaysEnabled = {
    'mon': false, 'tue': false, 'wed': false, 'thu': false,
    'fri': false, 'sat': false, 'sun': false,
  };
  final Map<String, List<Map<String, String>>> _avlSlots = {
    'mon': [], 'tue': [], 'wed': [], 'thu': [],
    'fri': [], 'sat': [], 'sun': [],
  };

  bool _submitting = false;
  String _progressMsg = '';

  final _storage = StorageService();
  final _biz     = BusinessService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ConfigProvider>().loadConfig();
      _loadUsers();
    });
  }

  @override
  void dispose() {
    _priceCtrl.dispose(); _locCtrl.dispose(); _descCtrl.dispose();
    _specCtrl.dispose();  _ttlCtrl.dispose(); _customSubCtrl.dispose();
    _contactPhCtrl.dispose(); _customCityCtrl.dispose();
    _ownerSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() => _loadingUsers = true);
    try {
      final res = await SupabaseService().client
          .from(DbTables.users)
          .select('id, nm, ph, role, sts, i_del')
          .eq('i_del', 0)
          .eq('sts', 0)
          .order('nm');
      _users = (res as List)
          .map((d) => UserModel.fromSupabase(
              Map<String, dynamic>.from(d), d['id'] as String))
          .toList();
    } catch (_) {}
    if (mounted) setState(() => _loadingUsers = false);
  }

  Map<String, List<String>> _buildAvl() {
    final result = <String, List<String>>{};
    for (final day in _weekDays) {
      final key = day.$1;
      if (_avlDaysEnabled[key] == true && _avlSlots[key]!.isNotEmpty) {
        result[key] = _avlSlots[key]!
            .where((s) => s['from']!.isNotEmpty && s['to']!.isNotEmpty)
            .map((s) => '${s['from']}-${s['to']}')
            .toList();
      }
    }
    return result;
  }

  Future<void> _submit() async {
    final auth      = context.read<AuthProvider>();
    final offerProv = context.read<OfferProvider>();
    final config    = context.read<ConfigProvider>().config;
    final admin     = auth.userModel;

    if (admin == null || !admin.isAdmin) {
      _snack('غير مصرح لك بهذه العملية');
      return;
    }
    if (_selectedOwner == null) {
      _snack('يرجى اختيار صاحب العرض');
      return;
    }
    if (_selectedType == null || _selectedTrans == null ||
        _selectedMainCat == null ||
        _selectedCityArea == null ||
        (_selectedCityArea == _customCityOption && _customCityCtrl.text.trim().isEmpty) ||
        _locCtrl.text.trim().isEmpty) {
      _snack('يرجى إكمال البيانات الأساسية');
      return;
    }
    if (_contactPhCtrl.text.trim().isEmpty) {
      _snack('رقم الهاتف للتواصل إلزامي');
      return;
    }
    final price = double.tryParse(_priceCtrl.text) ?? 0.0;
    if (price <= 0) { _snack('يرجى إدخال سعر صالح'); return; }
    if (_selectedDocType == null) {
      _snack('يرجى اختيار نوع سند الملكية');
      return;
    }

    setState(() { _submitting = true; _progressMsg = 'جارٍ رفع الصور...'; });

    List<String> imageUrls = [];
    if (_pickedImages.isNotEmpty) {
      imageUrls = await _storage.uploadOfferImages(
        files: _pickedImages,
        userId: _selectedOwner!.uid,
        onProgress: (d, t) {
          if (mounted) setState(() => _progressMsg = 'الصور ($d/$t)...');
        },
      );
    }

    setState(() => _progressMsg = 'جارٍ رفع السند...');
    String docUrl = '';
    if (_docImage != null) {
      try {
        final storage = SupabaseService().storage;
        final path = 'docs/${_selectedOwner!.uid}/doc_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final bytes = kIsWeb
            ? await _docImage!.readAsBytes()
            : await (await _storage.compressImage(File(_docImage!.path)) ??
                    File(_docImage!.path))
                .readAsBytes();
        await storage.from(StorageService.offerBucket).uploadBinary(path, bytes,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: true));
        docUrl = storage.from(StorageService.offerBucket).getPublicUrl(path);
      } catch (_) {}
    }

    setState(() => _progressMsg = 'جارٍ إنشاء العرض...');
    final cityName = _selectedCityArea == _customCityOption
        ? _customCityCtrl.text.trim()
        : (_selectedCityArea?.trim() ?? '');
    final loc = {'r': 0, 'd': _locCtrl.text.trim(), 'city': cityName};

    final customSub = _customSubCtrl.text.trim();
    final catLabel  = customSub.isNotEmpty ? customSub : _catLabel();
    final autoTitle = '$catLabel في $cityName';
    final finalTitle = _ttlCtrl.text.trim().isNotEmpty
        ? _ttlCtrl.text.trim()
        : autoTitle;

    // الوسيط يُحدَّد تلقائياً إذا كان صاحب العرض وسيطاً
    final brkId = _selectedOwner!.role == UserRole.broker
        ? _selectedOwner!.uid
        : '';

    final offer = OfferModel(
      id: '',
      usrId:     _selectedOwner!.uid,
      brkId:     brkId,
      ttl:       finalTitle,
      typ:       _selectedType!,
      trx:       _selectedTrans!,
      cat:       _selectedMainCat!,
      sub:       (_selectedSubCat == null || _selectedSubCat == -1) ? 0 : _selectedSubCat!,
      contactPh: _contactPhCtrl.text.trim(),
      prc:       price,
      cur:       _cur,
      loc:       loc,
      descript:  _descCtrl.text.trim().isNotEmpty
                   ? _descCtrl.text.trim()
                   : _locCtrl.text.trim(),
      specs:     {'details': _specCtrl.text, if (customSub.isNotEmpty) 'custom_sub': customSub},
      imgs:      imageUrls,
      vdo:       '',
      exactLoc:  _pickedLocation != null
                   ? '${_pickedLocation!.latitude},${_pickedLocation!.longitude}'
                   : '',
      docTp:     _selectedDocType ?? 0,
      docImg:    docUrl,
      avl:       _buildAvl(),
      addedBy:   admin.uid,  // ← من أضاف العرض (الموظف/المدير)
      sts:       OfferStatus.review,
      iPub:      0,
      tsCrt:     DateTime.now(),
    );

    OfferModel? created;
    try {
      // نستخدم RPC مخصصة للإدارة لتمرير added_by
      final response = await SupabaseService().client.rpc(
        'create_offer_internal',
        params: {
          'p_user_uid': _selectedOwner!.uid,
          'p_offer':    {...offer.toMap(), 'added_by': admin.uid},
        },
      );
      if (response != null && (response as List).isNotEmpty) {
        final row = Map<String, dynamic>.from(response.first as Map);
        created = OfferModel.fromSupabase(row, row['id'] as String);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        _snack('فشل في إنشاء العرض: $e');
      }
      return;
    }

    if (mounted) setState(() => _submitting = false);
    if (created != null) {
      if (mounted) Navigator.pop(context);
      _snack('✅ تم إنشاء العرض وإرساله للمراجعة');
    } else {
      _snack('فشل إنشاء العرض، حاول مجدداً');
    }
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إضافة عرض — الإدارة'),
        backgroundColor: Colors.transparent,
      ),
      body: Stack(
        children: [
          Stepper(
            type: StepperType.vertical,
            currentStep: _currentStep,
            onStepTapped: (s) => setState(() => _currentStep = s),
            controlsBuilder: (_, __) => const SizedBox.shrink(),
            steps: [
              _stepOwner(),
              _stepBasics(),
              _stepDetails(),
              _stepMedia(),
              _stepAvl(),
              _stepDoc(),
            ],
          ),
          if (_submitting)
            Container(
              color: const Color.fromRGBO(0, 0, 0, 0.7),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(color: AppTheme.primaryGold),
                    const SizedBox(height: 16),
                    Text(_progressMsg,
                        style: const TextStyle(color: AppTheme.textWhite)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─── Step 0: اختيار صاحب العرض ───
  Step _stepOwner() {
    final query = _ownerSearchCtrl.text.toLowerCase();
    final filtered = _users.where((u) {
      return u.nm.toLowerCase().contains(query) ||
          u.ph.contains(query);
    }).toList();

    return Step(
      title: Row(children: [
        const Text('صاحب العرض',
            style: TextStyle(color: AppTheme.primaryGold, fontWeight: FontWeight.bold)),
        if (_selectedOwner != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              _selectedOwner!.nm.isNotEmpty ? _selectedOwner!.nm : _selectedOwner!.ph,
              style: const TextStyle(color: Colors.green, fontSize: 12),
            ),
          ),
        ],
      ]),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // تنويه داخلي
          Container(
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
            ),
            child: const Row(children: [
              Icon(Icons.admin_panel_settings, color: Colors.amber, size: 16),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'العرض يُضاف من الإدارة — سيُسجَّل من أضافه داخلياً.',
                  style: TextStyle(color: Colors.amber, fontSize: 12),
                ),
              ),
            ]),
          ),
          TextField(
            controller: _ownerSearchCtrl,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'بحث عن المستخدم (الاسم أو الهاتف)',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          _loadingUsers
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGold))
              : SizedBox(
                  height: 220,
                  child: filtered.isEmpty
                      ? const Center(child: Text('لا يوجد مستخدم',
                          style: TextStyle(color: AppTheme.textGrey)))
                      : ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (_, i) {
                            final u = filtered[i];
                            final selected = _selectedOwner?.uid == u.uid;
                            return ListTile(
                              dense: true,
                              selected: selected,
                              selectedTileColor:
                                  AppTheme.primaryGold.withValues(alpha: 0.1),
                              leading: CircleAvatar(
                                backgroundColor: AppTheme.primaryGold,
                                radius: 16,
                                child: Text(
                                  u.nm.isNotEmpty ? u.nm[0].toUpperCase() : '؟',
                                  style: const TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14),
                                ),
                              ),
                              title: Text(
                                u.nm.isNotEmpty ? u.nm : 'مجهول',
                                style: const TextStyle(
                                    color: AppTheme.textWhite, fontSize: 14),
                              ),
                              subtitle: Text(
                                u.ph + (u.role == UserRole.broker ? ' • وسيط' : ''),
                                style: const TextStyle(
                                    color: AppTheme.textGrey, fontSize: 11),
                              ),
                              trailing: selected
                                  ? const Icon(Icons.check_circle,
                                      color: AppTheme.primaryGold)
                                  : null,
                              onTap: () => setState(() => _selectedOwner = u),
                            );
                          },
                        ),
                ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _selectedOwner == null
                  ? null
                  : () => setState(() => _currentStep = 1),
              child: const Text('التالي →'),
            ),
          ),
        ],
      ),
      isActive: _currentStep >= 0,
    );
  }

  // ─── Step 1: الأساسيات ───
  Step _stepBasics() {
    final config = context.watch<ConfigProvider>().config;
    final mainCategories = _categoryGroupMap();
    final subCategories = _selectedMainCat != null
        ? _subCategoryMap(_selectedMainCat!)
        : <int, String>{};

    final cityItems = _cityOptions()
        .map((c) => DropdownMenuItem<String>(
              value: c,
              child: Text(c, overflow: TextOverflow.ellipsis),
            ))
        .toList()
      ..add(const DropdownMenuItem<String>(
          value: _customCityOption, child: Text('آخر (إدخال حر)')));

    return Step(
      title: const Text('الأساسيات',
          style: TextStyle(
              color: AppTheme.primaryGold, fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _dd('نوع العرض', ['عقار', 'سيارة'], (v) => setState(() {
                _selectedType = v == 'عقار' ? 0 : 1;
                _selectedMainCat = null;
                _selectedSubCat  = null;
              })),
          const SizedBox(height: 16),
          _dd('نوع المعاملة', ['بيع', 'إيجار'],
              (v) => setState(() => _selectedTrans = v == 'بيع' ? 0 : 1)),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            initialValue: _selectedMainCat,
            dropdownColor: AppTheme.surfaceBlack,
            style: const TextStyle(color: AppTheme.textWhite),
            decoration: const InputDecoration(
                border: OutlineInputBorder(), labelText: 'التصنيف الرئيسي'),
            items: mainCategories.entries
                .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                .toList(),
            onChanged: (v) => setState(() {
              _selectedMainCat = v;
              _selectedSubCat  = null;
              _customSubCtrl.clear();
            }),
            hint: const Text('اختر التصنيف',
                style: TextStyle(color: AppTheme.textGrey)),
          ),
          if (_selectedMainCat != null) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _selectedSubCat,
              dropdownColor: AppTheme.surfaceBlack,
              style: const TextStyle(color: AppTheme.textWhite, fontSize: 14),
              decoration: const InputDecoration(
                  border: OutlineInputBorder(), labelText: 'التصنيف الفرعي'),
              items: [
                ...subCategories.entries.map(
                    (e) => DropdownMenuItem(value: e.key, child: Text(e.value))),
                const DropdownMenuItem(value: -1, child: Text('آخر (يدوي)')),
              ],
              onChanged: (v) => setState(() {
                _selectedSubCat = v;
                if (v != -1) _customSubCtrl.clear();
              }),
              hint: const Text('اختر التصنيف الفرعي',
                  style: TextStyle(color: AppTheme.textGrey, fontSize: 14)),
            ),
            if (_selectedSubCat == -1)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: TextField(
                  controller: _customSubCtrl,
                  decoration: const InputDecoration(
                      labelText: 'اكتب التصنيف الفرعي يدوياً',
                      border: OutlineInputBorder()),
                ),
              ),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _contactPhCtrl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'رقم الهاتف للتواصل (إلزامي)',
              hintText: 'رقم جوال صاحب العرض أو المكتب',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _selectedCityArea,
            dropdownColor: AppTheme.surfaceBlack,
            style: const TextStyle(color: AppTheme.textWhite),
            decoration: const InputDecoration(
                border: OutlineInputBorder(), labelText: 'المنطقة الرئيسية'),
            items: cityItems,
            onChanged: (v) => setState(() {
              _selectedCityArea = v;
              if (v != _customCityOption) _customCityCtrl.clear();
            }),
            hint: const Text('اختر المنطقة',
                style: TextStyle(color: AppTheme.textGrey, fontSize: 14)),
            menuMaxHeight: 300,
          ),
          if (_selectedCityArea == _customCityOption)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: TextField(
                controller: _customCityCtrl,
                decoration: const InputDecoration(
                    labelText: 'اكتب المنطقة يدوياً',
                    border: OutlineInputBorder()),
              ),
            ),
          const SizedBox(height: 16),
          _buildLocationAutocomplete(),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => setState(() => _currentStep = 2),
              child: const Text('التالي →'),
            ),
          ),
        ]),
      ),
      isActive: _currentStep >= 1,
    );
  }

  // ─── Step 2: التفاصيل ───
  Step _stepDetails() => Step(
        title: const Text('التفاصيل',
            style: TextStyle(
                color: AppTheme.primaryGold, fontWeight: FontWeight.bold)),
        content: Column(children: [
          TextField(
            controller: _ttlCtrl,
            maxLength: 80,
            decoration: const InputDecoration(
              labelText: 'عنوان مخصص (اختياري)',
              hintText: 'يُبنى تلقائياً إذا تُرك فارغاً',
              border: OutlineInputBorder(),
              counterStyle: TextStyle(color: AppTheme.textGrey),
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: _priceCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'السعر (إلزامي)',
                    border: OutlineInputBorder()),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<int>(
                initialValue: _cur,
                dropdownColor: AppTheme.surfaceBlack,
                style: const TextStyle(color: AppTheme.textWhite),
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: Currency.dollar, child: Text('دولار')),
                  DropdownMenuItem(value: Currency.lbp, child: Text('ل.س')),
                ],
                onChanged: (v) => setState(() => _cur = v ?? Currency.lbp),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          TextField(
            controller: _descCtrl,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'وصف تفصيلي للعرض (اختياري)',
              hintText: 'مميزات العرض، حالته، الطابق، المساحة...',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _specCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'المواصفات التقنية (اختيارية)',
              hintText: 'مثال: 3 غرف، 2 حمام، مساحة 150م²، طابق ثالث',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          // الخريطة
          const Row(children: [
            Icon(Icons.map, color: AppTheme.primaryGold, size: 18),
            SizedBox(width: 6),
            Text('الموقع الدقيق على الخريطة (اختياري)',
                style: TextStyle(color: AppTheme.primaryGold, fontWeight: FontWeight.bold, fontSize: 14)),
          ]),
          const SizedBox(height: 8),
          LocationPicker(
            initial: _pickedLocation,
            onPicked: (loc) => setState(() => _pickedLocation = loc),
            height: 220,
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => setState(() => _currentStep = 3),
              child: const Text('التالي →'),
            ),
          ),
        ]),
        isActive: _currentStep >= 2,
      );

  // ─── Step 3: الصور ───
  Step _stepMedia() => Step(
        title: const Text('الصور',
            style: TextStyle(
                color: AppTheme.primaryGold, fontWeight: FontWeight.bold)),
        content: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ElevatedButton.icon(
            onPressed: _pickImages,
            icon: const Icon(Icons.add_photo_alternate),
            label: Text(
                'إضافة صور (${_pickedImages.length}/${StorageService.maxImages})'),
          ),
          const SizedBox(height: 10),
          if (_pickedImages.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _pickedImages.asMap().entries.map((e) {
                return Stack(children: [
                  ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: _thumb(e.value)),
                  Positioned(
                    top: -8, left: -8,
                    child: IconButton(
                      icon: const Icon(Icons.cancel, color: AppTheme.errorRed),
                      onPressed: () =>
                          setState(() => _pickedImages.removeAt(e.key)),
                    ),
                  ),
                ]);
              }).toList(),
            ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => setState(() => _currentStep = 4),
              child: const Text('التالي →'),
            ),
          ),
        ]),
        isActive: _currentStep >= 3,
      );

  // ─── Step 4: المواعيد المتاحة (avl) ───
  Step _stepAvl() => Step(
        title: const Text('المواعيد المتاحة',
            style: TextStyle(
                color: AppTheme.primaryGold, fontWeight: FontWeight.bold)),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('حدد الأيام والفترات الزمنية المتاحة للمعاينة.',
                style: TextStyle(color: AppTheme.textGrey, fontSize: 13)),
            const SizedBox(height: 16),
            ..._weekDays.map((day) {
              final key     = day.$1;
              final label   = day.$2;
              final enabled = _avlDaysEnabled[key] ?? false;
              final slots   = _avlSlots[key] ?? [];
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceBlack,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: enabled
                        ? AppTheme.primaryGold.withValues(alpha: 0.5)
                        : Colors.white12,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: () => setState(() {
                        _avlDaysEnabled[key] = !enabled;
                        if (!enabled && slots.isEmpty) {
                          _avlSlots[key]!.add({'from': '', 'to': ''});
                        }
                      }),
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        child: Row(children: [
                          Icon(
                            enabled
                                ? Icons.check_box
                                : Icons.check_box_outline_blank,
                            color: enabled
                                ? AppTheme.primaryGold
                                : AppTheme.textGrey,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Text(label,
                              style: TextStyle(
                                color: enabled
                                    ? AppTheme.textWhite
                                    : AppTheme.textGrey,
                                fontWeight: FontWeight.bold,
                              )),
                          const Spacer(),
                          if (enabled)
                            TextButton.icon(
                              onPressed: () => setState(() {
                                _avlSlots[key]!.add({'from': '', 'to': ''});
                              }),
                              icon: const Icon(Icons.add,
                                  size: 16, color: AppTheme.primaryGold),
                              label: const Text('فترة',
                                  style: TextStyle(
                                      color: AppTheme.primaryGold,
                                      fontSize: 12)),
                              style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero),
                            ),
                        ]),
                      ),
                    ),
                    if (enabled)
                      ...slots.asMap().entries.map((e) {
                        final i    = e.key;
                        final slot = e.value;
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          child: Row(children: [
                            const Text('من',
                                style: TextStyle(
                                    color: AppTheme.textGrey, fontSize: 13)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: _timeField(
                                value: slot['from'] ?? '',
                                hint: '09:00',
                                onChanged: (v) => setState(
                                    () => _avlSlots[key]![i]['from'] = v),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text('إلى',
                                style: TextStyle(
                                    color: AppTheme.textGrey, fontSize: 13)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: _timeField(
                                value: slot['to'] ?? '',
                                hint: '12:00',
                                onChanged: (v) => setState(
                                    () => _avlSlots[key]![i]['to'] = v),
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.remove_circle,
                                  color: Colors.red, size: 20),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => setState(() {
                                _avlSlots[key]!.removeAt(i);
                                if (_avlSlots[key]!.isEmpty) {
                                  _avlDaysEnabled[key] = false;
                                }
                              }),
                            ),
                          ]),
                        );
                      }),
                    if (enabled) const SizedBox(height: 8),
                  ],
                ),
              );
            }),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => setState(() => _currentStep = 5),
                child: const Text('التالي →'),
              ),
            ),
          ],
        ),
        isActive: _currentStep >= 4,
      );

  // ─── Step 5: السند والإرسال ───
  Step _stepDoc() {
    final config   = context.watch<ConfigProvider>().config;
    final docTypes = config?.documentTypes ?? {};

    return Step(
      title: const Text('السند والإرسال',
          style: TextStyle(
              color: AppTheme.primaryGold, fontWeight: FontWeight.bold)),
      content: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('نوع سند الملكية (إلزامي)',
            style: TextStyle(
                color: AppTheme.primaryGold, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        DropdownButtonFormField<int>(
          initialValue: _selectedDocType,
          dropdownColor: AppTheme.surfaceBlack,
          style: const TextStyle(color: AppTheme.textWhite),
          decoration: const InputDecoration(border: OutlineInputBorder()),
          hint: const Text('اختر نوع السند',
              style: TextStyle(color: AppTheme.textGrey)),
          items: docTypes.entries
              .map((e) => DropdownMenuItem(
                    value: int.tryParse(e.key) ?? 0,
                    child: Text(e.value.toString()),
                  ))
              .toList(),
          onChanged: (v) => setState(() => _selectedDocType = v),
        ),
        const SizedBox(height: 14),
        const Text('صورة سند الملكية (اختيارية)',
            style: TextStyle(
                color: AppTheme.primaryGold, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: _pickDocImage,
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              color: AppTheme.surfaceBlack,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _docImage != null
                    ? Colors.green.withValues(alpha: 0.4)
                    : AppTheme.primaryGold.withValues(alpha: 0.3),
              ),
            ),
            child: _docImage == null
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.upload_file,
                            color: AppTheme.primaryGold, size: 32),
                        SizedBox(height: 4),
                        Text('اضغط لرفع صورة السند',
                            style: TextStyle(
                                color: AppTheme.textGrey, fontSize: 12)),
                      ],
                    ),
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: kIsWeb
                        ? Image.network(_docImage!.path,
                            fit: BoxFit.cover, width: double.infinity)
                        : Image.file(File(_docImage!.path),
                            fit: BoxFit.cover, width: double.infinity),
                  ),
          ),
        ),
        const SizedBox(height: 20),
        // تنويه داخلي
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
          ),
          child: Row(children: [
            const Icon(Icons.info_outline, color: Colors.amber, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'تنويه داخلي: هذا العرض أُضيف من قِبل ${context.read<AuthProvider>().userModel?.nm ?? "الإدارة"}',
                style: const TextStyle(color: Colors.amber, fontSize: 12),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _submitting ? null : _submit,
            child: const Text('إرسال العرض للمراجعة',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ]),
      isActive: _currentStep >= 5,
    );
  }

  // ── مساعدات ──

  Widget _timeField({required String value, required String hint, required void Function(String) onChanged}) {
    final ctrl = TextEditingController(text: value)
      ..selection = TextSelection.collapsed(offset: value.length);
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.datetime,
      textAlign: TextAlign.center,
      style: const TextStyle(color: AppTheme.textWhite, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppTheme.textGrey, fontSize: 13),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
      ),
      onChanged: onChanged,
    );
  }

  Future<void> _pickImages() async {
    final remaining = StorageService.maxImages - _pickedImages.length;
    if (remaining <= 0) { _snack('الحد الأقصى ${StorageService.maxImages} صور'); return; }
    final files = await _storage.pickMultiImages(limit: remaining);
    if (files.isNotEmpty) setState(() => _pickedImages.addAll(files));
  }

  Future<void> _pickDocImage() async {
    final file = await _storage.pickImage(fromCamera: false);
    if (file != null) setState(() => _docImage = file);
  }

  Widget _thumb(XFile file) {
    final err = Container(
        width: 70, height: 70, color: AppTheme.surfaceBlack,
        child: const Icon(Icons.image, color: AppTheme.primaryGold));
    if (kIsWeb) {
      return Image.network(file.path,
          width: 70, height: 70, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => err);
    }
    return Image.file(File(file.path),
        width: 70, height: 70, fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => err);
  }

  String _catLabel() {
    if (_selectedMainCat == null) return 'عرض';
    final config = context.read<ConfigProvider>().config;
    final source = _selectedType == 1
        ? config?.vehicleCategories
        : config?.propertyCategories;
    if (source != null) {
      final main = source['$_selectedMainCat'];
      if (main is Map) {
        final subs = main['sub'] ?? main['children'];
        if (subs is List && _selectedSubCat != null &&
            _selectedSubCat! >= 0 && _selectedSubCat! < subs.length) {
          return subs[_selectedSubCat!].toString();
        }
        return main['nm']?.toString() ?? 'عرض';
      }
    }
    return _selectedType == 1 ? 'مركبة' : 'عقار';
  }

  Map<int, String> _categoryGroupMap() {
    final config = context.read<ConfigProvider>().config;
    final cats = _selectedType == 1 ? config?.vehicleCategories : config?.propertyCategories;
    if (cats != null && cats.isNotEmpty) {
      return (cats as Map).map((k, v) {
        final id = int.tryParse(k.toString()) ?? 0;
        final name = v is Map
            ? (v['nm']?.toString() ?? v.toString())
            : v.toString();
        return MapEntry(id, name);
      });
    }
    return {0: _selectedType == 1 ? 'مركبة' : 'عقار'};
  }

  Map<int, String> _subCategoryMap(int mainId) {
    final config = context.read<ConfigProvider>().config;
    final cats = _selectedType == 1 ? config?.vehicleCategories : config?.propertyCategories;
    final main = cats?['$mainId'];
    if (main is Map) {
      final subs = main['sub'] ?? main['children'];
      if (subs is List) {
        final result = <int, String>{};
        for (int i = 0; i < subs.length; i++) {
          result[i] = subs[i].toString();
        }
        return result;
      }
    }
    return {mainId: _categoryGroupMap()[mainId] ?? '—'};
  }

  List<String> _cityOptions() {
    final config = context.read<ConfigProvider>().config;
    return (config?.locations ?? [])
        .map((item) {
          if (item is String) return item.trim();
          if (item is Map) return (item['name'] ?? item['d'] ?? '').toString().trim();
          return item.toString().trim();
        })
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

  Widget _buildLocationAutocomplete() {
    final locs = _cityOptions();
    return Autocomplete<String>(
      initialValue: TextEditingValue(text: _locCtrl.text),
      optionsBuilder: (v) {
        if (locs.isEmpty) return const Iterable<String>.empty();
        if (v.text.isEmpty) return locs.take(20);
        return locs.where((s) => s.toLowerCase().contains(v.text.toLowerCase()));
      },
      fieldViewBuilder: (ctx, ctrl, fn, _) {
        ctrl.text = _locCtrl.text;
        return TextField(
          controller: ctrl,
          focusNode: fn,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'وصف دقيق للموقع (إلزامي)',
            hintText: 'الحي، الشارع، المبنى...',
            border: OutlineInputBorder(),
          ),
          onChanged: (v) => _locCtrl.text = v,
        );
      },
      onSelected: (s) => setState(() => _locCtrl.text = s),
    );
  }

  Widget _dd(String label, List<String> items, Function(String) on) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: AppTheme.textGrey)),
        const SizedBox(height: 5),
        DropdownButtonFormField<String>(
          initialValue: null,
          items: items
              .map((i) => DropdownMenuItem(value: i, child: Text(i)))
              .toList(),
          onChanged: (v) => on(v!),
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
      ]);
}
