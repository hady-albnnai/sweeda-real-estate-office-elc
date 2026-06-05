import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/offer_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/config_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/business_service.dart';
import '../../models/offer_model.dart';
import '../../services/storage_service.dart';

class AddOfferScreen extends StatefulWidget {
  const AddOfferScreen({super.key});
  @override
  State<AddOfferScreen> createState() => _AddOfferScreenState();
}

class _AddOfferScreenState extends State<AddOfferScreen> {
  int _currentStep = 0;
  int? _selectedType;
  int? _selectedTrans;
  String? _selectedCat;
  final _priceCtrl = TextEditingController();
  final _locCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _specCtrl = TextEditingController();

  final List<XFile> _pickedImages = [];
  bool _submitting = false;
  String _progressMsg = '';

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
    super.dispose();
  }

  void _next() => setState(() {
        if (_currentStep < 2) _currentStep++;
      });
  void _prev() => setState(() {
        if (_currentStep > 0) _currentStep--;
      });

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

  Future<void> _submit() async {
    final auth = context.read<AuthProvider>();
    final offerProv = context.read<OfferProvider>();
    final configProv = context.read<ConfigProvider>();
    final user = auth.userModel;

    if (user == null) {
      _snack('يجب تسجيل الدخول أولاً');
      return;
    }
    if (_selectedType == null || _priceCtrl.text.isEmpty) {
      _snack('يرجى إكمال البيانات الأساسية');
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
      config: configProv.config,
    );
    if (quota['allowed'] != true) {
      setState(() => _submitting = false);
      _snack(quota['reason'] as String);
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

    // 3) إنشاء العرض
    setState(() => _progressMsg = 'جارٍ إنشاء العرض...');
    final price = double.tryParse(_priceCtrl.text) ?? 0.0;
    final loc = {'r': 0, 'd': _locCtrl.text};

    final offer = OfferModel(
      id: '',
      usrId: user.uid,
      ttl: '${_selectedCat ?? 'عرض'} في ${_locCtrl.text}',
      typ: _selectedType!,
      trx: _selectedTrans ?? 0,
      cat: 0,
      prc: price,
      loc: loc,
      descript: _descCtrl.text,
      specs: {'details': _specCtrl.text},
      imgs: imageUrls,
      sts: 0,
      iPub: 0,
      tsCrt: DateTime.now(),
    );

    final ok = await offerProv.addOffer(offer);

    if (ok) {
      // 4) منح نقاط إضافة عرض (pts.addO)
      await _biz.awardEvent(user.uid, configProv.config, 'addO', fallback: 500);
      await auth.refreshUser();
    }

    if (!mounted) return;
    setState(() => _submitting = false);

    if (ok) {
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

  @override
  Widget build(BuildContext context) {
    final config = context.watch<ConfigProvider>().config;
    final user = context.watch<AuthProvider>().userModel;
    final limit = _biz.offerQuota(config,
        role: user?.role ?? 0, packageType: user?.bPkg ?? 0);

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
                  'حصّتك: حتى $limit عرض فعّال ${user?.bPkg != null && user!.bPkg > 0 ? '(باقة مدفوعة)' : '(باقة مجانية)'}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.textGrey, fontSize: 12),
                ),
              ),
              Expanded(
                child: Stepper(
                  type: StepperType.vertical,
                  currentStep: _currentStep,
                  onStepTapped: (s) => setState(() => _currentStep = s),
                  onStepContinue: _next,
                  onStepCancel: _prev,
                  steps: [_step1(), _step2(), _step3()],
                ),
              ),
            ],
          ),
          if (_submitting)
            Container(
              color: Colors.black.withOpacity(0.7),
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

  Step _step1() => Step(
        title: const Text('الأساسيات',
            style: TextStyle(
                color: AppTheme.primaryGold, fontWeight: FontWeight.bold)),
        content: Column(children: [
          _dd('نوع العرض', ['عقار', 'سيارة'],
              (v) => setState(() => _selectedType = v == 'عقار' ? 0 : 1)),
          const SizedBox(height: 20),
          _dd('نوع المعاملة', ['بيع', 'إيجار'],
              (v) => setState(() => _selectedTrans = v == 'بيع' ? 0 : 1)),
          const SizedBox(height: 20),
          _dd('التصنيف', ['شقة', 'فيلا', 'أرض', 'سيدان', 'SUV', 'دفع رباعي'],
              (v) => setState(() => _selectedCat = v)),
        ]),
        isActive: _currentStep >= 0,
      );

  Step _step2() => Step(
        title: const Text('التفاصيل',
            style: TextStyle(
                color: AppTheme.primaryGold, fontWeight: FontWeight.bold)),
        content: Column(children: [
          TextField(
              controller: _priceCtrl,
              keyboardType: TextInputType.number,
              decoration:
                  const InputDecoration(labelText: 'السعر المتوقع (ل.س)')),
          const SizedBox(height: 15),
          TextField(
              controller: _locCtrl,
              decoration: const InputDecoration(labelText: 'الموقع / المنطقة')),
          const SizedBox(height: 15),
          TextField(
              controller: _descCtrl,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'وصف مختصر')),
          const SizedBox(height: 15),
          TextField(
              controller: _specCtrl,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'المواصفات')),
        ]),
        isActive: _currentStep >= 1,
      );

  Step _step3() => Step(
        title: const Text('المرفقات',
            style: TextStyle(
                color: AppTheme.primaryGold, fontWeight: FontWeight.bold)),
        content: Column(children: [
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
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                child: const Text('نشر العرض الآن')),
          ),
        ]),
        isActive: _currentStep >= 2,
      );

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
            value: null,
            items: items
                .map((i) => DropdownMenuItem(value: i, child: Text(i)))
                .toList(),
            onChanged: (v) => on(v!),
            decoration: const InputDecoration(border: OutlineInputBorder()))
      ]);
}
