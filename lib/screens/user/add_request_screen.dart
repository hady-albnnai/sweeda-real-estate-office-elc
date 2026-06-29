import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/request_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/config_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/business_service.dart';
import '../../core/constants/db_constants.dart';
import '../../models/request_model.dart';
import '../../models/offer_model.dart';

/// شاشة إضافة طلب (شراء / إيجار)
class AddRequestScreen extends StatefulWidget {
  const AddRequestScreen({super.key});

  @override
  State<AddRequestScreen> createState() => _AddRequestScreenState();
}

class _AddRequestScreenState extends State<AddRequestScreen> {
  int _currentStep = 0;
  int? _selectedType;    // 0=شراء, 1=استئجار
  int? _selectedElement; // 0=عقار, 1=سيارة
  int? _selectedMainCat;
  int? _selectedSubCat;
  final _customSubCtrl   = TextEditingController();
  final _clientNameCtrl  = TextEditingController();
  final _clientPhoneCtrl = TextEditingController();
  final _priceCtrl       = TextEditingController();
  final _notesCtrl       = TextEditingController();
  final _specsCtrl       = TextEditingController(); // المواصفات المطلوبة
  int _cur = Currency.lbp; // العملة — دولار أو ل.س

  bool _submitting = false;

  void _next() => setState(() { if (_currentStep < 2) _currentStep++; });
  void _prev() => setState(() { if (_currentStep > 0) _currentStep--; });

  @override
  void dispose() {
    _clientNameCtrl.dispose();
    _clientPhoneCtrl.dispose();
    _priceCtrl.dispose();
    _notesCtrl.dispose();
    _specsCtrl.dispose();
    _customSubCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedType == null || _selectedElement == null) {
      _snack('يرجى اختيار نوع الطلب والعنصر');
      return;
    }
    if (_clientNameCtrl.text.trim().isEmpty ||
        _clientPhoneCtrl.text.trim().isEmpty) {
      _snack('اسم العميل وهاتفه إلزاميان');
      return;
    }

    final auth      = context.read<AuthProvider>();
    final reqProv   = context.read<RequestProvider>();
    final user      = auth.userModel;
    if (user == null) return;

    setState(() => _submitting = true);

    // فحص الحصة عبر Edge Function حتى لا نفتح RPC مباشرة من العميل.
    final quota = await reqProv.canPublishRequest(user.uid);
    if (quota['allowed'] != true) {
      if (mounted) setState(() => _submitting = false);
      final reason = quota['reason']?.toString();
      _snack(reason == 'QUOTA_EXCEEDED'
          ? 'وصلت للحد الأقصى (${quota['limit']} طلب).'
          : (reason?.isNotEmpty == true ? reason! : 'تعذّر التحقق من حصتك، حاول لاحقاً.'));
      return;
    }

    final budget  = double.tryParse(_priceCtrl.text) ?? 0;
    final element = _selectedElement ?? 0;

    // بناء specs من حقل المواصفات
    final specsText = _specsCtrl.text.trim();
    final specs = specsText.isNotEmpty
        ? {'details': specsText}
        : <String, dynamic>{};

    // التصنيف الفرعي
    final customSub = _customSubCtrl.text.trim();
    if (customSub.isNotEmpty) {
      specs['custom_sub'] = customSub;
    }

    final request = RequestModel(
      id:    '',
      typ:   _selectedType!,
      elm:   element,
      clNm:  _clientNameCtrl.text.trim(),
      clPh:  _clientPhoneCtrl.text.trim(),
      prc:   budget,
      cur:   _cur,
      notes: _notesCtrl.text.trim(),
      specs: specs,
      usrId: user.uid,
      sts:   0,
      tsCrt: DateTime.now(),
    );

