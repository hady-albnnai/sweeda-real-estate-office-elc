import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/offer_provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/offer_model.dart';

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
  List<String> _selectedImages = [];
  Map<String, List<String>> _availability = {};

  void _next() => setState(() { if (_currentStep < 2) _currentStep++; });
  void _prev() => setState(() { if (_currentStep > 0) _currentStep--; });

  Future<void> _submit() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final offerProv = Provider.of<OfferProvider>(context, listen: false);
    if (_selectedType == null || _priceCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى إكمال البيانات الأساسية')));
      return;
    }
    final offer = OfferModel(
      id: '', usrId: auth.userModel?.uid ?? '',
      ttl: '${_selectedCat ?? 'عقار'} في ${_locCtrl.text}',
      typ: _selectedType!, trx: _selectedTrans ?? 0, cat: 0,
      prc: double.tryParse(_priceCtrl.text) ?? 0.0,
      loc: {'r': 0, 'd': _locCtrl.text},
      desc: _descCtrl.text, specs: {'details': _specCtrl.text},
      imgs: _selectedImages, sts: 0, iPUB: 0, avl: _availability,
      tsCrt: DateTime.now(), docTp: 0, brkId: '', brkPct: 0, sub: 0,
      cur: 1, vdo: '', docImg: '', exactLoc: '', com: 0, rsn: '',
      vws: 0, fvs: 0, iSoc: 0, socPub: 0, socTxt: '', iDup: 0, dupOf: '', iDel: 0,
    );
    if (await offerProv.addOffer(offer)) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إرسال عرضك للمراجعة بنجاح')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('إضافة عرض جديد'), backgroundColor: Colors.transparent),
    body: Stepper(type: StepperType.vertical, currentStep: _currentStep,
      onStepTapped: (s) => setState(() => _currentStep = s),
      onStepContinue: _next, onStepCancel: _prev,
      steps: [_step1(), _step2(), _step3()]),
  );

  Step _step1() => Step(
    title: const Text('الأساسيات', style: TextStyle(color: AppTheme.primaryGold, fontWeight: FontWeight.bold)),
    content: Column(children: [
      _dd('نوع العرض', ['عقار','سيارة'], (v) => setState(() => _selectedType = v == 'عقار' ? 0 : 1)),
      const SizedBox(height: 20),
      _dd('نوع المعاملة', ['بيع','إيجار'], (v) => setState(() => _selectedTrans = v == 'بيع' ? 0 : 1)),
      const SizedBox(height: 20),
      _dd('التصنيف', ['شقة','فيلا','أرض','سيدان','SUV','دفع رباعي'], (v) => setState(() => _selectedCat = v)),
    ]),
    isActive: _currentStep >= 0,
  );

  Step _step2() => Step(
    title: const Text('التفاصيل', style: TextStyle(color: AppTheme.primaryGold, fontWeight: FontWeight.bold)),
    content: Column(children: [
      TextField(controller: _priceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'السعر المتوقع (ل.س)')),
      const SizedBox(height: 15),
      TextField(controller: _locCtrl, decoration: const InputDecoration(labelText: 'الموقع / المنطقة')),
      const SizedBox(height: 15),
      TextField(controller: _descCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'وصف مختصر')),
      const SizedBox(height: 15),
      TextField(controller: _specCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'المواصفات')),
    ]),
    isActive: _currentStep >= 1,
  );

  Step _step3() => Step(
    title: const Text('المرفقات والمواعيد', style: TextStyle(color: AppTheme.primaryGold, fontWeight: FontWeight.bold)),
    content: Column(children: [
      ElevatedButton.icon(onPressed: () => setState(() => _selectedImages.add('https://via.placeholder.com/150')),
        icon: const Icon(Icons.image), label: const Text('إضافة صور (حد أقصى 6)')),
      Wrap(children: _selectedImages.map((img) => Padding(padding: const EdgeInsets.all(5),
        child: Image.network(img, width: 60, height: 60, fit: BoxFit.cover))).toList()),
      const SizedBox(height: 20),
      SizedBox(width: double.infinity, height: 55, child: ElevatedButton(onPressed: _submit, child: const Text('نشر العرض الآن'))),
    ]),
    isActive: _currentStep >= 2,
  );

  Widget _dd(String label, List<String> items, Function(String) on) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [Text(label, style: const TextStyle(color: AppTheme.textGrey)), const SizedBox(height: 5),
      DropdownButtonFormField<String>(value: null,
        items: items.map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(),
        onChanged: (v) => on(v!), decoration: const InputDecoration(border: OutlineInputBorder()))]);
}
