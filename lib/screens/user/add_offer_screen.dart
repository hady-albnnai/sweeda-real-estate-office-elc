import '../../models/user_model.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/offer_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/config_provider.dart';
import '../../core/constants/db_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/business_service.dart';
import '../../core/network/supabase_service.dart';
import '../../models/offer_model.dart';
import '../../services/storage_service.dart';
import '../../widgets/location_picker.dart';
import 'package:latlong2/latlong.dart';

class AddOfferScreen extends StatefulWidget {
  const AddOfferScreen({super.key});
  @override
  State<AddOfferScreen> createState() => _AddOfferScreenState();
}

class _AddOfferScreenState extends State<AddOfferScreen> {
  static const String _customCityOption = '__custom_city__';

  int _currentStep = 0;
  int? _selectedType;
  int? _selectedTrans;
  int? _selectedMainCat;
  int? _selectedSubCat; 
  String? _selectedCityArea; 
  int _cur = Currency.lbp;
  final _priceCtrl = TextEditingController();
  final _locCtrl = TextEditingController();   
  final _descCtrl = TextEditingController();  
  final _specCtrl = TextEditingController();  
  final _ttlCtrl  = TextEditingController();  
  final _customSubCtrl = TextEditingController(); 
  final _contactPhoneCtrl = TextEditingController(); 
  final _customCityCtrl = TextEditingController(); 

  final List<XFile> _pickedImages = [];
  XFile? _docImage; 
  LatLng? _pickedLocation; 
  int? _selectedDocType; 
  bool _agreePledge = false; 
  bool _shareOnSocial = true; 
  bool _submitting = false;
  bool _anytimeReady = false; 

  final _carBrandCtrl = TextEditingController();
  final _carModelCtrl = TextEditingController();
  final _carYearCtrl = TextEditingController();
  final _carColorCtrl = TextEditingController();
  final _carKmCtrl = TextEditingController();
  final _carPlateCtrl = TextEditingController(); 
  String? _carFuel;
  String? _carTransmission;
  String? _carGovernorate; 
  int? _selectedCarDocType;  
  int? _selectedPlateType;   

  final _areaCtrl = TextEditingController();    
  final _floorCtrl = TextEditingController();   
  final _legalNotesCtrl = TextEditingController(); 
  String? _finishing;   
  String? _direction;   
  String _progressMsg = '';

