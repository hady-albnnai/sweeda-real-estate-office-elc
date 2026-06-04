import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/request_provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/request_model.dart';

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

  Future<void> _submit() async {
    if (_selectedType == null || _clientNameCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إكمال البيانات الأساسية')));
      return;
    }
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final reqProv = Provider.of<RequestProvider>(context, listen: false);

    final request = RequestModel(
      id: '',
      typ: _selectedType!,
      elm: _selectedElement ?? 0,
      clNm: _clientNameCtrl.text,
      clPh: _clientPhoneCtrl.text,
      prc: double.tryParse(_priceCtrl.text) ?? 0,
      cur: 1,
      notes: _notesCtrl.text,
      specs: _specs,
      usrId: auth.userModel?.uid ?? '',
      sts: 0,
      tsCrt: DateTime.now(),
    );

    if (await reqProv.addRequest(request)) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إرسال طلبك بنجاح')));
      }
    }
  }

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
                    onPressed: details.onStepContinue,
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
            onPressed: _submit,
            icon: const Icon(Icons.send),
            label: const Text('إرسال الطلب', style: TextStyle(fontWeight: FontWeight.bold)),
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
      value: null,
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
