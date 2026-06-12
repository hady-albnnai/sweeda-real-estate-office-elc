import '../../models/user_model.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import '../../providers/offer_provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/db_constants.dart';
import '../../models/offer_model.dart';
import '../../services/storage_service.dart';

/// شاشة تعديل عرض موجود
class EditOfferScreen extends StatefulWidget {
  final String offerId;
  const EditOfferScreen({super.key, required this.offerId});

  @override
  State<EditOfferScreen> createState() => _EditOfferScreenState();
}

class _EditOfferScreenState extends State<EditOfferScreen> {
  OfferModel? _offer;
  bool _loading = true;
  bool _saving  = false;
  String _progress = '';

  final _titleCtrl       = TextEditingController();
  final _priceCtrl       = TextEditingController();
  final _locCtrl         = TextEditingController();
  final _descCtrl        = TextEditingController();
  final _contactPhCtrl   = TextEditingController(); // رقم التواصل
  final _specsCtrl       = TextEditingController(); // المواصفات

  int _typ = 0;
  int _trx = 0;
  int _cur = 1;

  // الصور الحالية + الجديدة
  final List<String> _existingImages = [];
  final List<XFile>  _newImages      = [];

  // المواعيد المتاحة (avl) — نفس بنية add_offer_screen
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

  final _storage = StorageService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadOffer());
  }

  @override
  void dispose() {
    _titleCtrl.dispose(); _priceCtrl.dispose(); _locCtrl.dispose();
    _descCtrl.dispose();  _contactPhCtrl.dispose(); _specsCtrl.dispose();
    super.dispose();
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

  void _loadAvl(Map<String, List<String>> avl) {
    for (final entry in avl.entries) {
      final key = entry.key;
      if (_avlDaysEnabled.containsKey(key) && entry.value.isNotEmpty) {
        _avlDaysEnabled[key] = true;
        _avlSlots[key] = entry.value.map((slot) {
          final parts = slot.split('-');
          return {'from': parts.isNotEmpty ? parts[0] : '', 'to': parts.length > 1 ? parts[1] : ''};
        }).toList();
      }
    }
  }

  Future<void> _loadOffer() async {
    final provider = context.read<OfferProvider>();
    final userId   = context.read<AuthProvider>().userModel?.uid;
    var offer = provider.getOfferById(widget.offerId);
    offer ??= await provider.fetchOfferById(widget.offerId, userId: userId);

    if (offer == null) {
      if (mounted) { setState(() => _loading = false); _snack('العرض غير موجود'); Navigator.pop(context); }
      return;
    }

    final auth = context.read<AuthProvider>();
    if (auth.userModel?.uid != offer.usrId && (auth.userModel?.role ?? 0) < UserRole.minAdmin) {
      _snack('ليس لديك صلاحية تعديل هذا العرض');
      if (mounted) Navigator.pop(context);
      return;
    }

    // منع تعديل العروض المحجوزة أو المكتملة
    if (offer.sts == 5 || offer.sts == 6) {
      _snack(offer.sts == 5 ? 'لا يمكن تعديل عرض محجوز — يوجد معاملة قيد الإتمام' : 'لا يمكن تعديل عرض مكتمل');
      if (mounted) Navigator.pop(context);
      return;
    }

    setState(() {
      _offer = offer;
      _titleCtrl.text     = offer!.ttl;
      _priceCtrl.text     = offer.prc.toStringAsFixed(0);
      _locCtrl.text       = (offer.loc['d'] ?? '').toString();
      _descCtrl.text      = offer.descript;
      _contactPhCtrl.text = offer.contactPh;
      _specsCtrl.text     = (offer.specs['details'] ?? '').toString();
      _typ = offer.typ;
      _trx = offer.trx;
      _cur = offer.cur;
      _existingImages.addAll(offer.imgs.map((e) => e.toString()));
      _loadAvl(offer.avl);
      _loading = false;
    });
  }

  Future<void> _pickImages() async {
    final total = _existingImages.length + _newImages.length;
    final remaining = StorageService.maxImages - total;
    if (remaining <= 0) { _snack('الحد الأقصى ${StorageService.maxImages} صور'); return; }
    final files = await _storage.pickMultiImages(limit: remaining);
    if (files.isNotEmpty) setState(() => _newImages.addAll(files));
  }

  void _removeExisting(int i) => setState(() => _existingImages.removeAt(i));
  void _removeNew(int i)      => setState(() => _newImages.removeAt(i));

  Future<void> _save() async {
    if (_offer == null) return;
    final auth     = context.read<AuthProvider>();
    final offerProv = context.read<OfferProvider>();
    final user     = auth.userModel;
    if (user == null) return;

    if (_titleCtrl.text.trim().isEmpty || _priceCtrl.text.trim().isEmpty) {
      _snack('يرجى إكمال العنوان والسعر'); return;
    }
    if (_contactPhCtrl.text.trim().isEmpty) {
      _snack('رقم الهاتف للتواصل إلزامي'); return;
    }

    setState(() { _saving = true; _progress = 'جارٍ رفع الصور الجديدة...'; });

    List<String> newUrls = [];
    if (_newImages.isNotEmpty) {
      newUrls = await _storage.uploadOfferImages(
        files: _newImages,
        userId: user.uid,
        offerId: _offer!.id,
        onProgress: (d, t) {
          if (mounted) setState(() => _progress = 'جارٍ رفع الصور ($d/$t)...');
        },
      );
    }

    setState(() => _progress = 'جارٍ حفظ التعديلات...');

    final allImages = [..._existingImages, ...newUrls];
    final specsText = _specsCtrl.text.trim();

    // offers لا يحتوي ts_upd — لا نرسله
    final updateData = {
      'ttl':        _titleCtrl.text.trim(),
      'prc':        double.tryParse(_priceCtrl.text) ?? _offer!.prc,
      'loc':        {'r': _offer!.loc['r'] ?? 0, 'd': _locCtrl.text.trim(), 'city': _offer!.loc['city'] ?? ''},
      'descript':   _descCtrl.text.trim(),
      'contact_ph': _contactPhCtrl.text.trim(),
      'specs':      {'details': specsText},
      'typ':        _typ,
      'trx':        _trx,
      'cur':        _cur,
      'imgs':       allImages,
      'avl':        _buildAvl(),
      // أي تعديل يعيد العرض إلى مسار مراجعة المكتب
      'sts':        OfferStatus.review,
      'i_pub':      0,
      'ts_pub':     null,
    };

    final ok = await offerProv.updateOffer(_offer!.id, updateData);

    if (!mounted) return;
    setState(() => _saving = false);

    if (ok) {
      _snack('تم حفظ التعديلات ✅ (سيُراجَع العرض من جديد)');
      Navigator.pop(context, true);
    } else {
      _snack('فشل حفظ التعديلات');
    }
  }

  Future<void> _renew() async {
    if (_offer == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surfaceBlack,
        title: const Text('تجديد العرض', style: TextStyle(color: AppTheme.textWhite)),
        content: const Text(
          'تجديد العرض يتم عبر نظام الترقيات بالنقاط.\n\nهل تريد فتح شاشة الترقية الآن؟',
          style: TextStyle(color: AppTheme.textGrey),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء', style: TextStyle(color: AppTheme.textGrey))),
          ElevatedButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('فتح الترقية')),
        ],
      ),
    );
    if (confirmed == true && mounted) context.push('/user/boost-offer/${_offer!.id}');
  }

  Future<void> _confirmDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surfaceBlack,
        title: const Text('حذف العرض', style: TextStyle(color: AppTheme.textWhite)),
        content: const Text('هل أنت متأكد من حذف هذا العرض؟ لا يمكن التراجع.',
            style: TextStyle(color: AppTheme.textGrey)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء', style: TextStyle(color: AppTheme.textGrey))),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('حذف', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final offerProv = context.read<OfferProvider>();
    setState(() { _saving = true; _progress = 'جارٍ الحذف...'; });
    final ok = await offerProv.softDeleteOffer(_offer!.id);
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) { _snack('تم حذف العرض'); Navigator.pop(context, true); }
    else    { _snack('فشل الحذف'); }
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppTheme.deepBlack,
        body: Center(child: CircularProgressIndicator(color: AppTheme.primaryGold)),
      );
    }
    if (_offer == null) {
      return const Scaffold(
        backgroundColor: AppTheme.deepBlack,
        body: Center(child: Text('العرض غير موجود', style: TextStyle(color: AppTheme.textGrey))),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.deepBlack,
      appBar: AppBar(
        title: const Text('تعديل العرض'),
        backgroundColor: AppTheme.deepBlack,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: _saving ? null : _confirmDelete,
          ),
        ],
      ),
      body: Stack(children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _statusBanner(),
            const SizedBox(height: 20),

            // ── العنوان ──
            _label('عنوان العرض'),
            TextField(controller: _titleCtrl,
                style: const TextStyle(color: AppTheme.textWhite),
                decoration: const InputDecoration(border: OutlineInputBorder())),
            const SizedBox(height: 16),

            // ── السعر + العملة ──
            _label('السعر'),
            Row(children: [
              Expanded(flex: 3, child: TextField(
                controller: _priceCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: AppTheme.textWhite),
                decoration: const InputDecoration(border: OutlineInputBorder()),
              )),
              const SizedBox(width: 10),
              Expanded(flex: 2, child: DropdownButtonFormField<int>(
                value: _cur,
                dropdownColor: AppTheme.surfaceBlack,
                style: const TextStyle(color: AppTheme.textWhite),
                items: const [
                  DropdownMenuItem(value: Currency.dollar, child: Text('دولار')),
                  DropdownMenuItem(value: Currency.lbp,    child: Text('ل.س')),
                ],
                onChanged: (v) => setState(() => _cur = v ?? Currency.lbp),
              )),
            ]),
            const SizedBox(height: 16),

            // ── رقم التواصل ──
            _label('رقم الهاتف للتواصل (إلزامي)'),
            TextField(
              controller: _contactPhCtrl,
              keyboardType: TextInputType.phone,
              style: const TextStyle(color: AppTheme.textWhite),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'مثال: 0938862469',
                hintStyle: TextStyle(color: AppTheme.textGrey),
              ),
            ),
            const SizedBox(height: 16),

            // ── الموقع ──
            _label('الموقع'),
            TextField(controller: _locCtrl,
                style: const TextStyle(color: AppTheme.textWhite),
                decoration: const InputDecoration(border: OutlineInputBorder())),
            const SizedBox(height: 16),

            // ── نوع العرض ──
            _label('نوع العرض'),
            Row(children: [
              Expanded(child: _radioChip('عقار',  _typ == 0, () => setState(() => _typ = 0))),
              const SizedBox(width: 10),
              Expanded(child: _radioChip('سيارة', _typ == 1, () => setState(() => _typ = 1))),
            ]),
            const SizedBox(height: 12),

            // ── نوع المعاملة ──
            _label('نوع المعاملة'),
            Row(children: [
              Expanded(child: _radioChip('بيع',    _trx == 0, () => setState(() => _trx = 0))),
              const SizedBox(width: 10),
              Expanded(child: _radioChip('إيجار', _trx == 1, () => setState(() => _trx = 1))),
            ]),
            const SizedBox(height: 16),

            // ── الوصف ──
            _label('الوصف التفصيلي'),
            TextField(
              controller: _descCtrl,
              maxLines: 4,
              style: const TextStyle(color: AppTheme.textWhite),
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),

            // ── المواصفات ──
            _label('المواصفات التقنية (اختيارية)'),
            TextField(
              controller: _specsCtrl,
              maxLines: 3,
              style: const TextStyle(color: AppTheme.textWhite),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'مثال: 3 غرف، 2 حمام، مساحة 150م²...',
                hintStyle: TextStyle(color: AppTheme.textGrey),
              ),
            ),
            const SizedBox(height: 20),

            // ── المواعيد المتاحة (avl) ──
            _label('المواعيد المتاحة للمعاينة'),
            const Text('حدد الأيام والفترات الزمنية المتاحة',
                style: TextStyle(color: AppTheme.textGrey, fontSize: 12)),
            const SizedBox(height: 10),
            ..._weekDays.map((day) => _avlDayWidget(day.$1, day.$2)),
            const SizedBox(height: 20),

            // ── الصور ──
            _label('الصور (${_existingImages.length + _newImages.length}/${StorageService.maxImages})'),
            const SizedBox(height: 8),
            _imagesGrid(),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickImages,
              icon: const Icon(Icons.add_photo_alternate, color: AppTheme.primaryGold),
              label: const Text('إضافة صور', style: TextStyle(color: AppTheme.primaryGold)),
              style: OutlinedButton.styleFrom(side: const BorderSide(color: AppTheme.primaryGold)),
            ),
            const SizedBox(height: 24),

            // ── أزرار ──
            Row(children: [
              Expanded(child: OutlinedButton.icon(
                onPressed: _saving ? null : _renew,
                icon: const Icon(Icons.refresh, color: AppTheme.primaryGold),
                label: const Text('تجديد العرض', style: TextStyle(color: AppTheme.primaryGold)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: AppTheme.primaryGold),
                ),
              )),
              const SizedBox(width: 12),
              Expanded(child: ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.save, color: Colors.black),
                label: const Text('حفظ التعديلات',
                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              )),
            ]),
            const SizedBox(height: 24),
          ]),
        ),
        if (_saving)
          Container(
            color: Colors.black.withValues(alpha: 0.7),
            child: Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(color: AppTheme.primaryGold),
                const SizedBox(height: 16),
                Text(_progress, style: const TextStyle(color: AppTheme.textWhite)),
              ],
            )),
          ),
      ]),
    );
  }

  // ── واجهة avl لكل يوم ──
  Widget _avlDayWidget(String key, String label) {
    final enabled = _avlDaysEnabled[key] ?? false;
    final slots   = _avlSlots[key] ?? [];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBlack,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: enabled ? AppTheme.primaryGold.withValues(alpha: 0.5) : Colors.white12,
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InkWell(
          onTap: () => setState(() {
            _avlDaysEnabled[key] = !enabled;
            if (!enabled && slots.isEmpty) _avlSlots[key]!.add({'from': '', 'to': ''});
          }),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(children: [
              Icon(enabled ? Icons.check_box : Icons.check_box_outline_blank,
                  color: enabled ? AppTheme.primaryGold : AppTheme.textGrey, size: 20),
              const SizedBox(width: 10),
              Text(label, style: TextStyle(
                  color: enabled ? AppTheme.textWhite : AppTheme.textGrey,
                  fontWeight: FontWeight.bold)),
              const Spacer(),
              if (enabled)
                TextButton.icon(
                  onPressed: () => setState(() => _avlSlots[key]!.add({'from': '', 'to': ''})),
                  icon: const Icon(Icons.add, size: 16, color: AppTheme.primaryGold),
                  label: const Text('فترة', style: TextStyle(color: AppTheme.primaryGold, fontSize: 12)),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                ),
            ]),
          ),
        ),
        if (enabled)
          ...slots.asMap().entries.map((e) {
            final i    = e.key;
            final slot = e.value;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(children: [
                const Text('من', style: TextStyle(color: AppTheme.textGrey, fontSize: 13)),
                const SizedBox(width: 6),
                Expanded(child: _timeField(
                  value: slot['from'] ?? '', hint: '09:00',
                  onChanged: (v) => setState(() => _avlSlots[key]![i]['from'] = v),
                )),
                const SizedBox(width: 8),
                const Text('إلى', style: TextStyle(color: AppTheme.textGrey, fontSize: 13)),
                const SizedBox(width: 6),
                Expanded(child: _timeField(
                  value: slot['to'] ?? '', hint: '12:00',
                  onChanged: (v) => setState(() => _avlSlots[key]![i]['to'] = v),
                )),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.remove_circle, color: Colors.red, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => setState(() {
                    _avlSlots[key]!.removeAt(i);
                    if (_avlSlots[key]!.isEmpty) _avlDaysEnabled[key] = false;
                  }),
                ),
              ]),
            );
          }),
        if (enabled) const SizedBox(height: 8),
      ]),
    );
  }

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

  Widget _statusBanner() {
    final info = _statusText(_offer!.sts);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: info.$2.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: info.$2.withValues(alpha: 0.5)),
      ),
      child: Row(children: [
        Icon(info.$3, color: info.$2),
        const SizedBox(width: 10),
        Expanded(child: Text('الحالة الحالية: ${info.$1}',
            style: TextStyle(color: info.$2, fontWeight: FontWeight.bold))),
      ]),
    );
  }

  (String, Color, IconData) _statusText(int s) {
    switch (s) {
      case 0: return ('مسودة',          Colors.grey,   Icons.edit);
      case 1: return ('قيد المراجعة',   Colors.orange, Icons.hourglass_empty);
      case 2: return ('منشور',          Colors.green,  Icons.check_circle);
      case 3: return ('مرفوض',          Colors.red,    Icons.cancel);
      case 4: return ('منتهي',          Colors.grey,   Icons.timer_off);
      case 5: return ('محجوز',          Colors.blue,   Icons.lock_clock);
      case 6: return ('مكتمل',          Colors.teal,   Icons.done_all);
      default: return ('غير معروف',     Colors.grey,   Icons.help);
    }
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text,
        style: const TextStyle(color: AppTheme.primaryGold, fontWeight: FontWeight.bold)),
  );

  Widget _radioChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryGold : AppTheme.surfaceBlack,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? AppTheme.primaryGold : AppTheme.textGrey),
        ),
        child: Center(child: Text(label,
            style: TextStyle(
              color: selected ? Colors.black : AppTheme.textWhite,
              fontWeight: FontWeight.bold,
            ))),
      ),
    );
  }

  Widget _imagesGrid() {
    final items = <Widget>[];
    for (var i = 0; i < _existingImages.length; i++) {
      items.add(_imageTile(
        Image.network(_existingImages[i], fit: BoxFit.cover),
        () => _removeExisting(i), 'موجودة',
      ));
    }
    for (var i = 0; i < _newImages.length; i++) {
      items.add(_imageTile(
        kIsWeb
            ? Image.network(_newImages[i].path, fit: BoxFit.cover)
            : Image.file(File(_newImages[i].path), fit: BoxFit.cover),
        () => _removeNew(i), 'جديدة',
      ));
    }
    if (items.isEmpty) {
      return Container(
        height: 80,
        decoration: BoxDecoration(
          color: AppTheme.surfaceBlack, borderRadius: BorderRadius.circular(10)),
        child: const Center(child: Text('لا توجد صور',
            style: TextStyle(color: AppTheme.textGrey))),
      );
    }
    return GridView.count(
      crossAxisCount: 3, shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8, crossAxisSpacing: 8,
      children: items,
    );
  }

  Widget _imageTile(Widget image, VoidCallback onRemove, String tag) {
    return Stack(children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(width: double.infinity, height: double.infinity, child: image),
      ),
      Positioned(top: 4, right: 4,
        child: GestureDetector(
          onTap: onRemove,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
            child: const Icon(Icons.close, color: Colors.white, size: 14),
          ),
        ),
      ),
      Positioned(bottom: 4, left: 4,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: tag == 'جديدة' ? Colors.green : Colors.blue,
            borderRadius: BorderRadius.circular(6)),
          child: Text(tag, style: const TextStyle(color: Colors.white, fontSize: 10)),
        ),
      ),
    ]);
  }
}