  static const _weekDays = [
    ('mon', 'الاثنين'),
    ('tue', 'الثلاثاء'),
    ('wed', 'الأربعاء'),
    ('thu', 'الخميس'),
    ('fri', 'الجمعة'),
    ('sat', 'السبت'),
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

  Map<String, List<String>> _buildAvl() {
    if (_anytimeReady) {
      return {'any': ['00:00-23:59']};
    }
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

  final _storage = StorageService();
  final _biz = BusinessService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ConfigProvider>().loadConfig();
    });
  }

  @override
  void dispose() {
    _priceCtrl.dispose();
    _locCtrl.dispose();
    _descCtrl.dispose();
    _specCtrl.dispose();
    _ttlCtrl.dispose();
    _customSubCtrl.dispose();
    _contactPhoneCtrl.dispose();
    _customCityCtrl.dispose();
    _carBrandCtrl.dispose();
    _carModelCtrl.dispose();
    _carYearCtrl.dispose();
    _carColorCtrl.dispose();
    _carKmCtrl.dispose();
    _carPlateCtrl.dispose();
    _areaCtrl.dispose();
    _floorCtrl.dispose();
    _legalNotesCtrl.dispose();
    super.dispose();
  }

  int get _totalSteps => _selectedType == 1 ? 4 : 5;

  Future<void> _pickDocImage() async {
    final file = await _storage.pickImage(fromCamera: false);
    if (file != null) setState(() => _docImage = file);
  }

  Future<String?> _uploadDocImage(String userId) async {
    if (_docImage == null) return null;
    try {
      final storage = SupabaseService().storage;
      final path = 'docs/$userId/doc_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final bytes = kIsWeb
          ? await _docImage!.readAsBytes()
          : await (await _storage.compressImage(File(_docImage!.path)) ??
                  File(_docImage!.path))
              .readAsBytes();
      await storage.from(StorageService.offerBucket).uploadBinary(
            path, bytes,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
          );
      return storage.from(StorageService.offerBucket).getPublicUrl(path);
    } catch (e) {
      print('UPLOAD DOC ERROR: $e');
      return null;
    }
  }

  void _showPledgeDialog() {
    final config = context.read<ConfigProvider>().config;
    const defaultPledge =
        'إقرار وتعهد إلكتروني — المكتب العقاري الالكتروني\n\n'
        'أقر أنا الموقع أدناه بموجب هذا الإقرار والتعهد بما يلي:\n'
        '1. أن جميع البيانات والصور والمعلومات المقدمة في هذا العرض صحيحة ودقيقة وغير مضللة.\n'
        '2. أنني المالك الشرعي للعقار/السيارة أو وكيل مفوض قانوناً عن المالك.\n'
        '3. أن أي سند ملكية مرفق (إن وجد) صحيح وصادر عن الجهة المختصة وغير مزوّر.\n'
        '4. أتعهد بإزالة هذا العرض فور بيع العقار/السيارة أو إلغاء الصفقة.\n'
        '5. أن تقديم أي بيانات كاذبة أو مضللة يعرضني للمسؤولية القانونية الكاملة،\n'
        '   بما في ذلك حظر الحساب وخصم النقاط.\n'
        '6. أن جميع المعلومات المقدمة تقع تحت مسؤوليتي الكاملة والحصرية.';

    final rawText = config?.texts['plg']?.toString() ?? '';
    final pledgeText = rawText.length > 50 ? rawText : defaultPledge;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surfaceBlack,
        title: const Row(children: [
          Icon(Icons.gavel, color: AppTheme.primaryGold),
          SizedBox(width: 8),
          Text('الإقرار والتعهد',
              style: TextStyle(color: AppTheme.textWhite)),
        ]),
        content: SingleChildScrollView(
          child: Text(
            pledgeText,
            style: const TextStyle(color: AppTheme.textGrey, fontSize: 14, height: 1.6),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق',
                style: TextStyle(color: AppTheme.primaryGold)),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImages() async {
    final remaining = StorageService.maxImages - _pickedImages.length;
    if (remaining <= 0) {
      _snack('الحد الأقصى ${StorageService.maxImages} صور');
      return;
    }
    final files = await _storage.pickMultiImages(limit: remaining);
    if (files.isNotEmpty) {
      setState(() => _pickedImages.addAll(files));
    }
  }

  Future<void> _openWhatsAppVideoGroup() async {
    final config = context.read<ConfigProvider>().config;
    final groupUrl = config?.texts['videoWhatsAppGroup']?.toString();
    final defaultMessage = Uri.encodeComponent(
        'مرحباً، أريد مشاركة فيديو لعرض جديد بعد إنشائه.');
    final uri = groupUrl != null && groupUrl.isNotEmpty
        ? Uri.parse(groupUrl)
        : Uri.parse('https://wa.me/?text=$defaultMessage');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _snack('لا يمكن فتح واتساب حالياً');
    }
  }

  Future<void> _submit() async {
    final auth = context.read<AuthProvider>();
    final offerProv = context.read<OfferProvider>();
    final configProv = context.read<ConfigProvider>();
    final user = auth.userModel;

    if (user == null) {
      _snack('يجب تسجيل الدخول أولاً');
      return;
    }
    if (_selectedType == null || _selectedTrans == null || _selectedMainCat == null ||
        (_selectedSubCat == null && _customSubCtrl.text.trim().isEmpty) ||
        (_selectedSubCat == -1 && _customSubCtrl.text.trim().isEmpty) ||
        _selectedDocType == null) {
      _snack('يرجى إكمال البيانات الأساسية (التصنيف الرئيسي + فرعي + نوع السند)');
      return;
    }
    if (_selectedType == 0) {
      if (_selectedCityArea == null ||
          (_selectedCityArea == _customCityOption && _customCityCtrl.text.trim().isEmpty) ||
          _locCtrl.text.trim().isEmpty) {
        _snack('يرجى اختيار المنطقة الرئيسية وكتابة وصف دقيق للموقع');
        return;
      }
    }
    if (_selectedType == 1) {
      if (_carPlateCtrl.text.trim().isEmpty) {
        _snack('يرجى إدخال لوحة السيارة');
        return;
      }
      if (_carBrandCtrl.text.trim().isEmpty || _carModelCtrl.text.trim().isEmpty || _carYearCtrl.text.trim().isEmpty) {
        _snack('يرجى إدخال الماركة والموديل وسنة الصنع');
        return;
      }
    }
    final effectiveContactPhone = _contactPhoneCtrl.text.trim().isNotEmpty
        ? _contactPhoneCtrl.text.trim()
        : (user.ph.trim());

    final phoneRegex = RegExp(r'^09[3-9]\d{7}$');
    if (!phoneRegex.hasMatch(effectiveContactPhone)) {
      _snack('يرجى إدخال رقم هاتف سوري صحيح (09xxxxxxxx)');
      return;
    }

    final price = double.tryParse(_priceCtrl.text) ?? 0.0;
    if (price <= 0) {
      _snack('يرجى إدخال سعر صالح');
      return;
    }
    if (!_agreePledge) {
      _snack('يجب الموافقة على الإقرار والتعهد قبل النشر');
      return;
    }

    setState(() {
      _submitting = true;
      _progressMsg = 'جارٍ التحقق من الحصة...';
    });

    final quota = await _biz.canPublishOffer(
      uid: user.uid,
      role: user.role,
      packageType: user.bPkg,
      pkgEnd:   user.pkgEnd,
      pkgGrace: user.pkgGrace,
      config:   configProv.config,
    );
    if (quota['allowed'] != true) {
      setState(() => _submitting = false);
      _showQuotaDialog(quota['reason'] as String);
      return;
    }

    List<String> imageUrls = [];
    if (_pickedImages.isNotEmpty) {
      setState(() => _progressMsg = 'جارٍ رفع الصور (0/${_pickedImages.length})...');
      imageUrls = await _storage.uploadOfferImages(
        files: _pickedImages,
        userId: user.uid,
        onProgress: (done, total) {
          if (mounted) {
            setState(() => _progressMsg = 'جارٍ رفع الصور ($done/$total)...');
          }
        },
      );
    }

    setState(() => _progressMsg = 'جارٍ رفع سند الملكية...');
    final docUrl = await _uploadDocImage(user.uid) ?? '';

    setState(() => _progressMsg = 'جارٍ إنشاء العرض...');
    String cityName;
    if (_selectedCityArea == _customCityOption) {
      cityName = _customCityCtrl.text.trim();
    } else {
      cityName = _selectedCityArea?.trim() ?? '';
    }
    final loc = _selectedType == 1
        ? {'r': 0, 'd': '', 'city': _carGovernorate ?? ''}
        : {'r': 0, 'd': _locCtrl.text, 'city': cityName};

    final customSub = _customSubCtrl.text.trim();
    final catForTitle = customSub.isNotEmpty
        ? customSub
        : (_selectedSubCat != null ? _catLabel() : 'عرض');

    String autoTitle;
    if (_selectedType == 1) {
      final brand = _carBrandCtrl.text.trim();
      final model = _carModelCtrl.text.trim();
      final year = _carYearCtrl.text.trim();
      autoTitle = '$brand $model $year'.trim();
      if (autoTitle.isEmpty) autoTitle = 'سيارة للبيع';
    } else {
      autoTitle = '$catForTitle في $cityName';
    }
    final finalTitle = _ttlCtrl.text.trim().isNotEmpty
        ? _ttlCtrl.text.trim()
        : autoTitle;

    final offer = OfferModel(
      id: '',
      usrId: user.uid,
      ttl: finalTitle,
      typ: _selectedType!,
      trx: _selectedTrans!,
      cat: _selectedMainCat!,
      sub: (_selectedSubCat == -1 || _selectedSubCat == null) ? 0 : _selectedSubCat!,
      contactPh: effectiveContactPhone,
      prc: price,
      cur: _cur,
      loc: loc,
      descript: _descCtrl.text.trim().isNotEmpty
          ? _descCtrl.text.trim()
          : _locCtrl.text.trim(),
      specs: {
        'details': _specCtrl.text,
        if (customSub.isNotEmpty) 'custom_sub': customSub,
        if (_selectedType == 0) ...{
          if (_areaCtrl.text.trim().isNotEmpty) 'area': _areaCtrl.text.trim(),
          if (_floorCtrl.text.trim().isNotEmpty) 'floor': _floorCtrl.text.trim(),
          if (_finishing != null) 'finishing': _finishing!,
          if (_direction != null) 'direction': _direction!,
          if (_legalNotesCtrl.text.trim().isNotEmpty) 'legal_notes': _legalNotesCtrl.text.trim(),
        },
        if (_selectedType == 1) ...{
          'plate': _carPlateCtrl.text.trim(),
          'governorate': _carGovernorate ?? '',
          'brand': _carBrandCtrl.text.trim(),
          'model': _carModelCtrl.text.trim(),
          'year': _carYearCtrl.text.trim(),
          'color': _carColorCtrl.text.trim(),
          'km': _carKmCtrl.text.trim(),
          'fuel': _carFuel ?? '',
          'transmission': _carTransmission ?? '',
          'plate_type': _selectedPlateType ?? 0,
        },
      },
      imgs: imageUrls,
      vdo: '',
      exactLoc: _pickedLocation != null
          ? '${_pickedLocation!.latitude},${_pickedLocation!.longitude}'
          : '',
      docTp: _selectedDocType ?? 0,
      docImg: docUrl,
      avl: _buildAvl(),
      brkId: user.role == UserRole.broker ? user.uid : '',
      sts: OfferStatus.review,
      iPub: 0,
      iSoc: _shareOnSocial ? 1 : 0,
      tsCrt: DateTime.now(),
    );

    try {
      await offerProv.addOffer(offer);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _snack('فشل في النشر: $e');
      return;
    }

    if (!mounted) return;
    setState(() => _submitting = false);
    Navigator.pop(context);
    _snack('تم إرسال العرض للمراجعة بنجاح ✅');
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  void _showQuotaDialog(String reason) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surfaceBlack,
        title: const Row(
          children: [
            Icon(Icons.workspace_premium, color: AppTheme.primaryGold),
            SizedBox(width: 8),
            Text('تجاوزت الحصة',
                style: TextStyle(color: AppTheme.textWhite)),
          ],
        ),
        content: Text(
          '$reason\n\nيمكنك ترقية باقتك للحصول على عدد أكبر من العروض الفعّالة.',
          style: const TextStyle(color: AppTheme.textGrey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('لاحقاً',
                style: TextStyle(color: AppTheme.textGrey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context); 
              Navigator.of(context).pushNamed('/user/packages');
            },
            child: const Text('ترقية الباقة'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = context.watch<ConfigProvider>().config;
    final user = context.watch<AuthProvider>().userModel;
    final isInternalAccount = (user?.role ?? 0) >= UserRole.minAdmin;
    final limit = _biz.offerQuota(config,
        role: user?.role ?? 0, packageType: user?.bPkg ?? 0,
        pkgEnd: user?.pkgEnd, pkgGrace: user?.pkgGrace);

    return Scaffold(
      appBar: AppBar(
          title: const Text('إضافة عرض جديد'),
          backgroundColor: Colors.transparent),
      body: Stack(
        children: [
          Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                color: AppTheme.surfaceBlack,
                child: Text(
                  isInternalAccount
                      ? 'حساب إداري — إضافة العروض غير محدودة'
                      : 'حصّتك: حتى $limit عرض فعّال',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.textGrey, fontSize: 12),
                ),
              ),
              Expanded(
                child: Stepper(
                  type: StepperType.vertical,
                  currentStep: _currentStep,
                  onStepTapped: (s) => setState(() => _currentStep = s),
                  controlsBuilder: (context, details) => const SizedBox.shrink(),
                  steps: [_step1(), _step2(), _step3(), if (_selectedType != 1) _stepAvl(), _step4()],
                ),
              ),
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

  Step _step1() {
    final mainCategories = _categoryGroupMap();
    final subCategories = _selectedMainCat != null
        ? _subCategoryMap(_selectedMainCat!)
        : <int, String>{};

    final cityItems = _cityOptions()
        .map((city) => DropdownMenuItem<String>(
              value: city,
              child: Text(city, overflow: TextOverflow.ellipsis),
            ))
        .toList();
    cityItems.add(const DropdownMenuItem<String>(value: _customCityOption, child: Text('آخر (إدخال حر)')));

    return Step(
      title: const Text('الأساسيات', style: TextStyle(color: AppTheme.primaryGold, fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          _dd('نوع العرض', ['عقار', 'سيارة'], (v) => setState(() {
            _selectedType = v == 'عقار' ? 0 : 1;
            _currentStep = 0;
            _selectedMainCat = null; _selectedSubCat = null; _selectedCityArea = null;
          })),
          const SizedBox(height: 20),
          _dd('نوع المعاملة', ['بيع', 'إيجار'], (v) => setState(() => _selectedTrans = v == 'بيع' ? 0 : 1)),
          const SizedBox(height: 20),
          DropdownButtonFormField<int>(
            value: _selectedMainCat,
            dropdownColor: AppTheme.surfaceBlack,
            style: const TextStyle(color: AppTheme.textWhite),
            decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'التصنيف الرئيسي'),
            items: mainCategories.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
            onChanged: (v) => setState(() {
              _selectedMainCat = v; _selectedSubCat = null;
            }),
            hint: const Text('اختر التصنيف الرئيسي', style: TextStyle(color: AppTheme.textGrey)),
          ),
          const SizedBox(height: 20),
          if (_selectedMainCat != null)
            DropdownButtonFormField<int>(
              value: _selectedSubCat,
              dropdownColor: AppTheme.surfaceBlack,
              style: const TextStyle(color: AppTheme.textWhite, fontSize: 14),
              decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'التصنيف الفرعي'),
              items: [
                ...subCategories.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))),
                const DropdownMenuItem<int>(value: -1, child: Text('آخر (إدخال يدوي)')),
              ],
              onChanged: (v) => setState(() => _selectedSubCat = v),
              hint: const Text('اختر التصنيف الفرعي', style: TextStyle(color: AppTheme.textGrey, fontSize: 14)),
            ),
          if (_selectedSubCat == -1)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: TextField(
                controller: _customSubCtrl,
                style: const TextStyle(color: AppTheme.textWhite),
                decoration: const InputDecoration(labelText: 'اكتب التصنيف الفرعي يدوياً', border: OutlineInputBorder()),
              ),
            ),
          const SizedBox(height: 20),
          TextField(
            controller: _contactPhoneCtrl,
            keyboardType: TextInputType.phone,
            style: const TextStyle(color: AppTheme.textWhite),
            decoration: const InputDecoration(
              labelText: 'رقم الهاتف للتواصل (إلزامي)',
              hintText: 'مثال: 0938862469',
              filled: true,
              fillColor: AppTheme.surfaceBlack,
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.phone, color: AppTheme.primaryGold),
            ),
          ),
          const SizedBox(height: 20),
          if (_selectedType == 0 || _selectedType == null) ...[
            DropdownButtonFormField<String>(
              value: _selectedCityArea,
              dropdownColor: AppTheme.surfaceBlack,
              style: const TextStyle(color: AppTheme.textWhite),
              decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'المنطقة الرئيسية'),
              items: cityItems,
              onChanged: (v) => setState(() => _selectedCityArea = v),
              hint: const Text('اختر المنطقة الرئيسية', style: TextStyle(color: AppTheme.textGrey, fontSize: 14)),
            ),
            if (_selectedCityArea == _customCityOption)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: TextField(
                  controller: _customCityCtrl,
                  decoration: const InputDecoration(labelText: 'اكتب المنطقة يدوياً', border: OutlineInputBorder()),
                ),
              ),
            const SizedBox(height: 20),
            TextField(controller: _locCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'وصف دقيق للموقع (إلزامي)', hintText: 'مثال: بجانب مدرسة الفارابي — شارع الجلاء — الطابق الثالث', border: OutlineInputBorder())),
          ],
          if (_selectedType == 1) ...[
            TextField(controller: _carPlateCtrl, decoration: const InputDecoration(labelText: 'لوحة السيارة (إلزامي)', border: OutlineInputBorder(), hintText: 'مثال: 123456')),
            const SizedBox(height: 12),
            _dd('المحافظة', ['السويداء', 'دمشق', 'ريف دمشق', 'حمص', 'حماة', 'حلب', 'اللاذقية', 'طرطوس', 'إدلب', 'دير الزور', 'الرقة', 'الحسكة', 'درعا', 'القنيطرة'], (v) => setState(() => _carGovernorate = v)),
            const SizedBox(height: 12),
            TextField(controller: _carBrandCtrl, decoration: const InputDecoration(labelText: 'الماركة (إلزامي)', border: OutlineInputBorder(), hintText: 'مثال: كيا، هيونداي...')),
            const SizedBox(height: 12),
            TextField(controller: _carModelCtrl, decoration: const InputDecoration(labelText: 'الموديل (إلزامي)', border: OutlineInputBorder(), hintText: 'مثال: سيراتو، أكسنت...')),
            const SizedBox(height: 12),
            TextField(controller: _carYearCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'سنة الصنع (إلزامي)', border: OutlineInputBorder(), hintText: 'مثال: 2020')),
            const SizedBox(height: 12),
            TextField(controller: _carColorCtrl, decoration: const InputDecoration(labelText: 'اللون (اختياري)', border: OutlineInputBorder(), hintText: 'مثال: أبيض، أسود...')),
            const SizedBox(height: 12),
            _dd('نوع الوقود (اختياري)', ['بنزين', 'ديزل', 'هجين', 'كهربائي', 'غاز'], (v) => setState(() => _carFuel = v)),
            const SizedBox(height: 12),
            _dd('ناقل الحركة (اختياري)', ['عادي', 'أوتوماتيك', 'نصف أوتوماتيك'], (v) => setState(() => _carTransmission = v)),
          ],
          const SizedBox(height: 8),
        ]),
      ),
      isActive: _currentStep >= 0,
    );
  }

  Step _step2() => Step(
        title: const Text('التفاصيل', style: TextStyle(color: AppTheme.primaryGold, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(children: [
            TextField(
              controller: _ttlCtrl,
              maxLength: 80,
              decoration: const InputDecoration(labelText: 'عنوان العرض بالتطبيق (اختياري)', hintText: 'مثال: شقة فاخرة مع حديقة', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 15),
            Row(children: [
              Expanded(flex: 3, child: TextField(controller: _priceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'السعر المتوقع (إلزامي)', border: OutlineInputBorder()))),
              const SizedBox(width: 10),
              Expanded(flex: 2, child: DropdownButtonFormField<int>(value: _cur, dropdownColor: AppTheme.surfaceBlack, style: const TextStyle(color: AppTheme.textWhite), decoration: const InputDecoration(border: OutlineInputBorder()), items: const [DropdownMenuItem(value: Currency.dollar, child: Text('دولار')), DropdownMenuItem(value: Currency.lbp, child: Text('ل.س'))], onChanged: (v) => setState(() => _cur = v ?? Currency.lbp))),
            ]),
            const SizedBox(height: 15),
            if (_selectedType == 0 || _selectedType == null) ...[
              TextField(controller: _areaCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'المساحة م² (اختياري)', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              _dd('الإكساء (اختياري)', ['ملكي', 'سوبر ديلوكس', 'ديلوكس', 'كسوة عادية', 'هيكل', 'آخر'], (v) => setState(() => _finishing = v)),
              const SizedBox(height: 12),
              TextField(controller: _floorCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'الطابق (اختياري)', hintText: 'مثال: 3', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              _dd('اتجاه العقار (اختياري)', ['شمالي', 'جنوبي', 'شرقي', 'غربي', 'شمالي شرقي', 'شمالي غربي', 'جنوبي شرقي', 'جنوبي غربي', 'مفتوح - أربع اتجاهات'], (v) => setState(() => _direction = v)),
              const SizedBox(height: 12),
              TextField(controller: _legalNotesCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'ملاحظات قانونية (اختياري)', hintText: 'مثال: طابو أخضر نظامي، أو حصة سهمية...', border: OutlineInputBorder())),
              const SizedBox(height: 15),
            ],
            TextField(controller: _descCtrl, maxLines: 4, decoration: const InputDecoration(labelText: 'وصف تفصيلي للعرض (اختياري)', hintText: 'اذكر مميزات العقار، حالته، أي تفاصيل مهمة...', border: OutlineInputBorder())),
            const SizedBox(height: 15),
            TextField(controller: _specCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'مواصفات إضافية (اختياري)', hintText: 'مثال: 3 غرف، 2 حمام، بلكون...', border: OutlineInputBorder())),
            const SizedBox(height: 20),
            if (_selectedType == 0 || _selectedType == null) ...[
              const Text('الموقع الدقيق على الخريطة (اختياري)', style: TextStyle(color: AppTheme.primaryGold, fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              LocationPicker(initial: _pickedLocation, onPicked: (loc) => setState(() => _pickedLocation = loc), height: 250),
            ],
          ]),
        ),
        isActive: _currentStep >= 1,
      );

  Step _step3() => Step(
        title: const Text('الصور والفيديو', style: TextStyle(color: AppTheme.primaryGold, fontWeight: FontWeight.bold)),
        content: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ElevatedButton.icon(onPressed: _pickImages, icon: const Icon(Icons.add_photo_alternate), label: Text('إضافة صور (${_pickedImages.length}/${StorageService.maxImages})')),
          const SizedBox(height: 10),
          if (_pickedImages.isNotEmpty)
            Wrap(
              spacing: 8, runSpacing: 8,
              children: _pickedImages.asMap().entries.map((e) {
                return Stack(children: [
                  ClipRRect(borderRadius: BorderRadius.circular(8), child: _thumb(e.value)),
                  Positioned(top: -8, left: -8, child: IconButton(icon: const Icon(Icons.cancel, color: AppTheme.errorRed), onPressed: () => setState(() => _pickedImages.removeAt(e.key)))),
                ]);
              }).toList(),
            ),
          const SizedBox(height: 20),
          OutlinedButton.icon(onPressed: _openWhatsAppVideoGroup, icon: const Icon(Icons.message, color: AppTheme.primaryGold), label: const Text('مشاركة فيديو عبر واتساب', style: TextStyle(color: AppTheme.primaryGold))),
        ]),
        isActive: _currentStep >= 2,
      );

  Step _stepAvl() {
    return Step(
      title: const Text('المواعيد المتاحة', style: TextStyle(color: AppTheme.primaryGold, fontWeight: FontWeight.bold)),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppTheme.primaryGold.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.primaryGold.withValues(alpha: 0.3))),
            child: SwitchListTile(
              value: _anytimeReady,
              onChanged: (v) => setState(() => _anytimeReady = v),
              title: const Text('أنا جاهز للمعاينة في أي وقت', style: TextStyle(color: AppTheme.textWhite, fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: const Text('سيتمكن الزبائن من طلب موعد في أي وقت تراه الإدارة مناسباً', style: TextStyle(color: AppTheme.textGrey, fontSize: 11)),
              activeColor: AppTheme.primaryGold,
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(height: 16),
          if (!_anytimeReady) ...[
            ..._weekDays.map((day) {
              final key = day.$1; final label = day.$2; final enabled = _avlDaysEnabled[key] ?? false; final slots = _avlSlots[key] ?? [];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(color: AppTheme.surfaceBlack, borderRadius: BorderRadius.circular(10), border: Border.all(color: enabled ? AppTheme.primaryGold.withValues(alpha: 0.5) : AppTheme.textGrey.withValues(alpha: 0.2))),
                child: Column(children: [
                  ListTile(
                    leading: Icon(enabled ? Icons.check_box : Icons.check_box_outline_blank, color: enabled ? AppTheme.primaryGold : AppTheme.textGrey),
                    title: Text(label, style: TextStyle(color: enabled ? AppTheme.textWhite : AppTheme.textGrey, fontWeight: FontWeight.bold)),
                    onTap: () => setState(() {
                      _avlDaysEnabled[key] = !enabled;
                      if (!enabled && slots.isEmpty) _avlSlots[key]!.add({'from': '', 'to': ''});
                    }),
                    trailing: enabled ? IconButton(icon: const Icon(Icons.add, color: AppTheme.primaryGold), onPressed: () => setState(() => _avlSlots[key]!.add({'from': '', 'to': ''}))) : null,
                  ),
                  if (enabled) ...slots.asMap().entries.map((entry) {
                    final i = entry.key; final slot = entry.value;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      child: Row(children: [
                        const Text('من', style: TextStyle(color: AppTheme.textGrey, fontSize: 12)),
                        const SizedBox(width: 4),
                        Expanded(child: _timeField(value: slot['from'] ?? '', hint: '09:00', onChanged: (v) => setState(() => _avlSlots[key]![i]['from'] = v))),
                        const SizedBox(width: 8),
                        const Text('إلى', style: TextStyle(color: AppTheme.textGrey, fontSize: 12)),
                        const SizedBox(width: 4),
                        Expanded(child: _timeField(value: slot['to'] ?? '', hint: '12:00', onChanged: (v) => setState(() => _avlSlots[key]![i]['to'] = v))),
                        IconButton(icon: const Icon(Icons.remove_circle, color: Colors.red, size: 20), onPressed: () => setState(() => _avlSlots[key]!.removeAt(i))),
                      ]),
                    );
                  }),
                ]),
              );
            }),
          ],
        ],
      ),
      isActive: _currentStep >= 3,
    );
  }

  Widget _timeField({required String value, required String hint, required void Function(String) onChanged}) {
    return TextField(
      controller: TextEditingController(text: value)..selection = TextSelection.collapsed(offset: value.length),
      keyboardType: TextInputType.datetime,
      style: const TextStyle(color: AppTheme.textWhite, fontSize: 14),
      decoration: InputDecoration(hintText: hint, contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), isDense: true, border: const OutlineInputBorder()),
      onChanged: onChanged,
    );
  }

  Step _step4() {
    final config = context.watch<ConfigProvider>().config;
    final Map<String, dynamic> rawDocTp = config?.data['docTp'] ?? {};
    final Map<String, dynamic> rawCarDocTp = config?.data['carDocTp'] ?? {};
    final Map<String, dynamic> rawPlateTp = config?.data['plateTp'] ?? {};

    return Step(
      title: const Text('السند والإقرار', style: TextStyle(color: AppTheme.primaryGold, fontWeight: FontWeight.bold)),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_selectedType == 1) ...[
            const Text('نوع سند ملكية السيارة (إلزامي)', style: TextStyle(color: AppTheme.primaryGold, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            DropdownButtonFormField<int>(
              value: _selectedCarDocType,
              dropdownColor: AppTheme.surfaceBlack,
              style: const TextStyle(color: AppTheme.textWhite),
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: rawCarDocTp.entries.map((e) => DropdownMenuItem(value: int.tryParse(e.key) ?? 0, child: Text(e.value.toString()))).toList(),
              onChanged: (v) => setState(() { _selectedCarDocType = v; _selectedDocType = v; }),
            ),
            const SizedBox(height: 14),
            const Text('نوع النمرة (إلزامي)', style: TextStyle(color: AppTheme.primaryGold, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            DropdownButtonFormField<int>(
              value: _selectedPlateType,
              dropdownColor: AppTheme.surfaceBlack,
              style: const TextStyle(color: AppTheme.textWhite),
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: rawPlateTp.entries.map((e) => DropdownMenuItem(value: int.tryParse(e.key) ?? 0, child: Text(e.value.toString()))).toList(),
              onChanged: (v) => setState(() => _selectedPlateType = v),
            ),
          ] else ...[
            const Text('نوع سند ملكية العقار (إلزامي)', style: TextStyle(color: AppTheme.primaryGold, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            DropdownButtonFormField<int>(
              value: _selectedDocType,
              dropdownColor: AppTheme.surfaceBlack,
              style: const TextStyle(color: AppTheme.textWhite),
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: rawDocTp.entries.map((e) => DropdownMenuItem(value: int.tryParse(e.key) ?? 0, child: Text(e.value.toString()))).toList(),
              onChanged: (v) => setState(() => _selectedDocType = v),
            ),
          ],
          const SizedBox(height: 14),
          const Text('صورة سند الملكية (اختيارية)', style: TextStyle(color: AppTheme.primaryGold, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: _pickDocImage,
            child: Container(
              height: 140,
              decoration: BoxDecoration(color: AppTheme.surfaceBlack, borderRadius: BorderRadius.circular(10), border: Border.all(color: _docImage != null ? Colors.green : AppTheme.primaryGold)),
              child: _docImage == null
                  ? const Center(child: Icon(Icons.upload_file, color: AppTheme.primaryGold, size: 36))
                  : ClipRRect(borderRadius: BorderRadius.circular(9), child: kIsWeb ? Image.network(_docImage!.path, fit: BoxFit.cover) : Image.file(File(_docImage!.path), fit: BoxFit.cover, cacheWidth: 800)),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppTheme.surfaceBlack, borderRadius: BorderRadius.circular(8), border: Border.all(color: _agreePledge ? Colors.green : AppTheme.primaryGold)),
            child: Column(children: [
              OutlinedButton.icon(onPressed: _showPledgeDialog, icon: const Icon(Icons.gavel, color: AppTheme.primaryGold), label: const Text('عرض الإقرار والتعهد الكامل', style: TextStyle(color: AppTheme.primaryGold))),
              Material(color: Colors.transparent, child: CheckboxListTile(value: _agreePledge, onChanged: (v) => setState(() => _agreePledge = v ?? false), title: const Text('أوافق على الإقرار والتعهد', style: TextStyle(color: AppTheme.textWhite, fontSize: 14)), activeColor: AppTheme.primaryGold)),
            ]),
          ),
          const SizedBox(height: 12),
          if (_selectedTrans != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryGold.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primaryGold.withValues(alpha: 0.5), width: 1.5),
              ),
              child: Row(
                children: [
                  const Icon(Icons.monetization_on, color: AppTheme.primaryGold, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('تنبيه بخصوص عمولة المكتب',
                            style: TextStyle(color: AppTheme.primaryGold, fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 4),
                        Text(
                          _selectedTrans == 0
                              ? 'يتقاضى المكتب عمولة قدرها 3% من القيمة الإجمالية عند إتمام عملية البيع.'
                              : 'يتقاضى المكتب عمولة تعادل أجرة نصف شهر عند إتمام عملية الإيجار.',
                          style: const TextStyle(color: AppTheme.textWhite, fontSize: 13, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          Material(color: Colors.transparent, child: CheckboxListTile(value: _shareOnSocial, onChanged: (v) => setState(() => _shareOnSocial = v ?? true), title: const Text('نشر على وسائل التواصل الاجتماعية للمكتب', style: TextStyle(color: AppTheme.textWhite, fontSize: 13)))),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, height: 52, child: ElevatedButton(onPressed: _submitting ? null : _submit, child: const Text('نشر العرض الآن'))),
        ],
      ),
      isActive: _currentStep >= _totalSteps - 1,
    );
  }

  String _catLabel() {
    final config = context.read<ConfigProvider>().config;
    final source = _selectedType == 1 ? config?.vehicleCategories : config?.propertyCategories;
    final mainItem = source?['$_selectedMainCat'];
    if (mainItem is Map) {
      final subs = mainItem['sub'] ?? mainItem['children'];
      if (subs is List && _selectedSubCat != null && _selectedSubCat! >= 0 && _selectedSubCat! < subs.length) return subs[_selectedSubCat!].toString();
      return mainItem['nm']?.toString() ?? 'عرض';
    }
    return 'عرض';
  }

  Map<int, String> _mapFromDynamic(dynamic data) {
    final result = <int, String>{};
    if (data is Map) { data.forEach((k, v) { final id = int.tryParse(k.toString()); if (id != null) result[id] = (v is Map ? v['nm'] : v).toString(); });
    } else if (data is List) { for (int i=0; i<data.length; i++) result[i] = data[i].toString(); }
    return result;
  }

  Map<int, String> _categoryGroupMap() {
    final config = context.read<ConfigProvider>().config;
    final categories = _selectedType == 1 ? config?.vehicleCategories : config?.propertyCategories;
    return categories != null ? _mapFromDynamic(categories) : {0: 'عرض'};
  }

  Map<int, String> _subCategoryMap(int mainId) {
    final config = context.read<ConfigProvider>().config;
    final categories = _selectedType == 1 ? config?.vehicleCategories : config?.propertyCategories;
    final mainItem = categories?['$mainId'];
    if (mainItem is Map) {
      final subSource = mainItem['sub'] ?? mainItem['children'] ?? mainItem;
      return _mapFromDynamic(subSource);
    }
    return {mainId: 'عرض'};
  }

  Widget _buildLocationAutocomplete() {
    return TextField(controller: _locCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'وصف دقيق للموقع (إلزامي)', border: OutlineInputBorder(), hintText: 'مثال: بجانب مدرسة الفارابي — شارع الجلاء — الطابق الثالث'));
  }

  List<String> _cityOptions() {
    final config = context.read<ConfigProvider>().config;
    return (config?.locations ?? []).map((e) => (e is Map ? e['name'] : e).toString()).toList();
  }

  Widget _thumb(XFile file) {
    return kIsWeb ? Image.network(file.path, width: 70, height: 70, fit: BoxFit.cover) : Image.file(File(file.path), width: 70, height: 70, fit: BoxFit.cover);
  }

  Widget _dd(String label, List<String> items, Function(String) on) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: AppTheme.textGrey)),
        const SizedBox(height: 5),
        DropdownButtonFormField<String>(items: items.map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(), onChanged: (v) => on(v!), decoration: const InputDecoration(border: OutlineInputBorder()))
      ]);
}
