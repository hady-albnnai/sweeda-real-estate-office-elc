import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/request_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/config_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/business_service.dart';
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
  int? _selectedType; // 0=شراء, 1=استئجار
  int? _selectedElement; // 0=عقار, 1=سيارة
  String? _selectedCategory;
  final _clientNameCtrl = TextEditingController();
  final _clientPhoneCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  Map<String, dynamic> _specs = {};

  void _next() => setState(() { if (_currentStep < 2) _currentStep++; });
  void _prev() => setState(() { if (_currentStep > 0) _currentStep--; });

  bool _submitting = false;

  Future<void> _submit() async {
    if (_selectedType == null || _clientNameCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إكمال البيانات الأساسية')));
      return;
    }
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final reqProv = Provider.of<RequestProvider>(context, listen: false);
    final configProv = Provider.of<ConfigProvider>(context, listen: false);
    final user = auth.userModel;
    if (user == null) return;

    setState(() => _submitting = true);

    // فحص حصة الطلبات
    final quota = await BusinessService().canPublishRequest(
      uid: user.uid,
      role: user.role,
      config: configProv.config,
    );
    if (quota['allowed'] != true) {
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(quota['reason'] as String)));
      return;
    }

    final budget = double.tryParse(_priceCtrl.text) ?? 0;
    final element = _selectedElement ?? 0;

    final request = RequestModel(
      id: '',
      typ: _selectedType!,
      elm: element,
      clNm: _clientNameCtrl.text,
      clPh: _clientPhoneCtrl.text,
      prc: budget,
      cur: 1,
      notes: _notesCtrl.text,
      specs: _specs,
      usrId: user.uid,
      sts: 0,
      tsCrt: DateTime.now(),
    );

    final ok = await reqProv.addRequest(request);

    if (!ok) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('فشل إرسال الطلب، حاول مجدداً')));
      }
      return;
    }

    // المطابقة التلقائية: البحث عن عروض مطابقة (نوع العنصر + الميزانية ±20%)
    final matches = await BusinessService().matchOffersForRequest(
      type: element,
      targetPrice: budget,
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (matches.isNotEmpty) {
      await _showMatchesSheet(matches);
    }
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(matches.isEmpty
          ? 'تم إرسال طلبك بنجاح ✅'
          : 'تم إرسال طلبك ✅ — وجدنا ${matches.length} عرض مطابق!'),
    ));
  }

  Future<void> _showMatchesSheet(List<OfferModel> matches) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceBlack,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (ctx, scroll) => Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.textGrey,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome, color: AppTheme.primaryGold),
                  const SizedBox(width: 8),
                  Text('${matches.length} عرض مطابق لطلبك',
                      style: const TextStyle(
                          color: AppTheme.primaryGold,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                ],
              ),
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
                          color: AppTheme.primaryGold.withValues(alpha: 0.2)),
                    ),
                    child: ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: o.imgs.isNotEmpty
                            ? Image.network(o.imgs[0],
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _imgBox())
                            : _imgBox(),
                      ),
                      title: Text(o.ttl,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppTheme.textWhite)),
                      subtitle: Text(
                          '${o.prc.toStringAsFixed(0)} ${o.cur == 0 ? '\$' : 'ل.س'}',
                          style: const TextStyle(color: AppTheme.primaryGold)),
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
          ],
        ),
      ),
    );
  }

  Widget _imgBox() => Container(
        width: 50,
        height: 50,
        color: AppTheme.surfaceBlack,
        child: const Icon(Icons.home_work, color: AppTheme.primaryGold),
      );

  @override
  void dispose() {
    _clientNameCtrl.dispose();
    _clientPhoneCtrl.dispose();
    _priceCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.deepBlack,
      appBar: AppBar(
        backgroundColor: AppTheme.deepBlack,
        elevation: 0,
        title: const Text('إضافة طلب جديد', style: TextStyle(color: AppTheme.primaryGold, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppTheme.textGrey),
          onPressed: () => context.pop(),
        ),
      ),
      body: Stepper(
        type: StepperType.vertical,
        currentStep: _currentStep,
        onStepTapped: (s) => setState(() => _currentStep = s),
        onStepContinue: _next,
        onStepCancel: _prev,
        steps: [_step1(), _step2(), _step3()],
        controlsBuilder: (context, details) {
          return Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Row(
              children: [
                if (details.onStepContinue != null)
                  ElevatedButton(
                    onPressed: _submitting
                        ? null
                        : (_currentStep == 2 ? _submit : details.onStepContinue),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGold,
                      foregroundColor: AppTheme.deepBlack,
                    ),
                    child: Text(_currentStep == 2 ? 'إرسال الطلب' : 'التالي'),
                  ),
                if (details.onStepCancel != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 10),
                    child: TextButton(
                      onPressed: details.onStepCancel,
                      child: const Text('السابق', style: TextStyle(color: AppTheme.textGrey)),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Step _step1() => Step(
    title: const Text('نوع الطلب', style: TextStyle(color: AppTheme.primaryGold, fontWeight: FontWeight.bold)),
    content: Column(
      children: [
        _dropdown('نوع الطلب', ['شراء', 'استئجار'], (v) => setState(() => _selectedType = v == 'شراء' ? 0 : 1)),
        const SizedBox(height: 15),
        _dropdown('نوع العنصر', ['عقار', 'سيارة'], (v) => setState(() => _selectedElement = v == 'عقار' ? 0 : 1)),
        const SizedBox(height: 15),
        _dropdown('التصنيف', _categories, (v) => setState(() => _selectedCategory = v)),
      ],
    ),
    isActive: _currentStep >= 0,
  );

  Step _step2() => Step(
    title: const Text('معلومات العميل', style: TextStyle(color: AppTheme.primaryGold, fontWeight: FontWeight.bold)),
    content: Column(
      children: [
        TextField(
          controller: _clientNameCtrl,
          decoration: const InputDecoration(
            labelText: 'اسم العميل',
            filled: true,
            fillColor: AppTheme.surfaceBlack,
          ),
        ),
        const SizedBox(height: 15),
        TextField(
          controller: _clientPhoneCtrl,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'هاتف العميل',
            filled: true,
            fillColor: AppTheme.surfaceBlack,
          ),
        ),
        const SizedBox(height: 15),
        TextField(
          controller: _priceCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'الميزانية المتوقعة (ل.س)',
            filled: true,
            fillColor: AppTheme.surfaceBlack,
          ),
        ),
      ],
    ),
    isActive: _currentStep >= 1,
  );

  Step _step3() => Step(
    title: const Text('المواصفات والملاحظات', style: TextStyle(color: AppTheme.primaryGold, fontWeight: FontWeight.bold)),
    content: Column(
      children: [
        TextField(
          controller: _notesCtrl,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'ملاحظات إضافية',
            filled: true,
            fillColor: AppTheme.surfaceBlack,
          ),
        ),
        const SizedBox(height: 15),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _submitting ? null : _submit,
            icon: const Icon(Icons.send),
            label: Text(_submitting ? 'جارٍ الإرسال...' : 'إرسال الطلب',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGold,
              foregroundColor: AppTheme.deepBlack,
              padding: const EdgeInsets.symmetric(vertical: 15),
            ),
          ),
        ),
      ],
    ),
    isActive: _currentStep >= 2,
  );

  Widget _dropdown(String label, List<String> items, Function(String) onSelected) {
    return DropdownButtonFormField<String>(
      initialValue: null,
      items: items.map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(),
      onChanged: (v) => onSelected(v!),
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AppTheme.surfaceBlack,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  List<String> get _categories {
    if (_selectedElement == 1) {
      return ['سيدان', 'دفع رباعي', 'هاتشباك', 'كوبيه', 'مكشوفة', 'شاحنة صغيرة', 'ميكروباص', 'فان'];
    }
    return ['شقة سكنية', 'دار عربي', 'فيلا', 'مزرعة', 'محل تجاري', 'أرض', 'بناء كامل', 'سطح'];
  }
}