    bool ok = false;
    try {
      ok = await reqProv.addRequest(request);
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        _snack('فشل إرسال الطلب: $e');
      }
      return;
    }

    if (!ok) {
      if (mounted) {
        setState(() => _submitting = false);
        _snack('فشل إرسال الطلب، حاول مجدداً');
      }
      return;
    }

    if (!mounted) return;
    setState(() => _submitting = false);

    // الانتقال إلى شاشة العروض المطابقة المتقدمة (Phase C)
    context.push('/matching-offers', extra: request.toMap());
  }

  Future<void> _showMatchesSheet(List<OfferModel> matches) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceBlack,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (ctx, scroll) => Column(children: [
          const SizedBox(height: 12),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
                color: AppTheme.textGrey,
                borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              const Icon(Icons.auto_awesome, color: AppTheme.primaryGold),
              const SizedBox(width: 8),
              Text('${matches.length} عرض مطابق لطلبك',
                  style: const TextStyle(
                      color: AppTheme.primaryGold,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
            ]),
          ),
          Expanded(
            child: ListView.builder(
              controller: scroll,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: matches.length,
              itemBuilder: (_, i) {
                final o = matches[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.deepBlack,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppTheme.primaryGold.withOpacity(0.2)),
                  ),
                  child: ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: o.imgs.isNotEmpty
                          ? Image.network(o.imgs[0],
                              width: 50, height: 50, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _imgBox())
                          : _imgBox(),
                    ),
                    title: Text(o.ttl,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppTheme.textWhite)),
                    subtitle: Text(
                        '${o.prc.toStringAsFixed(0)} ${o.cur == 0 ? '\$' : 'ل.س'}',
                        style:
                            const TextStyle(color: AppTheme.primaryGold)),
                    trailing: const Icon(Icons.arrow_back_ios,
                        color: AppTheme.primaryGold, size: 14),
                    onTap: () {
                      Navigator.pop(ctx);
                      context.push('/offer/${o.id}');
                    },
                  ),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }

  Widget _imgBox() => Container(
        width: 50, height: 50, color: AppTheme.surfaceBlack,
        child: const Icon(Icons.home_work, color: AppTheme.primaryGold));

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  // ── مساعدات التصنيف من Config (مطابقة لشاشة العرض) ──

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
    final categories = _selectedElement == 1
        ? config?.vehicleCategories
        : config?.propertyCategories;
    if (categories != null && categories.isNotEmpty) {
      return _mapFromDynamic(categories);
    }
    return {0: _selectedElement == 1 ? 'مركبة' : 'عقار'};
  }

  Map<int, String> _subCategoryMap(int mainId) {
    final config = context.read<ConfigProvider>().config;
    final categories = _selectedElement == 1
        ? config?.vehicleCategories
        : config?.propertyCategories;
    final mainItem = categories?['$mainId'];
    if (mainItem is Map) {
      final subSource = mainItem['sub'] ?? mainItem['children'] ?? mainItem;
      final subMap = _mapFromDynamic(subSource);
      if (subMap.isNotEmpty) return subMap;
    }
    return {mainId: _categoryGroupMap()[mainId] ?? '—'};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.deepBlack,
      appBar: AppBar(
        backgroundColor: AppTheme.deepBlack,
        elevation: 0,
        title: const Text('إضافة طلب جديد',
            style: TextStyle(
                color: AppTheme.primaryGold, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppTheme.textGrey),
          onPressed: () => context.pop(),
        ),
      ),
      body: Stack(
        children: [
          Stepper(
            type: StepperType.vertical,
            currentStep: _currentStep,
            onStepTapped: (s) => setState(() => _currentStep = s),
            onStepContinue: _next,
            onStepCancel: _prev,
            steps: [_step1(), _step2(), _step3()],
            controlsBuilder: (context, details) => Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Row(children: [
                ElevatedButton(
                  onPressed: _submitting
                      ? null
                      : (_currentStep == 2
                          ? _submit
                          : details.onStepContinue),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGold,
                    foregroundColor: AppTheme.deepBlack,
                  ),
                  child: Text(_currentStep == 2 ? 'إرسال الطلب' : 'التالي'),
                ),
                if (_currentStep > 0)
                  Padding(
                    padding: const EdgeInsets.only(left: 10),
                    child: TextButton(
                      onPressed: details.onStepCancel,
                      child: const Text('السابق',
                          style: TextStyle(color: AppTheme.textGrey)),
                    ),
                  ),
              ]),
            ),
          ),
          if (_submitting)
            Container(
              color: const Color.fromRGBO(0, 0, 0, 0.6),
              child: const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryGold),
              ),
            ),
        ],
      ),
    );
  }

  // ─── Step 1: نوع الطلب والتصنيف ───
  Step _step1() {
    final mainCategories = _selectedElement != null
        ? _categoryGroupMap()
        : <int, String>{};
    final subCategories = _selectedMainCat != null
        ? _subCategoryMap(_selectedMainCat!)
        : <int, String>{};

    return Step(
      title: const Text('نوع الطلب',
          style: TextStyle(
              color: AppTheme.primaryGold, fontWeight: FontWeight.bold)),
      content: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _dd('نوع الطلب', ['شراء', 'استئجار'],
            (v) => setState(() {
                  _selectedType = v == 'شراء' ? 0 : 1;
                })),
        const SizedBox(height: 16),
        _dd('نوع العنصر', ['عقار', 'سيارة'],
            (v) => setState(() {
                  _selectedElement = v == 'عقار' ? 0 : 1;
                  _selectedMainCat = null;
                  _selectedSubCat  = null;
                  _customSubCtrl.clear();
                })),
        const SizedBox(height: 16),
        if (_selectedElement != null) ...[
          DropdownButtonFormField<int>(
            value: _selectedMainCat,
            dropdownColor: AppTheme.surfaceBlack,
            style: const TextStyle(color: AppTheme.textWhite),
            decoration: const InputDecoration(
                labelText: 'التصنيف الرئيسي (اختياري)',
                border: OutlineInputBorder()),
            items: mainCategories.entries
                .map((e) =>
                    DropdownMenuItem(value: e.key, child: Text(e.value)))
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
              value: _selectedSubCat,
              dropdownColor: AppTheme.surfaceBlack,
              style: const TextStyle(color: AppTheme.textWhite, fontSize: 14),
              decoration: const InputDecoration(
                  labelText: 'التصنيف الفرعي (اختياري)',
                  border: OutlineInputBorder()),
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
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
          ],
        ],
        if (_selectedType != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.surfaceBlack,
              border: Border.all(
                  color: AppTheme.primaryGold.withOpacity(0.4)),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              _selectedType == 0
                  ? 'المكتب يتقاضى عمولة 3% عند إتمام عملية الشراء.'
                  : 'المكتب يتقاضى أجرة نصف شهر عند إتمام عملية الاستئجار.',
              style: const TextStyle(color: AppTheme.textWhite, fontSize: 12),
            ),
          ),
        ],
      ]),
      isActive: _currentStep >= 0,
    );
  }

  // ─── Step 2: معلومات العميل والميزانية ───
  Step _step2() => Step(
        title: const Text('معلومات العميل',
            style: TextStyle(
                color: AppTheme.primaryGold, fontWeight: FontWeight.bold)),
        content: Column(children: [
          TextField(
            controller: _clientNameCtrl,
            decoration: const InputDecoration(
              labelText: 'اسم العميل (إلزامي)',
              filled: true,
              fillColor: AppTheme.surfaceBlack,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _clientPhoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'هاتف العميل (إلزامي)',
              hintText: 'مثال: 0938862469',
              filled: true,
              fillColor: AppTheme.surfaceBlack,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          // الميزانية + العملة
          Row(children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: _priceCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'الميزانية المتوقعة',
                  filled: true,
                  fillColor: AppTheme.surfaceBlack,
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<int>(
                value: _cur,
                dropdownColor: AppTheme.surfaceBlack,
                style: const TextStyle(color: AppTheme.textWhite),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: AppTheme.surfaceBlack,
                ),
                items: const [
                  DropdownMenuItem(value: Currency.dollar, child: Text('دولار')),
                  DropdownMenuItem(value: Currency.lbp,    child: Text('ل.س')),
                ],
                onChanged: (v) => setState(() => _cur = v ?? Currency.lbp),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          // توضيح: بيانات العميل للإدارة وصاحب الطلب فقط
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryGold.withOpacity(0.06),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: AppTheme.primaryGold.withOpacity(0.2)),
            ),
            child: const Row(children: [
              Icon(Icons.lock_outline,
                  color: AppTheme.primaryGold, size: 14),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'بيانات العميل تظهر فقط لك وللإدارة — لا تُكشف لأي طرف آخر.',
                  style: TextStyle(
                      color: AppTheme.textGrey,
                      fontSize: 11,
                      height: 1.4),
                ),
              ),
            ]),
          ),
        ]),
        isActive: _currentStep >= 1,
      );

  // ─── Step 3: المواصفات والملاحظات ───
  Step _step3() => Step(
        title: const Text('المواصفات والملاحظات',
            style: TextStyle(
                color: AppTheme.primaryGold, fontWeight: FontWeight.bold)),
        content: Column(children: [
          TextField(
            controller: _specsCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'المواصفات المطلوبة (اختيارية)',
              hintText:
                  'مثال: 3 غرف نوم، موقف سيارة، بالقرب من المدارس...',
              filled: true,
              fillColor: AppTheme.surfaceBlack,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _notesCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'ملاحظات إضافية (اختيارية)',
              filled: true,
              fillColor: AppTheme.surfaceBlack,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: const Icon(Icons.send),
              label: Text(
                  _submitting ? 'جارٍ الإرسال...' : 'إرسال الطلب',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGold,
                foregroundColor: AppTheme.deepBlack,
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
            ),
          ),
        ]),
        isActive: _currentStep >= 2,
      );

  Widget _dd(String label, List<String> items, Function(String) onSelected) =>
      DropdownButtonFormField<String>(
        value: null,
        items: items
            .map((i) => DropdownMenuItem(value: i, child: Text(i)))
            .toList(),
        onChanged: (v) => onSelected(v!),
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: AppTheme.surfaceBlack,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
}
