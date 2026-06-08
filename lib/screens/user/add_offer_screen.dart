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
  int _currentStep = 0;
  int? _selectedType;
  int? _selectedTrans;
  int? _selectedMainCat;
  int? _selectedCat;
  int _cur = Currency.lbp;
  final _priceCtrl = TextEditingController();
  final _locCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _specCtrl = TextEditingController();

  final List<XFile> _pickedImages = [];
  XFile? _docImage; // صورة سند الملكية
  LatLng? _pickedLocation; // الموقع الدقيق على الخريطة (اختياري)
  int? _selectedDocType; // نوع السند من config.docTp
  bool _agreePledge = false; // الإقرار والتعهد
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
        if (_currentStep < 3) _currentStep++;
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
    final pledgeText = config?.texts['plg'] ??
        'إقرار وتعهد إلكتروني — عقارات السويداء\n\n'
            '• أُقرّ بأن البيانات والصور المُرفقة بهذا العرض صحيحة وحقيقية.\n'
            '• أتعهّد بأنني المالك الفعلي للعقار/السيارة أو وكيل قانوني عنه.\n'
            '• أُقرّ بأن سند الملكية المرفق صحيح وغير مزوّر.\n'
            '• أتعهّد بإزالة العرض فور بيعه أو إلغائه.\n'
            '• أُقرّ بأن أي بيانات كاذبة قد تؤدي لحظر حسابي وخصم نقاطي.';
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
          child: Text(pledgeText,
              style: const TextStyle(color: AppTheme.textGrey, fontSize: 13)),
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
    if (_selectedType == null || _selectedTrans == null || _selectedMainCat == null || _selectedCat == null) {
      _snack('يرجى إكمال البيانات الأساسية');
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
      config: configProv.config,
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
    final loc = {'r': 0, 'd': _locCtrl.text};

    final offer = OfferModel(
      id: '',
      usrId: user.uid,
      ttl: '${_selectedCat != null ? _catLabel() : 'عرض'} في ${_locCtrl.text}',
      typ: _selectedType!,
      trx: _selectedTrans!,
      cat: _selectedCat!,
      prc: price,
      cur: _cur,
      loc: loc,
      descript: _descCtrl.text,
      specs: {'details': _specCtrl.text},
      imgs: imageUrls,
      vdo: videoUrl,
      exactLoc: _pickedLocation != null
          ? '${_pickedLocation!.latitude},${_pickedLocation!.longitude}'
          : '',
      docTp: _selectedDocType ?? 0,
      docImg: docUrl,
      sts: 0,
      iPub: 0,
      tsCrt: DateTime.now(),
    );

    final createdOffer = await offerProv.addOffer(offer);

    if (createdOffer != null) {
      // 4) منح نقاط إضافة عرض (pts.addO)
      await _biz.awardEvent(user.uid, configProv.config, 'addO', fallback: 500);
      await auth.refreshUser();
    }

    if (!mounted) return;
    setState(() => _submitting = false);

    if (createdOffer != null) {
      await _triggerWhatsAppVideoShare(createdOffer, user);
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
                  steps: [_step1(), _step2(), _step3(), _step4()],
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

    return Step(
      title: const Text('الأساسيات',
          style: TextStyle(
              color: AppTheme.primaryGold, fontWeight: FontWeight.bold)),
      content: Column(children: [
        _dd('نوع العرض', ['عقار', 'سيارة'], (v) => setState(() {
          _selectedType = v == 'عقار' ? 0 : 1;
          _selectedMainCat = null;
          _selectedCat = null;
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
            _selectedCat = null;
            if (v != null) {
              final subs = _subCategoryMap(v);
              if (subs.length == 1) {
                _selectedCat = subs.keys.first;
              }
            }
          }),
          hint: const Text('اختر التصنيف الرئيسي',
              style: TextStyle(color: AppTheme.textGrey)),
        ),
        const SizedBox(height: 20),
        if (subCatItems.isNotEmpty)
          DropdownButtonFormField<int>(
            initialValue: _selectedCat,
            dropdownColor: AppTheme.surfaceBlack,
            style: const TextStyle(color: AppTheme.textWhite),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'التصنيف الفرعي',
            ),
            items: subCatItems,
            onChanged: (v) => setState(() => _selectedCat = v),
            hint: const Text('اختر التصنيف الفرعي',
                style: TextStyle(color: AppTheme.textGrey)),
          ),
      ]),
      isActive: _currentStep >= 0,
    );
  }

  Step _step2() => Step(
        title: const Text('التفاصيل',
            style: TextStyle(
                color: AppTheme.primaryGold, fontWeight: FontWeight.bold)),
        content: Column(children: [
          Row(children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: _priceCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'السعر المتوقع (${_cur == Currency.dollar ? '\$' : 'ل.س'})',
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
          _buildLocationAutocomplete(),
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
          const SizedBox(height: 20),
          // الموقع الدقيق على الخريطة
          const Row(children: [
            Icon(Icons.map, color: AppTheme.primaryGold, size: 18),
            SizedBox(width: 6),
            Text('الموقع الدقيق على الخريطة (اختياري)',
                style: TextStyle(
                    color: AppTheme.primaryGold,
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
          ]),
          const SizedBox(height: 4),
          const Text('اضغط على الخريطة لتحديد موقع العقار بدقة',
              style: TextStyle(color: AppTheme.textGrey, fontSize: 11)),
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
                        color: Colors.green, fontSize: 11),
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

  Step _step4() {
    final config = context.watch<ConfigProvider>().config;
    final docTypes = config?.documentTypes ?? {};
    return Step(
      title: const Text('السند والإقرار',
          style: TextStyle(
              color: AppTheme.primaryGold, fontWeight: FontWeight.bold)),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // نوع سند الملكية
          const Text('نوع سند الملكية (اختياري)',
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

          // صورة سند الملكية
          const Text('صورة سند الملكية (اختياري)',
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
          const Text('رفع سند الملكية اختياري عند النشر؛ يمكنك إضافته لاحقاً من صفحة العرض.',
              style: TextStyle(color: AppTheme.textGrey, fontSize: 11)),
          const SizedBox(height: 16),

          // الإقرار والتعهد
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
              children: [
                InkWell(
                  onTap: _showPledgeDialog,
                  child: const Row(
                    children: [
                      Icon(Icons.gavel,
                          color: AppTheme.primaryGold, size: 16),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text('اقرأ نص الإقرار والتعهد',
                            style: TextStyle(
                                color: AppTheme.textWhite, fontSize: 12)),
                      ),
                      Icon(Icons.arrow_forward_ios,
                          color: AppTheme.primaryGold, size: 10),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'يمكنك قراءة نص الإقرار الكامل قبل الموافقة. الموافقة مطلوبة للنشر.',
                  style: TextStyle(color: AppTheme.textGrey, fontSize: 11),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  value: _agreePledge,
                  onChanged: (v) =>
                      setState(() => _agreePledge = v ?? false),
                  title: const Text('أوافق على الإقرار والتعهد',
                      style: TextStyle(
                          color: AppTheme.textWhite, fontSize: 12)),
                  activeColor: AppTheme.primaryGold,
                  checkColor: Colors.black,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  dense: true,
                ),
              ],
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
      isActive: _currentStep >= 3,
    );
  }

  String _catLabel() {
    final config = context.read<ConfigProvider>().config;
    final source = _selectedType == 1
        ? config?.vehicleCategories
        : config?.propertyCategories;
    if (source != null && source.isNotEmpty && _selectedCat != null) {
      return source[_selectedCat.toString()]?.toString() ?? 'عرض';
    }
    final fallback = _selectedType == 1
        ? {1: 'سيدان', 2: 'SUV', 3: 'دفع رباعي'}
        : {1: 'شقة', 2: 'فيلا', 3: 'أرض'};
    return fallback[_selectedCat] ?? 'عرض';
  }

  Map<int, String> _mapFromDynamic(dynamic data) {
    final result = <int, String>{};
    if (data is Map) {
      data.forEach((key, value) {
        final id = int.tryParse(key);
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
    return _selectedType == 1
        ? {
            1: 'سيدان',
            2: 'SUV',
            3: 'دفع رباعي',
          }
        : {
            1: 'شقة',
            2: 'فيلا',
            3: 'أرض',
          };
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
      if (item is String) return item;
      if (item is Map) {
        return item['name']?.toString() ??
            item['d']?.toString() ??
            item.toString();
      }
      return item.toString();
    }).where((item) => item.isNotEmpty).cast<String>().toList();

    return Autocomplete<String>(
      initialValue: TextEditingValue(text: _locCtrl.text),
      optionsBuilder: (textEditingValue) {
        if (textEditingValue.text.isEmpty) return locations;
        final query = textEditingValue.text.toLowerCase();
        return locations.where(
            (option) => option.toLowerCase().contains(query));
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        controller.text = _locCtrl.text;
        controller.selection = _locCtrl.selection;
        return TextField(
          controller: controller,
          focusNode: focusNode,
          decoration: const InputDecoration(labelText: 'الموقع / المنطقة'),
          onChanged: (value) => _locCtrl.text = value,
        );
      },
      onSelected: (selection) {
        setState(() => _locCtrl.text = selection);
      },
    );
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
