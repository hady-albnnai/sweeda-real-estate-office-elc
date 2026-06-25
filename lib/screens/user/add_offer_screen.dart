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
    ('mon', 'الاثنين'), ('tue', 'الثلاثاء'), ('wed', 'الأربعاء'),
    ('thu', 'الخميس'), ('fri', 'الجمعة'), ('sat', 'السبت'), ('sun', 'الأحد'),
  ];
  final Map<String, bool> _avlDaysEnabled = {
    'mon': false, 'tue': false, 'wed': false, 'thu': false, 'fri': false, 'sat': false, 'sun': false,
  };
  final Map<String, List<Map<String, String>>> _avlSlots = {
    'mon': [], 'tue': [], 'wed': [], 'thu': [], 'fri': [], 'sat': [], 'sun': [],
  };

  Map<String, List<String>> _buildAvl() {
    if (_anytimeReady) return {'any': ['00:00-23:59']};
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
    _priceCtrl.dispose(); _locCtrl.dispose(); _descCtrl.dispose(); _specCtrl.dispose();
    _ttlCtrl.dispose(); _customSubCtrl.dispose(); _contactPhoneCtrl.dispose();
    _customCityCtrl.dispose(); _carBrandCtrl.dispose(); _carModelCtrl.dispose();
    _carYearCtrl.dispose(); _carColorCtrl.dispose(); _carKmCtrl.dispose();
    _carPlateCtrl.dispose(); _areaCtrl.dispose(); _floorCtrl.dispose(); _legalNotesCtrl.dispose();
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
      final bytes = kIsWeb ? await _docImage!.readAsBytes() : await (await _storage.compressImage(File(_docImage!.path)) ?? File(_docImage!.path)).readAsBytes();
      await storage.from(StorageService.offerBucket).uploadBinary(path, bytes, fileOptions: const FileOptions(cacheControl: '3600', upsert: true));
      return storage.from(StorageService.offerBucket).getPublicUrl(path);
    } catch (e) { return null; }
  }

  void _showPledgeDialog() {
    final config = context.read<ConfigProvider>().config;
    const defaultPledge = 'إقرار وتعهد إلكتروني — المكتب العقاري الالكتروني\n\nأقر أنا الموقع أدناه بموجب هذا الإقرار والتعهد بما يلي:\n1. أن جميع البيانات والمعلومات المقدمة صحيحة ودقيقة.\n2. أنني المالك الشرعي للعقار/السيارة أو مفوض قانوناً.\n3. أن تقديم أي بيانات كاذبة يعرضني للمسؤولية القانونية.';
    final pledgeText = config?.data?['txts']?['plg']?.toString() ?? defaultPledge;
    showDialog(context: context, builder: (_) => AlertDialog(backgroundColor: AppTheme.surfaceBlack, title: const Text('الإقرار والتعهد', style: TextStyle(color: AppTheme.textWhite)), content: SingleChildScrollView(child: Text(pledgeText, style: const TextStyle(color: AppTheme.textGrey, fontSize: 14, height: 1.6))), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق'))]));
  }

  Future<void> _pickImages() async {
    final remaining = StorageService.maxImages - _pickedImages.length;
    if (remaining <= 0) { _snack('الحد الأقصى ${StorageService.maxImages} صور'); return; }
    final files = await _storage.pickMultiImages(limit: remaining);
    if (files.isNotEmpty) setState(() => _pickedImages.addAll(files));
  }

  Future<void> _openWhatsAppVideoGroup() async {
    final config = context.read<ConfigProvider>().config;
    final groupUrl = config?.data?['txts']?['videoWhatsAppGroup']?.toString();
    final uri = Uri.parse(groupUrl ?? 'https://wa.me/');
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _submit() async {
    final auth = context.read<AuthProvider>();
    final offerProv = context.read<OfferProvider>();
    final configProv = context.read<ConfigProvider>();
    final user = auth.userModel;
    if (user == null) { _snack('يجب تسجيل الدخول'); return; }

    if (_selectedType == null || _selectedTrans == null || _selectedMainCat == null || _selectedDocType == null) {
      _snack('يرجى إكمال البيانات الأساسية واختيار نوع السند'); return;
    }
    
    // إزالة شرط إلزامية الصورة (أصبحت اختيارية كما طلبت)
    
    final effectivePhone = _contactPhoneCtrl.text.trim().isNotEmpty ? _contactPhoneCtrl.text.trim() : user.ph.trim();
    if (!RegExp(r'^09[3-9]\d{7}$').hasMatch(effectivePhone)) { _snack('يرجى إدخال رقم هاتف سوري صحيح (09xxxxxxxx)'); return; }

    setState(() { _submitting = true; _progressMsg = 'جاري رفع البيانات...'; });
    final docUrl = await _uploadDocImage(user.uid) ?? '';
    
    List<String> imageUrls = [];
    if (_pickedImages.isNotEmpty) {
      imageUrls = await _storage.uploadOfferImages(files: _pickedImages, userId: user.uid, onProgress: (done, total) {
        if (mounted) setState(() => _progressMsg = 'جاري رفع الصور ($done/$total)...');
      });
    }

    final loc = _selectedType == 1 ? {'r': 0, 'd': '', 'city': _carGovernorate ?? ''} : {'r': 0, 'd': _locCtrl.text, 'city': _selectedCityArea == _customCityOption ? _customCityCtrl.text : _selectedCityArea};

    final offer = OfferModel(
      id: '', usrId: user.uid, ttl: _ttlCtrl.text.isNotEmpty ? _ttlCtrl.text : 'عرض جديد',
      typ: _selectedType!, trx: _selectedTrans!, cat: _selectedMainCat!, sub: _selectedSubCat ?? 0,
      contactPh: effectivePhone, prc: double.tryParse(_priceCtrl.text) ?? 0, cur: _cur, loc: loc,
      descript: _descCtrl.text.isNotEmpty ? _descCtrl.text : _locCtrl.text,
      specs: {
        'details': _specCtrl.text,
        if (_selectedType == 0) ...{'area': _areaCtrl.text, 'floor': _floorCtrl.text, 'finishing': _finishing, 'direction': _direction, 'legal_notes': _legalNotesCtrl.text},
        if (_selectedType == 1) ...{'plate': _carPlateCtrl.text, 'brand': _carBrandCtrl.text, 'model': _carModelCtrl.text, 'year': _carYearCtrl.text, 'color': _carColorCtrl.text, 'fuel': _carFuel, 'transmission': _carTransmission, 'plate_type': _selectedPlateType},
      },
      imgs: imageUrls, vdo: '', exactLoc: _pickedLocation != null ? '${_pickedLocation!.latitude},${_pickedLocation!.longitude}' : '',
      docTp: _selectedDocType ?? 0, docImg: docUrl, avl: _buildAvl(), sts: OfferStatus.review, tsCrt: DateTime.now(),
    );

    try {
      await offerProv.addOffer(offer);
      if (mounted) { Navigator.pop(context); _snack('تم إرسال العرض للمراجعة بنجاح ✅'); }
    } catch (e) {
      if (mounted) { setState(() => _submitting = false); _snack('خطأ في النشر: $e'); }
    }
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إضافة عرض جديد'), backgroundColor: Colors.transparent),
      body: Stack(children: [
        Stepper(
          type: StepperType.vertical, currentStep: _currentStep,
          onStepTapped: (s) => setState(() => _currentStep = s),
          controlsBuilder: (context, details) => const SizedBox.shrink(),
          steps: [_step1(), _step2(), _step3(), if (_selectedType != 1) _stepAvl(), _step4()],
        ),
        if (_submitting) Container(color: Colors.black54, child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const CircularProgressIndicator(color: AppTheme.primaryGold), const SizedBox(height: 16), Text(_progressMsg, style: const TextStyle(color: AppTheme.textWhite))]))),
      ]),
    );
  }

  Step _step1() {
    final config = context.read<ConfigProvider>().config;
    final cityItems = (config?.data?['locs'] as List? ?? []).map((e) => DropdownMenuItem<String>(value: e.toString(), child: Text(e.toString()))).toList();
    cityItems.add(const DropdownMenuItem(value: _customCityOption, child: Text('آخر (إدخال حر)')));

    final Map<String, dynamic> catsSource = _selectedType == 1 ? (config?.data?['catVeh'] ?? {}) : (config?.data?['catProp'] ?? {});
    final mainCatItems = catsSource.entries.map((e) => DropdownMenuItem<int>(value: int.tryParse(e.key), child: Text(e.value['nm']?.toString() ?? ''))).toList();

    return Step(
      title: const Text('الأساسيات', style: TextStyle(color: AppTheme.primaryGold, fontWeight: FontWeight.bold)),
      content: Column(children: [
        _dd('نوع العرض', ['عقار', 'سيارة'], (v) => setState(() { _selectedType = v == 'عقار' ? 0 : 1; _selectedMainCat = null; _selectedSubCat = null; })),
        const SizedBox(height: 15),
        _dd('نوع المعاملة', ['بيع', 'إيجار'], (v) => setState(() => _selectedTrans = v == 'بيع' ? 0 : 1)),
        const SizedBox(height: 15),
        DropdownButtonFormField<int>(value: _selectedMainCat, items: mainCatItems, onChanged: (v) => setState(() { _selectedMainCat = v; _selectedSubCat = null; }), decoration: const InputDecoration(labelText: 'التصنيف الرئيسي', border: OutlineInputBorder())),
        const SizedBox(height: 15),
        if (_selectedMainCat != null)
           DropdownButtonFormField<int>(
             value: _selectedSubCat,
             items: [
               ...((catsSource[_selectedMainCat.toString()]?['sub'] as List? ?? []).asMap().entries.map((e) => DropdownMenuItem<int>(value: e.key, child: Text(e.value.toString())))),
               const DropdownMenuItem(value: -1, child: Text('آخر'))
             ],
             onChanged: (v) => setState(() => _selectedSubCat = v),
             decoration: const InputDecoration(labelText: 'التصنيف الفرعي', border: OutlineInputBorder()),
           ),
        const SizedBox(height: 15),
        TextField(controller: _contactPhoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'رقم الهاتف للتواصل (إلزامي)', hintText: 'مثال: 09xxxxxxxx', border: OutlineInputBorder(), prefixIcon: Icon(Icons.phone))),
        const SizedBox(height: 15),
        if (_selectedType == 0) ...[
          DropdownButtonFormField<String>(value: _selectedCityArea, items: cityItems, onChanged: (v) => setState(() => _selectedCityArea = v), decoration: const InputDecoration(labelText: 'المنطقة الرئيسية', border: OutlineInputBorder())),
          if (_selectedCityArea == _customCityOption) Padding(padding: const EdgeInsets.only(top: 10), child: TextField(controller: _customCityCtrl, decoration: const InputDecoration(labelText: 'اكتب المنطقة يدوياً', border: OutlineInputBorder()))),
          const SizedBox(height: 15),
          TextField(controller: _locCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'وصف دقيق للموقع (إلزامي)', hintText: 'بجانب مدرسة... شارع... الطابق...', border: OutlineInputBorder())),
        ],
        if (_selectedType == 1) ...[
          TextField(controller: _carPlateCtrl, decoration: const InputDecoration(labelText: 'لوحة السيارة (إلزامي)', hintText: 'مثال: 123456', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: _carBrandCtrl, decoration: const InputDecoration(labelText: 'الماركة (إلزامي)', hintText: 'كيا، تويوتا، مرسيدس...', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: _carModelCtrl, decoration: const InputDecoration(labelText: 'الموديل (إلزامي)', hintText: 'سيراتو، لاندكروزر، أكسنت...', border: OutlineInputBorder())),
        ],
      ]),
      isActive: _currentStep >= 0,
    );
  }

  Step _step2() => Step(
    title: const Text('التفاصيل والمواصفات', style: TextStyle(color: AppTheme.primaryGold, fontWeight: FontWeight.bold)),
    content: Column(children: [
      TextField(controller: _ttlCtrl, maxLength: 80, decoration: const InputDecoration(labelText: 'عنوان العرض بالتطبيق (اختياري)', hintText: 'شقة فاخرة، سيارة نظيفة، أرض زراعية...', border: OutlineInputBorder())),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(flex: 3, child: TextField(controller: _priceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'السعر المتوقع (إلزامي)', border: OutlineInputBorder()))),
        const SizedBox(width: 8),
        Expanded(flex: 3, child: DropdownButtonFormField<int>(value: _cur, isExpanded: true, items: const [DropdownMenuItem(value: 0, child: Text('دولار أمريكي', overflow: TextOverflow.ellipsis)), DropdownMenuItem(value: 1, child: Text('ليرة سورية', overflow: TextOverflow.ellipsis))], onChanged: (v) => setState(() => _cur = v ?? 1), decoration: const InputDecoration(border: OutlineInputBorder()))),
      ]),
      const SizedBox(height: 15),
      if (_selectedType == 0) ...[
        TextField(controller: _areaCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'المساحة م² (اختياري)', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        _dd('الإكساء (اختياري)', ['ملكي', 'سوبر ديلوكس', 'ديلوكس', 'عادي', 'هيكل'], (v) => setState(() => _finishing = v)),
        const SizedBox(height: 12),
        TextField(controller: _floorCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'الطابق (اختياري)', hintText: 'مثال: 3', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        _dd('اتجاه العقار (اختياري)', ['شمالي', 'جنوبي', 'شرقي', 'غربي', 'شمالي شرقي', 'شمالي غربي', 'جنوبي شرقي', 'جنوبي غربي', 'مفتوح - 4 اتجاهات'], (v) => setState(() => _direction = v)),
        const SizedBox(height: 12),
        TextField(controller: _legalNotesCtrl, decoration: const InputDecoration(labelText: 'ملاحظات قانونية (اختياري)', hintText: 'طابو أخضر، كاتب عدل، حكم محكمة...', border: OutlineInputBorder())),
      ],
      if (_selectedType == 1) ...[
        TextField(controller: _carYearCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'سنة الصنع (إلزامي)', border: OutlineInputBorder())),
        const SizedBox(height: 10),
        _dd('نوع الوقود (اختياري)', ['بنزين', 'ديزل', 'هجين', 'كهرباء'], (v) => setState(() => _carFuel = v)),
        const SizedBox(height: 10),
        _dd('ناقل الحركة (اختياري)', ['عادي', 'أوتوماتيك', 'نصف أوتوماتيك'], (v) => setState(() => _carTransmission = v)),
        const SizedBox(height: 10),
        TextField(controller: _carColorCtrl, decoration: const InputDecoration(labelText: 'اللون (اختياري)', border: OutlineInputBorder())),
        const SizedBox(height: 10),
        TextField(controller: _carKmCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'عدد الكيلومترات (اختياري)', border: OutlineInputBorder())),
      ],
      const SizedBox(height: 15),
      TextField(controller: _descCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'وصف إضافي (اختياري)', hintText: 'أي مميزات أو تفاصيل أخرى تود ذكرها للزبائن...', border: OutlineInputBorder())),
      const SizedBox(height: 15),
      TextField(controller: _specCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'مواصفات إضافية (اختياري)', hintText: 'مثال: 3 غرف، 2 حمام، بلكون، مصعد...', border: OutlineInputBorder())),
      const SizedBox(height: 20),
      if (_selectedType == 0) ...[
        const Text('الموقع الدقيق على الخريطة (اختياري)', style: TextStyle(color: AppTheme.primaryGold, fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),
        LocationPicker(initial: _pickedLocation, onPicked: (loc) => setState(() => _pickedLocation = loc), height: 250),
      ],
    ]),
    isActive: _currentStep >= 1,
  );

  Step _step3() => Step(
    title: const Text('الصور والفيديو', style: TextStyle(color: AppTheme.primaryGold, fontWeight: FontWeight.bold)),
    content: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ElevatedButton.icon(onPressed: _pickImages, icon: const Icon(Icons.add_a_photo), label: Text('إضافة صور العرض (${_pickedImages.length}/${StorageService.maxImages})')),
      const SizedBox(height: 10),
      if (_pickedImages.isNotEmpty) Wrap(spacing: 8, children: _pickedImages.asMap().entries.map((e) => Stack(children: [ClipRRect(borderRadius: BorderRadius.circular(8), child: _thumb(e.value)), Positioned(top: -5, left: -5, child: IconButton(icon: const Icon(Icons.cancel, color: Colors.red), onPressed: () => setState(() => _pickedImages.removeAt(e.key))))])).toList()),
      const SizedBox(height: 20),
      const Text('🎬 فيديو العرض (اختياري)', style: TextStyle(color: AppTheme.primaryGold, fontWeight: FontWeight.bold, fontSize: 13)),
      const SizedBox(height: 8),
      OutlinedButton.icon(onPressed: _openWhatsAppVideoGroup, icon: const Icon(Icons.video_library), label: const Text('إرسال فيديو عبر واتساب المكتب')),
    ]),
    isActive: _currentStep >= 2,
  );

  Step _stepAvl() => Step(
    title: const Text('المواعيد المتاحة للمعاينة', style: TextStyle(color: AppTheme.primaryGold, fontWeight: FontWeight.bold)),
    content: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppTheme.primaryGold.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.primaryGold.withValues(alpha: 0.3))),
        child: SwitchListTile(
          value: _anytimeReady,
          onChanged: (v) => setState(() => _anytimeReady = v),
          title: const Text('أنا جاهز للمعاينة في أي وقت', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
          subtitle: const Text('سيتمكن الزبائن من طلب موعد في أي وقت تراه الإدارة مناسباً', style: TextStyle(color: AppTheme.textGrey, fontSize: 11)),
          activeColor: AppTheme.primaryGold,
          contentPadding: EdgeInsets.zero,
        ),
      ),
      const SizedBox(height: 16),
      if (!_anytimeReady) ...[
        const Text('أو حدد أياماً وفترات زمنية محددة:', style: TextStyle(color: AppTheme.textGrey, fontSize: 13)),
        const SizedBox(height: 12),
        ..._weekDays.map((day) {
          final key = day.$1; final label = day.$2; final enabled = _avlDaysEnabled[key] ?? false; final slots = _avlSlots[key] ?? [];
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(color: AppTheme.surfaceBlack, borderRadius: BorderRadius.circular(10), border: Border.all(color: enabled ? AppTheme.primaryGold.withValues(alpha: 0.5) : AppTheme.textGrey.withValues(alpha: 0.2))),
            child: Column(children: [
              ListTile(
                leading: Icon(enabled ? Icons.check_box : Icons.check_box_outline_blank, color: enabled ? AppTheme.primaryGold : AppTheme.textGrey),
                title: Text(label, style: TextStyle(color: enabled ? AppTheme.textWhite : AppTheme.textGrey, fontWeight: FontWeight.bold)),
                onTap: () => setState(() { _avlDaysEnabled[key] = !enabled; if (!enabled && slots.isEmpty) _avlSlots[key]!.add({'from': '', 'to': ''}); }),
                trailing: enabled ? IconButton(icon: const Icon(Icons.add, color: AppTheme.primaryGold, size: 20), onPressed: () => setState(() => _avlSlots[key]!.add({'from': '', 'to': ''}))) : null,
              ),
              if (enabled) ...slots.asMap().entries.map((entry) {
                final i = entry.key; final slot = entry.value;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Row(children: [
                    const Text('من', style: TextStyle(color: AppTheme.textGrey, fontSize: 11)),
                    const SizedBox(width: 4),
                    Expanded(child: _timeField(value: slot['from'] ?? '', hint: '09:00', onChanged: (v) => setState(() => _avlSlots[key]![i]['from'] = v))),
                    const SizedBox(width: 8),
                    const Text('إلى', style: TextStyle(color: AppTheme.textGrey, fontSize: 11)),
                    const SizedBox(width: 4),
                    Expanded(child: _timeField(value: slot['to'] ?? '', hint: '12:00', onChanged: (v) => setState(() => _avlSlots[key]![i]['to'] = v))),
                    IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 18), onPressed: () => setState(() => _avlSlots[key]!.removeAt(i))),
                  ]),
                );
              }),
            ]),
          );
        }),
      ],
    ]),
    isActive: _currentStep >= 3,
  );

  Widget _timeField({required String value, required String hint, required void Function(String) onChanged}) {
    return TextField(
      controller: TextEditingController(text: value)..selection = TextSelection.collapsed(offset: value.length),
      keyboardType: TextInputType.datetime,
      style: const TextStyle(color: AppTheme.textWhite, fontSize: 13),
      decoration: InputDecoration(hintText: hint, contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5), isDense: true, border: const OutlineInputBorder()),
      onChanged: onChanged,
    );
  }

  Step _step4() {
    final config = context.watch<ConfigProvider>().config;
    final Map<String, dynamic> rawDocTp = config?.data?['docTp'] ?? {};
    final Map<String, dynamic> rawCarDocTp = config?.data?['carDocTp'] ?? {};
    final Map<String, dynamic> rawPlateTp = config?.data?['plateTp'] ?? {};

    // فلترة السندات لمنع تداخل السيارات بالعقارات
    final propertyDocs = rawDocTp.entries
        .where((e) => int.tryParse(e.key) != null && int.parse(e.key) < 6)
        .map((e) => DropdownMenuItem<int>(value: int.parse(e.key), child: Text(e.value.toString())))
        .toList();

    return Step(
      title: const Text('السند والعمولة', style: TextStyle(color: AppTheme.primaryGold, fontWeight: FontWeight.bold)),
      content: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (_selectedType == 1) ...[
          const Text('سند ملكية السيارة (إلزامي)', style: TextStyle(color: AppTheme.primaryGold, fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          DropdownButtonFormField<int>(value: _selectedCarDocType, items: rawCarDocTp.entries.map((e) => DropdownMenuItem(value: int.parse(e.key), child: Text(e.value.toString()))).toList(), onChanged: (v) => setState(() { _selectedCarDocType = v; _selectedDocType = v; }), decoration: const InputDecoration(border: OutlineInputBorder())),
          const SizedBox(height: 12),
          const Text('نوع النمرة (إلزامي)', style: TextStyle(color: AppTheme.primaryGold, fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          DropdownButtonFormField<int>(value: _selectedPlateType, items: rawPlateTp.entries.map((e) => DropdownMenuItem(value: int.parse(e.key), child: Text(e.value.toString()))).toList(), onChanged: (v) => setState(() => _selectedPlateType = v), decoration: const InputDecoration(border: OutlineInputBorder())),
        ] else ...[
          const Text('سند ملكية العقار (إلزامي)', style: TextStyle(color: AppTheme.primaryGold, fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          DropdownButtonFormField<int>(value: _selectedDocType, items: propertyDocs, onChanged: (v) => setState(() => _selectedDocType = v), decoration: const InputDecoration(border: OutlineInputBorder())),
        ],
        const SizedBox(height: 15),
        const Text('صورة سند الملكية (اختياري)', style: TextStyle(color: AppTheme.primaryGold, fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        GestureDetector(onTap: _pickDocImage, child: Container(height: 120, width: double.infinity, decoration: BoxDecoration(color: AppTheme.surfaceBlack, borderRadius: BorderRadius.circular(10), border: Border.all(color: _docImage != null ? Colors.green : AppTheme.primaryGold.withValues(alpha: 0.5))), child: _docImage == null ? const Center(child: Icon(Icons.upload_file, size: 40, color: AppTheme.primaryGold)) : ClipRRect(borderRadius: BorderRadius.circular(10), child: kIsWeb ? Image.network(_docImage!.path, fit: BoxFit.cover) : Image.file(File(_docImage!.path), fit: BoxFit.cover, cacheWidth: 800)))),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppTheme.primaryGold.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.primaryGold, width: 1.5)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [Icon(Icons.monetization_on, color: AppTheme.primaryGold, size: 28), SizedBox(width: 10), Text('تنبيه بخصوص عمولة المكتب', style: TextStyle(color: AppTheme.primaryGold, fontWeight: FontWeight.bold, fontSize: 15))]),
            const SizedBox(height: 8),
            Text(_selectedTrans == 0 ? 'يتقاضى المكتب عمولة قدرها 3% من القيمة الإجمالية عند إتمام عملية البيع.' : 'يتقاضى المكتب عمولة تعادل أجرة نصف شهر عند إتمام عملية الإيجار.', style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4)),
          ]),
        ),
        const SizedBox(height: 15),
        CheckboxListTile(value: _agreePledge, onChanged: (v) => setState(() => _agreePledge = v ?? false), title: const Text('أوافق على الإقرار والتعهد وصحة البيانات المقدمة', style: TextStyle(color: Colors.white, fontSize: 13)), activeColor: AppTheme.primaryGold, contentPadding: EdgeInsets.zero, controlAffinity: ListTileControlAffinity.leading),
        const SizedBox(height: 10),
        SizedBox(width: double.infinity, height: 55, child: ElevatedButton(onPressed: _submitting ? null : _submit, child: const Text('نشر العرض للمراجعة الآن', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)))),
      ]),
      isActive: _currentStep >= 4,
    );
  }

  Widget _thumb(XFile file) => kIsWeb ? Image.network(file.path, width: 70, height: 70, fit: BoxFit.cover) : Image.file(File(file.path), width: 70, height: 70, fit: BoxFit.cover, cacheWidth: 200);
  Widget _dd(String label, List<String> items, Function(String) on) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(color: AppTheme.textGrey, fontSize: 12)), const SizedBox(height: 5), DropdownButtonFormField<String>(items: items.map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(), onChanged: (v) => on(v!), decoration: const InputDecoration(border: OutlineInputBorder()))]);
}
