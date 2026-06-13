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
  int? _selectedSubCat; // التصنيف الفرعي (index داخل sub array للمجموعة الرئيسية)
  String? _selectedCityArea; // تُقرأ من config.locations مع دعم إدخال حر
  int _cur = Currency.lbp;
  final _priceCtrl = TextEditingController();
  final _locCtrl = TextEditingController();   // الوصف الدقيق للموقع (step1)
  final _descCtrl = TextEditingController();  // الوصف التفصيلي للعرض (step2)
  final _specCtrl = TextEditingController();  // المواصفات (step2)
  final _ttlCtrl  = TextEditingController();  // عنوان حر اختياري (step1)
  final _customSubCtrl = TextEditingController(); // للتصنيف الفرعي الحر (غير موجود في القائمة)
  final _contactPhoneCtrl = TextEditingController(); // رقم التواصل مع العارض (إلزامي في الأساسيات)
  final _customCityCtrl = TextEditingController(); // حقل حر للمنطقة الرئيسية (آخر)

  final List<XFile> _pickedImages = [];
  XFile? _docImage; // صورة سند الملكية
  LatLng? _pickedLocation; // الموقع الدقيق على الخريطة (اختياري)
  int? _selectedDocType; // نوع السند من config.docTp
  bool _agreePledge = false; // الإقرار والتعهد
  bool _shareOnSocial = true; // نشر على وسائل التواصل الاجتماعي للمكتب
  bool _submitting = false;

  // حقول السيارة
  final _carBrandCtrl = TextEditingController();
  final _carModelCtrl = TextEditingController();
  final _carYearCtrl = TextEditingController();
  final _carColorCtrl = TextEditingController();
  final _carKmCtrl = TextEditingController();
  String? _carFuel;
  String? _carTransmission;
  int? _selectedCarDocType;  // نوع سند ملكية السيارة
  int? _selectedPlateType;   // نوع النمرة
  String _progressMsg = '';

  // المواعيد المتاحة — avl
  // البنية: {"mon": ["09:00-12:00", "15:00-17:00"], "wed": ["10:00-13:00"]}
  static const _weekDays = [
    ('mon', 'الاثنين'),
    ('tue', 'الثلاثاء'),
    ('wed', 'الأربعاء'),
    ('thu', 'الخميس'),
    ('fri', 'الجمعة'),
    ('sat', 'السبت'),
    ('sun', 'الأحد'),
  ];
  // أيام مفعّلة
  final Map<String, bool> _avlDaysEnabled = {
    'mon': false, 'tue': false, 'wed': false, 'thu': false,
    'fri': false, 'sat': false, 'sun': false,
  };
  // فترات لكل يوم: [{"from": "09:00", "to": "12:00"}, ...]
  final Map<String, List<Map<String, String>>> _avlSlots = {
    'mon': [], 'tue': [], 'wed': [], 'thu': [],
    'fri': [], 'sat': [], 'sun': [],
  };

  /// يبني Map<String, List<String>> لإرساله في avl
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
    super.dispose();
  }

  void _next() => setState(() {
        if (_currentStep < 4) _currentStep++;
      });
  void _prev() => setState(() {
        if (_currentStep > 0) _currentStep--;
      });

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
    } catch (e) {return null;
    }
  }

  void _showPledgeDialog() {
    final config = context.read<ConfigProvider>().config;
    // النص الافتراضي باسم المكتب العقاري الالكتروني (يُستبدل بالنص من config إذا وُجد)
    const _defaultPledge =
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
    final pledgeText = rawText.length > 50 ? rawText : _defaultPledge;

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
    // فحص الحقول الإلزامية المشتركة
    if (_selectedType == null || _selectedTrans == null || _selectedMainCat == null ||
        (_selectedSubCat == null && _customSubCtrl.text.trim().isEmpty) ||
        (_selectedSubCat == -1 && _customSubCtrl.text.trim().isEmpty) ||
        _selectedDocType == null) {
      _snack('يرجى إكمال البيانات الأساسية (التصنيف الرئيسي + فرعي + نوع السند)');
      return;
    }
    // فحص حقول العقار
    if (_selectedType == 0) {
      if (_selectedCityArea == null ||
          (_selectedCityArea == _customCityOption && _customCityCtrl.text.trim().isEmpty) ||
          _locCtrl.text.trim().isEmpty) {
        _snack('يرجى اختيار المنطقة الرئيسية وكتابة وصف دقيق للموقع');
        return;
      }
    }
    // فحص حقول السيارة
    if (_selectedType == 1) {
      if (_carBrandCtrl.text.trim().isEmpty || _carModelCtrl.text.trim().isEmpty || _carYearCtrl.text.trim().isEmpty) {
        _snack('يرجى إدخال الماركة والموديل وسنة الصنع');
        return;
      }
    }
    final effectiveContactPhone = _contactPhoneCtrl.text.trim().isNotEmpty
        ? _contactPhoneCtrl.text.trim()
        : (user.ph.trim());
    if (effectiveContactPhone.isEmpty) {
      _snack('رقم الهاتف للتواصل إلزامي لإرسال العرض');
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

    // 1) فحص الحصة/الباقة
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

    // 2) رفع الصور (مع ضغط)
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

    // 2.5) الفيديو لن يُرفع للسيرفر حالياً. يتم مشاركة رابط واتساب لاحقاً.
    const String videoUrl = '';

    // 3) رفع صورة سند الملكية
    setState(() => _progressMsg = 'جارٍ رفع سند الملكية...');
    final docUrl = await _uploadDocImage(user.uid) ?? '';

    // 4) إنشاء العرض
    setState(() => _progressMsg = 'جارٍ إنشاء العرض...');
    String cityName;
    if (_selectedCityArea == _customCityOption) {
      cityName = _customCityCtrl.text.trim();
    } else {
      cityName = _selectedCityArea?.trim() ?? '';
    }
    final loc = {'r': 0, 'd': _locCtrl.text, 'city': cityName};

    final customSub = _customSubCtrl.text.trim();
    final catForTitle = customSub.isNotEmpty
        ? customSub
        : (_selectedSubCat != null ? _catLabel() : 'عرض');

    // العنوان: يُستخدم ما كتبه المستخدم إن وُجد، وإلا يُبنى آلياً
    final autoTitle = '$catForTitle في $cityName';
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
      // الوصف التفصيلي: ما كتبه المستخدم في حقل الوصف (step2)
      // يختلف عن الوصف الدقيق للموقع (_locCtrl) الذي يُحفظ في loc['d']
      descript: _descCtrl.text.trim().isNotEmpty
          ? _descCtrl.text.trim()
          : _locCtrl.text.trim(),
      specs: {
        'details': _specCtrl.text,
        if (customSub.isNotEmpty) 'custom_sub': customSub,
        // حقول السيارة
        if (_selectedType == 1) ...{
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
      vdo: videoUrl,
      exactLoc: _pickedLocation != null
          ? '${_pickedLocation!.latitude},${_pickedLocation!.longitude}'
          : '',
      docTp: _selectedDocType ?? 0,
      docImg: docUrl,
      // avl: المواعيد المتاحة التي أدخلها صاحب العرض
      avl: _buildAvl(),
      // brk_id: إذا كان صاحب الحساب وسيطاً يُحفظ uid تلقائياً
      brkId: user.role == UserRole.broker ? user.uid : '',
      sts: OfferStatus.review,
      iPub: 0,
      iSoc: _shareOnSocial ? 1 : 0,
      tsCrt: DateTime.now(),
    );

    OfferModel? createdOffer;
    try {
      createdOffer = await offerProv.addOffer(offer);

      if (createdOffer != null) {
        // 4) منح نقاط إضافة عرض (pts.addO)
        await _biz.awardEvent(user.uid, configProv.config, 'addO', fallback: 500);
        await auth.refreshUser();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _snack('فشل في النشر بعد تحميل الصور: $e');
      return;
    }

    if (!mounted) return;
    setState(() => _submitting = false);

    if (createdOffer != null) {
      if (_shareOnSocial) {
        await _triggerWhatsAppVideoShare(createdOffer, user);
      }
      if (!mounted) return;
      Navigator.pop(context);
      _snack('تم إرسال عرضك للمراجعة بنجاح ✅ (+نقاط)');
    } else {
      _snack('فشل إنشاء العرض، حاول مجدداً');
    }
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
              Navigator.pop(context); // close add offer
              // open packages
              Future.microtask(() {
                // ignore: use_build_context_synchronously
                final ctx = context;
                if (ctx.mounted) {
                  // ignore: use_build_context_synchronously
                  Navigator.of(ctx).pushNamed('/user/packages');
                }
              });
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
              // شريط معلومات الحصة
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                color: AppTheme.surfaceBlack,
                child: Text(
                  isInternalAccount
                      ? 'حساب إداري — إضافة العروض غير محدودة'
                      : () {
                          final u = user;
                          String pkgLabel;
                          if (u == null || u.bPkg == 0) {
                            pkgLabel = '(باقة مجانية)';
                          } else if (u.isPkgActive) {
                            pkgLabel = '(باقة مدفوعة)';
                          } else if (u.isInGracePeriod) {
                            pkgLabel = '(فترة السماح — ${u.graceDaysLeft} يوم متبقي)';
                          } else {
                            pkgLabel = '(باقة منتهية)';
                          }
                          return 'حصّتك: حتى $limit عرض فعّال $pkgLabel';
                        }(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.textGrey, fontSize: 12),
                ),
              ),
              Expanded(
                child: Stepper(
                  type: StepperType.vertical,
                  currentStep: _currentStep,
                  onStepTapped: (s) => setState(() => _currentStep = s),
                  // إزالة أزرار "Continue/Cancel" المزعجة (التنقل عبر النقر على عناوين الخطوات كافٍ)
                  controlsBuilder: (context, details) => const SizedBox.shrink(),
                  steps: [_step1(), _step2(), _step3(), _stepAvl(), _step4()],
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

    final mainCatItems = mainCategories.entries
        .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
        .toList();
    final subCatItems = subCategories.entries
        .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
        .toList();

    // إضافة خيار "آخر" داخل قائمة التصنيفات الفرعية
    final allSubItems = List<DropdownMenuItem<int>>.from(subCatItems);
    allSubItems.add(
      const DropdownMenuItem<int>(
        value: -1,
        child: Text('آخر (إدخال يدوي)'),
      ),
    );

    // قائمة المناطق تُقرأ من config.locations مع دعم إدخال حر
    final cityItems = _cityOptions()
        .map((city) => DropdownMenuItem<String>(
              value: city,
              child: Text(city, overflow: TextOverflow.ellipsis),
            ))
        .toList();
    cityItems.add(
      const DropdownMenuItem<String>(
        value: _customCityOption,
        child: Text('آخر (إدخال حر)'),
      ),
    );

    return Step(
      title: const Text('الأساسيات',
          style: TextStyle(
              color: AppTheme.primaryGold, fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          _dd('نوع العرض', ['عقار', 'سيارة'], (v) => setState(() {
            _selectedType = v == 'عقار' ? 0 : 1;
            _selectedMainCat = null;
            _selectedSubCat = null;
            _selectedCityArea = null;
            _customSubCtrl.clear();
            _customCityCtrl.clear();
          })),
          const SizedBox(height: 20),
          _dd('نوع المعاملة', ['بيع', 'إيجار'],
              (v) => setState(() => _selectedTrans = v == 'بيع' ? 0 : 1)),
          const SizedBox(height: 20),
          DropdownButtonFormField<int>(
            initialValue: _selectedMainCat,
            dropdownColor: AppTheme.surfaceBlack,
            style: const TextStyle(color: AppTheme.textWhite),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'التصنيف الرئيسي',
            ),
            items: mainCatItems,
            onChanged: (v) => setState(() {
              _selectedMainCat = v;
              _selectedSubCat = null;
              _customSubCtrl.clear();
              if (v != null) {
                final subs = _subCategoryMap(v);
                if (subs.length == 1) {
                  _selectedSubCat = subs.keys.first;
                }
              }
            }),
            hint: const Text('اختر التصنيف الرئيسي',
                style: TextStyle(color: AppTheme.textGrey)),
          ),
          const SizedBox(height: 20),
          if (_selectedMainCat != null)
            DropdownButtonFormField<int>(
              initialValue: _selectedSubCat,
              dropdownColor: AppTheme.surfaceBlack,
              style: const TextStyle(color: AppTheme.textWhite, fontSize: 14),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'التصنيف الفرعي',
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                isDense: true,
              ),
              items: allSubItems,
              onChanged: (v) => setState(() {
                _selectedSubCat = v;
                if (v != -1) _customSubCtrl.clear();
              }),
              hint: const Text('اختر التصنيف الفرعي',
                  style: TextStyle(color: AppTheme.textGrey, fontSize: 14)),
              menuMaxHeight: 300,
            ),
          if (_selectedSubCat == -1)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: TextField(
                controller: _customSubCtrl,
                decoration: const InputDecoration(
                  labelText: 'اكتب التصنيف الفرعي يدوياً',
                  hintText: 'مثال: فيلا فاخرة أو سيارة كهربائية مخصصة',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          const SizedBox(height: 20),
          // رقم الهاتف الآن في الأساسيات + إلزامي + نص واضح
          TextField(
            controller: _contactPhoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'رقم الهاتف للتواصل (إلزامي)',
              hintText: 'مثال: 0938862469 أو +963938862469',
              filled: true,
              fillColor: AppTheme.surfaceBlack,
            ),
          ),
          const SizedBox(height: 20),
          // ─── حقول العقار (المنطقة + الموقع) ───
          if (_selectedType == 0 || _selectedType == null) ...[
            // المنطقة الرئيسية + حقل حر
            DropdownButtonFormField<String>(
              initialValue: _selectedCityArea,
              dropdownColor: AppTheme.surfaceBlack,
              style: const TextStyle(color: AppTheme.textWhite),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'المنطقة الرئيسية',
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: cityItems,
              onChanged: (v) => setState(() {
                _selectedCityArea = v;
                if (v != _customCityOption) _customCityCtrl.clear();
              }),
              hint: const Text('اختر المنطقة الرئيسية أو آخر للإدخال الحر',
                  style: TextStyle(color: AppTheme.textGrey, fontSize: 14)),
              menuMaxHeight: 320,
            ),
            if (_selectedCityArea == _customCityOption)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: TextField(
                  controller: _customCityCtrl,
                  decoration: const InputDecoration(
                    labelText: 'اكتب المنطقة الرئيسية يدوياً',
                    hintText: 'اكتب اسم المنطقة أو الحي',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            const SizedBox(height: 20),
            // الوصف الدقيق للموقع (إلزامي) — يُحفظ في loc['d'] وليس في descript
            _buildLocationAutocomplete(),
          ],

          // ─── حقول السيارة ───
          if (_selectedType == 1) ...[
            TextField(
              controller: _carBrandCtrl,
              decoration: const InputDecoration(labelText: 'الماركة *', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _carModelCtrl,
              decoration: const InputDecoration(labelText: 'الموديل *', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _carYearCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'سنة الصنع *', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _carColorCtrl,
              decoration: const InputDecoration(labelText: 'اللون', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _carKmCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'عدد الكيلومترات', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            _dd('نوع الوقود', ['بنزين', 'ديزل', 'هجين', 'كهربائي', 'غاز'],
                (v) => setState(() => _carFuel = v)),
            const SizedBox(height: 12),
            _dd('ناقل الحركة', ['عادي', 'أوتوماتيك'],
                (v) => setState(() => _carTransmission = v)),
          ],
          const SizedBox(height: 8),
          if (_selectedTrans != null)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.surfaceBlack,
                border: Border.all(color: AppTheme.primaryGold.withOpacity(0.4)),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                _selectedTrans == 0
                    ? 'المكتب يتقاضى عمولة 3% عند إتمام عملية البيع.'
                    : 'المكتب يتقاضى أجرة نصف شهر عند إتمام عملية الإيجار أو الاستئجار.',
                style: const TextStyle(color: AppTheme.textWhite, fontSize: 14),
              ),
            ),
        ]),
      ),
      isActive: _currentStep >= 0,
    );
  }

  Step _step2() => Step(
        title: const Text('التفاصيل',
            style: TextStyle(
                color: AppTheme.primaryGold, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(children: [
            // عنوان حر (اختياري — يُكمّل العنوان الآلي إذا تُرك فارغاً)
            TextField(
              controller: _ttlCtrl,
              maxLength: 80,
              decoration: InputDecoration(
                labelText: 'عنوان مخصص (اختياري)',
                hintText: _selectedSubCat != null
                    ? 'مثال: ${_catLabel()} فاخرة مع حديقة — إذا تُرك فارغاً يُبنى تلقائياً'
                    : 'مثال: شقة فاخرة مع حديقة — إذا تُرك فارغاً يُبنى تلقائياً',
                helperText: 'العنوان الآلي: ${_catLabel()} في ${_locCtrl.text.isNotEmpty ? _locCtrl.text : "الموقع"}',
                helperStyle: const TextStyle(color: AppTheme.primaryGold, fontSize: 11),
                border: const OutlineInputBorder(),
                counterStyle: const TextStyle(color: AppTheme.textGrey),
              ),
            ),
            const SizedBox(height: 15),
            Row(children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _priceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'السعر المتوقع (إلزامي)',
                    border: OutlineInputBorder(),
                  ),
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
            const SizedBox(height: 15),
            // الوصف التفصيلي للعرض (يختلف عن وصف الموقع الذي أُدخل في step1)
            TextField(
              controller: _descCtrl,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'وصف تفصيلي للعرض (اختياري)',
                hintText: 'اذكر مميزات العرض، حالته، الطابق، المساحة، أي تفاصيل مهمة...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
                controller: _specCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'المواصفات التقنية (اختيارية)',
                  hintText: 'مثال: 3 غرف، 2 حمام، مساحة 150م²',
                  border: OutlineInputBorder(),
                )),
            const SizedBox(height: 20),
            // الموقع الدقيق على الخريطة
            const Row(children: [
              Icon(Icons.map, color: AppTheme.primaryGold, size: 18),
              SizedBox(width: 6),
              Text('الموقع الدقيق على الخريطة (اختياري)',
                  style: TextStyle(
                      color: AppTheme.primaryGold,
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
            ]),
            const SizedBox(height: 4),
            const Text('اضغط على الخريطة لتحديد موقع العقار بدقة',
                style: TextStyle(color: AppTheme.textGrey, fontSize: 14)),
            const SizedBox(height: 8),
            LocationPicker(
              initial: _pickedLocation,
              onPicked: (loc) => setState(() => _pickedLocation = loc),
              height: 250,
            ),
            if (_pickedLocation != null) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color.fromRGBO(76, 175, 80, 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 14),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'تم تحديد الموقع: ${_pickedLocation!.latitude.toStringAsFixed(4)}, ${_pickedLocation!.longitude.toStringAsFixed(4)}',
                      style: const TextStyle(
                          color: Colors.green, fontSize: 14),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red, size: 16),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => setState(() => _pickedLocation = null),
                  ),
                ]),
              ),
            ],
          ]),
        ),
        isActive: _currentStep >= 1,
      );

  Step _step3() => Step(
        title: const Text('الصور والفيديو',
            style: TextStyle(
                color: AppTheme.primaryGold, fontWeight: FontWeight.bold)),
        content: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // الصور
          ElevatedButton.icon(
            onPressed: _pickImages,
            icon: const Icon(Icons.add_photo_alternate),
            label: Text('إضافة صور (${_pickedImages.length}/${StorageService.maxImages})'),
          ),
          const SizedBox(height: 10),
          if (_pickedImages.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _pickedImages.asMap().entries.map((e) {
                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: _thumb(e.value),
                    ),
                    Positioned(
                      top: -8,
                      left: -8,
                      child: IconButton(
                        icon: const Icon(Icons.cancel, color: AppTheme.errorRed),
                        onPressed: () =>
                            setState(() => _pickedImages.removeAt(e.key)),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          const SizedBox(height: 20),
          const Divider(color: AppTheme.textGrey),
          const SizedBox(height: 10),
          // الفيديو (اختياري)
          const Text('🎬 فيديو العرض (اختياري)',
              style: TextStyle(
                  color: AppTheme.primaryGold,
                  fontWeight: FontWeight.bold,
                  fontSize: 13)),
          const SizedBox(height: 4),
          const Text('لن يُرفع الفيديو للسيرفر حالياً. اضغط الزر لفتح واتساب ومشاركة الرابط لاحقاً.',
              style: TextStyle(color: AppTheme.textGrey, fontSize: 11)),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _openWhatsAppVideoGroup,
            icon: const Icon(Icons.message, color: AppTheme.primaryGold),
            label: const Text('مشاركة فيديو عبر واتساب',
                style: TextStyle(color: AppTheme.primaryGold)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppTheme.primaryGold),
            ),
          ),
        ]),
        isActive: _currentStep >= 2,
      );

  Step _stepAvl() {
    return Step(
      title: const Text('المواعيد المتاحة',
          style: TextStyle(color: AppTheme.primaryGold, fontWeight: FontWeight.bold)),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'حدد الأيام والفترات الزمنية التي يمكن فيها معاينة العرض.',
            style: TextStyle(color: AppTheme.textGrey, fontSize: 13),
          ),
          const SizedBox(height: 4),
          const Text(
            'مثال: الأربعاء من 10:00 إلى 13:00',
            style: TextStyle(color: AppTheme.primaryGold, fontSize: 12),
          ),
          const SizedBox(height: 16),
          ..._weekDays.map((day) {
            final key = day.$1;
            final label = day.$2;
            final enabled = _avlDaysEnabled[key] ?? false;
            final slots = _avlSlots[key] ?? [];

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceBlack,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: enabled
                      ? AppTheme.primaryGold.withValues(alpha: 0.5)
                      : AppTheme.textGrey.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // رأس اليوم
                  InkWell(
                    onTap: () => setState(() {
                      _avlDaysEnabled[key] = !enabled;
                      if (!enabled && slots.isEmpty) {
                        _avlSlots[key]!.add({'from': '', 'to': ''});
                      }
                    }),
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(
                        children: [
                          Icon(
                            enabled ? Icons.check_box : Icons.check_box_outline_blank,
                            color: enabled ? AppTheme.primaryGold : AppTheme.textGrey,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Text(label,
                              style: TextStyle(
                                color: enabled ? AppTheme.textWhite : AppTheme.textGrey,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              )),
                          const Spacer(),
                          if (enabled)
                            TextButton.icon(
                              onPressed: () => setState(() {
                                _avlSlots[key]!.add({'from': '', 'to': ''});
                              }),
                              icon: const Icon(Icons.add, size: 16, color: AppTheme.primaryGold),
                              label: const Text('فترة', style: TextStyle(color: AppTheme.primaryGold, fontSize: 12)),
                              style: TextButton.styleFrom(padding: EdgeInsets.zero),
                            ),
                        ],
                      ),
                    ),
                  ),
                  // الفترات
                  if (enabled)
                    ...slots.asMap().entries.map((entry) {
                      final i = entry.key;
                      final slot = entry.value;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        child: Row(
                          children: [
                            const Text('من', style: TextStyle(color: AppTheme.textGrey, fontSize: 13)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: _timeField(
                                value: slot['from'] ?? '',
                                hint: '09:00',
                                onChanged: (v) => setState(() => _avlSlots[key]![i]['from'] = v),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text('إلى', style: TextStyle(color: AppTheme.textGrey, fontSize: 13)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: _timeField(
                                value: slot['to'] ?? '',
                                hint: '12:00',
                                onChanged: (v) => setState(() => _avlSlots[key]![i]['to'] = v),
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.remove_circle, color: Colors.red, size: 20),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => setState(() {
                                _avlSlots[key]!.removeAt(i);
                                if (_avlSlots[key]!.isEmpty) {
                                  _avlDaysEnabled[key] = false;
                                }
                              }),
                            ),
                          ],
                        ),
                      );
                    }),
                  if (enabled) const SizedBox(height: 8),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primaryGold.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.primaryGold.withValues(alpha: 0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: AppTheme.primaryGold, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'المواعيد المتاحة اختيارية. إذا تركتها فارغة لن يتمكن أحد من حجز موعد على هذا العرض.',
                    style: TextStyle(color: AppTheme.textGrey, fontSize: 12, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      isActive: _currentStep >= 3,
    );
  }

  Widget _timeField({
    required String value,
    required String hint,
    required void Function(String) onChanged,
  }) {
    final ctrl = TextEditingController(text: value);
    ctrl.selection = TextSelection.collapsed(offset: ctrl.text.length);
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

  Step _step4() {
    final config = context.watch<ConfigProvider>().config;
    final docTypes = config?.documentTypes ?? {};
    // pledgeText غير مستخدم هنا — النص يُعرض في _showPledgeDialog فقط
    return Step(
      title: const Text('السند والإقرار',
          style: TextStyle(
              color: AppTheme.primaryGold, fontWeight: FontWeight.bold)),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── نوع السند — حسب نوع العرض ───
          if (_selectedType == 1) ...[
            // سيارة: سند ملكية السيارة
            const Text('نوع سند الملكية (إلزامي)',
                style: TextStyle(color: AppTheme.primaryGold, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            DropdownButtonFormField<int>(
              initialValue: _selectedCarDocType,
              dropdownColor: AppTheme.surfaceBlack,
              style: const TextStyle(color: AppTheme.textWhite),
              decoration: const InputDecoration(border: OutlineInputBorder()),
              hint: const Text('اختر نوع السند', style: TextStyle(color: AppTheme.textGrey)),
              items: (config?.carDocumentTypes ?? {}).entries
                  .map((e) => DropdownMenuItem(value: int.tryParse(e.key) ?? 0, child: Text(e.value.toString())))
                  .toList(),
              onChanged: (v) => setState(() { _selectedCarDocType = v; _selectedDocType = v; }),
            ),
            const SizedBox(height: 14),
            // نوع النمرة
            const Text('نوع النمرة (إلزامي)',
                style: TextStyle(color: AppTheme.primaryGold, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            DropdownButtonFormField<int>(
              initialValue: _selectedPlateType,
              dropdownColor: AppTheme.surfaceBlack,
              style: const TextStyle(color: AppTheme.textWhite),
              decoration: const InputDecoration(border: OutlineInputBorder()),
              hint: const Text('اختر نوع النمرة', style: TextStyle(color: AppTheme.textGrey)),
              items: (config?.plateTypes ?? {}).entries
                  .map((e) => DropdownMenuItem(value: int.tryParse(e.key) ?? 0, child: Text(e.value.toString())))
                  .toList(),
              onChanged: (v) => setState(() => _selectedPlateType = v),
            ),
          ] else ...[
            // عقار: سند ملكية العقار
            const Text('نوع سند الملكية (إلزامي)',
                style: TextStyle(color: AppTheme.primaryGold, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            DropdownButtonFormField<int>(
              initialValue: _selectedDocType,
              dropdownColor: AppTheme.surfaceBlack,
              style: const TextStyle(color: AppTheme.textWhite),
              decoration: const InputDecoration(border: OutlineInputBorder()),
              hint: const Text('اختر نوع السند', style: TextStyle(color: AppTheme.textGrey)),
              items: docTypes.entries
                  .map((e) => DropdownMenuItem(value: int.tryParse(e.key) ?? 0, child: Text(e.value.toString())))
                  .toList(),
              onChanged: (v) => setState(() => _selectedDocType = v),
            ),
          ],
          const SizedBox(height: 14),

          // صورة سند الملكية (اختيارية)
          const Text('صورة سند الملكية (اختيارية)',
              style: TextStyle(
                  color: AppTheme.primaryGold, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: _pickDocImage,
            child: Container(
              height: 140,
              decoration: BoxDecoration(
                color: AppTheme.surfaceBlack,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: _docImage != null
                        ? const Color.fromRGBO(76, 175, 80, 0.4)
                        : const Color.fromRGBO(212, 175, 55, 0.4)),
              ),
              child: _docImage == null
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.upload_file,
                              color: AppTheme.primaryGold, size: 36),
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
          const SizedBox(height: 6),
          const Text('رفع صورة السند اختياري عند النشر (سيتم طلبها لاحقاً عند حجز أي موعد). يُفضل اصطحاب سند الملكية الأصلي عند المعاينة لتعزيز ثقة المشتري/المستأجر.',
              style: TextStyle(color: AppTheme.textGrey, fontSize: 11)),
          const SizedBox(height: 16),

          // الإقرار والتعهد - زر يفتح dialog مع النص الكامل (كما طلبت) + checkbox دائماً ظاهر
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.surfaceBlack,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: _agreePledge
                      ? const Color.fromRGBO(76, 175, 80, 0.3)
                      : const Color.fromRGBO(212, 175, 55, 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                OutlinedButton.icon(
                  onPressed: _showPledgeDialog,
                  icon: const Icon(Icons.gavel, color: AppTheme.primaryGold),
                  label: const Text('عرض نص الإقرار والتعهد الكامل',
                      style: TextStyle(color: AppTheme.primaryGold, fontSize: 14)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.primaryGold),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'الموافقة على الإقرار والتعهد إلزامية للنشر.',
                  style: TextStyle(color: AppTheme.textGrey, fontSize: 14),
                ),
                const SizedBox(height: 8),
                // إصلاح تحذير ListTile: wrap بـ Material لتجنب الـ ink splash invisible
                Material(
                  color: Colors.transparent,
                  child: CheckboxListTile(
                    value: _agreePledge,
                    onChanged: (v) =>
                        setState(() => _agreePledge = v ?? false),
                    title: const Text('أوافق على الإقرار والتعهد',
                        style: TextStyle(
                            color: AppTheme.textWhite, fontSize: 14)),
                    activeColor: AppTheme.primaryGold,
                    checkColor: Colors.black,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    dense: true,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // خيار النشر على وسائل التواصل الاجتماعي
          Material(
            color: Colors.transparent,
            child: CheckboxListTile(
              value: _shareOnSocial,
              onChanged: (v) => setState(() => _shareOnSocial = v ?? true),
              title: const Text('أرغب بنشر العرض على وسائل التواصل الاجتماعي الخاصة بالمكتب',
                  style: TextStyle(color: AppTheme.textWhite, fontSize: 13)),
              subtitle: const Text('يساعد في زيادة فرص البيع/الإيجار',
                  style: TextStyle(color: AppTheme.textGrey, fontSize: 11)),
              activeColor: AppTheme.primaryGold,
              checkColor: Colors.black,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: const Text('نشر العرض الآن',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
      isActive: _currentStep >= 4,
    );
  }

  String _catLabel() {
    if (_selectedMainCat == null) return 'عرض';
    final config = context.read<ConfigProvider>().config;
    final source = _selectedType == 1
        ? config?.vehicleCategories
        : config?.propertyCategories;
    if (source != null && source.isNotEmpty) {
      final mainItem = source['${_selectedMainCat}'];
      if (mainItem is Map) {
        final subsList = mainItem['sub'] ?? mainItem['children'];
        if (subsList is List && _selectedSubCat != null && _selectedSubCat! >= 0 && _selectedSubCat! < subsList.length) {
          return subsList[_selectedSubCat!].toString();
        }
        return mainItem['nm']?.toString() ?? mainItem.toString();
      }
    }
    return _selectedType == 1 ? 'مركبة' : 'عقار';
  }

  Map<int, String> _mapFromDynamic(dynamic data) {
    final result = <int, String>{};
    if (data is Map) {
      data.forEach((key, value) {
        final id = int.tryParse(key.toString());
        if (id == null) return;
        if (value is String) {
          result[id] = value;
        } else if (value is Map) {
          result[id] = value['nm']?.toString() ??
              value['name']?.toString() ??
              value.toString();
        } else {
          result[id] = value.toString();
        }
      });
    } else if (data is List) {
      // دعم مصفوفات التصنيفات الفرعية في config (sub: ["اسم1", "اسم2", ...])
      // نستخدم الـ index كـ id للحقل sub في offers (cat = main group id, sub = index داخل المجموعة)
      for (int i = 0; i < data.length; i++) {
        final value = data[i];
        if (value is String) {
          result[i] = value;
        } else if (value is Map) {
          result[i] = value['nm']?.toString() ??
              value['name']?.toString() ??
              value.toString();
        } else {
          result[i] = value.toString();
        }
      }
    }
    return result;
  }

  Map<int, String> _categoryGroupMap() {
    final config = context.read<ConfigProvider>().config;
    final categories = _selectedType == 1
        ? config?.vehicleCategories
        : config?.propertyCategories;
    if (categories != null && categories.isNotEmpty) {
      return _mapFromDynamic(categories);
    }
    return {0: _selectedType == 1 ? 'مركبة' : 'عقار'};
  }

  Map<int, String> _subCategoryMap(int mainId) {
    final config = context.read<ConfigProvider>().config;
    final categories = _selectedType == 1
        ? config?.vehicleCategories
        : config?.propertyCategories;
    final mainItem = categories?['$mainId'];
    if (mainItem is Map) {
      final subSource = mainItem['sub'] ?? mainItem['children'] ?? mainItem;
      final subMap = _mapFromDynamic(subSource);
      if (subMap.isNotEmpty) {
        return subMap;
      }
    }
    final label = _categoryGroupMap()[mainId] ?? 'غير معروف';
    return {mainId: label};
  }

  Widget _buildLocationAutocomplete() {
    final config = context.watch<ConfigProvider>().config;
    final locations = (config?.locations ?? [])
        .map((item) {
          if (item is String) return item.trim();
          if (item is Map) {
            return item['name']?.toString().trim() ??
                item['d']?.toString().trim() ??
                item.toString().trim();
          }
          return item.toString().trim();
        })
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    return Autocomplete<String>(
      initialValue: TextEditingValue(text: _locCtrl.text),
      optionsBuilder: (textEditingValue) {
        if (locations.isEmpty) return const Iterable<String>.empty();
        if (textEditingValue.text.isEmpty) return locations.take(20);
        final query = textEditingValue.text.toLowerCase();
        return locations.where(
          (option) => option.toLowerCase().contains(query),
        );
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        controller.text = _locCtrl.text;
        controller.selection = _locCtrl.selection;
        return TextField(
          controller: controller,
          focusNode: focusNode,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'وصف دقيق للموقع (إلزامي)',
            hintText: 'ابحث من المواقع الموجودة أو اكتب الموقع يدوياً',
          ),
          onChanged: (value) => _locCtrl.text = value,
        );
      },
      onSelected: (selection) {
        setState(() => _locCtrl.text = selection);
      },
    );
  }

  List<String> _cityOptions() {
    final config = context.read<ConfigProvider>().config;
    final options = (config?.locations ?? [])
        .map((item) {
          if (item is String) return item.trim();
          if (item is Map) {
            return item['name']?.toString().trim() ??
                item['d']?.toString().trim() ??
                item.toString().trim();
          }
          return item.toString().trim();
        })
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return options;
  }

  Future<void> _triggerWhatsAppVideoShare(OfferModel offer, dynamic user) async {
    final config = context.read<ConfigProvider>().config;
    final groupUrl = config?.texts['videoWhatsAppGroup']?.toString();
    final ownerName = (user?.nm ?? user?.uid ?? '');
    final message = 'عرض رقم ${offer.id} للمستخدم $ownerName';
    final uri = groupUrl != null && groupUrl.isNotEmpty
        ? Uri.parse(groupUrl)
        : Uri.parse('https://wa.me/?text=${Uri.encodeComponent(message)}');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Widget _thumb(XFile file) {
    final errBox = Container(
      width: 70,
      height: 70,
      color: AppTheme.surfaceBlack,
      child: const Icon(Icons.image, color: AppTheme.primaryGold),
    );
    if (kIsWeb) {
      return Image.network(file.path,
          width: 70,
          height: 70,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => errBox);
    }
    return Image.file(File(file.path),
        width: 70,
        height: 70,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => errBox);
  }

  Widget _dd(String label, List<String> items, Function(String) on) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppTheme.textGrey)),
        const SizedBox(height: 5),
        DropdownButtonFormField<String>(
            initialValue: null,
            items: items
                .map((i) => DropdownMenuItem(value: i, child: Text(i)))
                .toList(),
            onChanged: (v) => on(v!),
            decoration: const InputDecoration(border: OutlineInputBorder()))
      ]);
}

