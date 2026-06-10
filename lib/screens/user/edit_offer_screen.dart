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
/// تتلقّى offerId وتحمل البيانات الحالية للتعديل
class EditOfferScreen extends StatefulWidget {
  final String offerId;
  const EditOfferScreen({super.key, required this.offerId});

  @override
  State<EditOfferScreen> createState() => _EditOfferScreenState();
}

class _EditOfferScreenState extends State<EditOfferScreen> {
  OfferModel? _offer;
  bool _loading = true;
  bool _saving = false;
  String _progress = '';

  final _titleCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _locCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  int _typ = 0;
  int _trx = 0;
  int _cur = 0;

  // الصور الحالية (URLs) + صور جديدة محلية
  final List<String> _existingImages = [];
  final List<XFile> _newImages = [];

  final _storage = StorageService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadOffer());
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _priceCtrl.dispose();
    _locCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadOffer() async {
    final provider = context.read<OfferProvider>();
    var offer = provider.getOfferById(widget.offerId);
    offer ??= await provider.fetchOfferById(widget.offerId);

    if (offer == null) {
      if (mounted) {
        setState(() => _loading = false);
        _snack('العرض غير موجود');
        Navigator.pop(context);
      }
      return;
    }

    // تحقّق ملكية العرض
    final auth = context.read<AuthProvider>();
    if (auth.userModel?.uid != offer.usrId) {
      _snack('ليس لديك صلاحية تعديل هذا العرض');
      if (mounted) Navigator.pop(context);
      return;
    }

    setState(() {
      _offer = offer;
      _titleCtrl.text = offer!.ttl;
      _priceCtrl.text = offer.prc.toStringAsFixed(0);
      _locCtrl.text = (offer.loc['d'] ?? '').toString();
      _descCtrl.text = offer.descript;
      _typ = offer.typ;
      _trx = offer.trx;
      _cur = offer.cur;
      _existingImages.addAll(offer.imgs.map((e) => e.toString()));
      _loading = false;
    });
  }

  Future<void> _pickImages() async {
    final total = _existingImages.length + _newImages.length;
    final remaining = StorageService.maxImages - total;
    if (remaining <= 0) {
      _snack('الحد الأقصى ${StorageService.maxImages} صور');
      return;
    }
    final files = await _storage.pickMultiImages(limit: remaining);
    if (files.isNotEmpty) {
      setState(() => _newImages.addAll(files));
    }
  }

  void _removeExisting(int i) =>
      setState(() => _existingImages.removeAt(i));

  void _removeNew(int i) => setState(() => _newImages.removeAt(i));

  Future<void> _save() async {
    if (_offer == null) return;
    final auth = context.read<AuthProvider>();
    final offerProv = context.read<OfferProvider>();
    final user = auth.userModel;

    if (user == null) return;

    if (_titleCtrl.text.trim().isEmpty || _priceCtrl.text.trim().isEmpty) {
      _snack('يرجى إكمال العنوان والسعر');
      return;
    }

    setState(() {
      _saving = true;
      _progress = 'جارٍ رفع الصور الجديدة...';
    });

    // 1) رفع الصور الجديدة
    List<String> newUrls = [];
    if (_newImages.isNotEmpty) {
      newUrls = await _storage.uploadOfferImages(
        files: _newImages,
        userId: user.uid,
        offerId: _offer!.id,
        onProgress: (d, t) {
          if (mounted) {
            setState(() => _progress = 'جارٍ رفع الصور ($d/$t)...');
          }
        },
      );
    }

    setState(() => _progress = 'جارٍ حفظ التعديلات...');

    // 2) دمج الصور (الموجودة + الجديدة)
    final allImages = [..._existingImages, ...newUrls];

    final updateData = {
      'ttl': _titleCtrl.text.trim(),
      'prc': double.tryParse(_priceCtrl.text) ?? _offer!.prc,
      'loc': {'r': _offer!.loc['r'] ?? 0, 'd': _locCtrl.text.trim()},
      'descript': _descCtrl.text.trim(),
      'typ': _typ,
      'trx': _trx,
      'cur': _cur,
      'imgs': allImages,
      'ts_upd': DateTime.now().toIso8601String(),
      // أي تعديل يعيد العرض إلى مسار مراجعة المكتب.
      'sts': OfferStatus.review,
      'i_pub': 0,
      'ts_pub': null,
    };

    final ok = await offerProv.updateOffer(_offer!.id, updateData);

    if (!mounted) return;
    setState(() => _saving = false);

    if (ok) {
      _snack('تم حفظ التعديلات بنجاح ✅ (سيُراجَع العرض من جديد)');
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
        title: const Text('تجديد العرض',
            style: TextStyle(color: AppTheme.textWhite)),
        content: const Text(
          'تجديد العرض يتم عبر نظام الترقيات بالنقاط حتى يبقى تحت منطق المكتب والسيرفر.\n\nهل تريد فتح شاشة الترقية الآن؟',
          style: TextStyle(color: AppTheme.textGrey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء',
                style: TextStyle(color: AppTheme.textGrey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('فتح الترقية'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      context.push('/user/boost-offer/${_offer!.id}');
    }
  }

  Future<void> _confirmDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surfaceBlack,
        title: const Text('حذف العرض',
            style: TextStyle(color: AppTheme.textWhite)),
        content: const Text(
          'هل أنت متأكد من حذف هذا العرض؟ هذا الإجراء لا يمكن التراجع عنه.',
          style: TextStyle(color: AppTheme.textGrey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء',
                style: TextStyle(color: AppTheme.textGrey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;
    final offerProv = context.read<OfferProvider>();
    setState(() {
      _saving = true;
      _progress = 'جارٍ الحذف...';
    });
    final ok = await offerProv.softDeleteOffer(_offer!.id);
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      _snack('تم حذف العرض');
      Navigator.pop(context, true);
    } else {
      _snack('فشل الحذف');
    }
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
        body: Center(
            child: Text('العرض غير موجود',
                style: TextStyle(color: AppTheme.textGrey))),
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
            tooltip: 'حذف العرض',
            onPressed: _saving ? null : _confirmDelete,
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _statusBanner(),
                const SizedBox(height: 20),
                _label('عنوان العرض'),
                TextField(
                    controller: _titleCtrl,
                    style: const TextStyle(color: AppTheme.textWhite)),
                const SizedBox(height: 16),
                _label('السعر'),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _priceCtrl,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: AppTheme.textWhite),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<int>(
                        value: _cur,
                        dropdownColor: AppTheme.surfaceBlack,
                        style: const TextStyle(color: AppTheme.textWhite),
                        items: const [
                          DropdownMenuItem(value: 0, child: Text('دولار')),
                          DropdownMenuItem(value: 1, child: Text('ل.س')),
                        ],
                        onChanged: (v) => setState(() => _cur = v ?? 0),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _label('الموقع'),
                TextField(
                    controller: _locCtrl,
                    style: const TextStyle(color: AppTheme.textWhite)),
                const SizedBox(height: 16),
                _label('نوع العرض'),
                Row(
                  children: [
                    Expanded(child: _radioChip('عقار', _typ == 0, () => setState(() => _typ = 0))),
                    const SizedBox(width: 10),
                    Expanded(child: _radioChip('سيارة', _typ == 1, () => setState(() => _typ = 1))),
                  ],
                ),
                const SizedBox(height: 12),
                _label('نوع المعاملة'),
                Row(
                  children: [
                    Expanded(child: _radioChip('بيع', _trx == 0, () => setState(() => _trx = 0))),
                    const SizedBox(width: 10),
                    Expanded(child: _radioChip('إيجار', _trx == 1, () => setState(() => _trx = 1))),
                  ],
                ),
                const SizedBox(height: 16),
                _label('الوصف'),
                TextField(
                  controller: _descCtrl,
                  maxLines: 4,
                  style: const TextStyle(color: AppTheme.textWhite),
                ),
                const SizedBox(height: 20),
                _label('الصور (${_existingImages.length + _newImages.length}/${StorageService.maxImages})'),
                const SizedBox(height: 8),
                _imagesGrid(),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _pickImages,
                  icon: const Icon(Icons.add_photo_alternate,
                      color: AppTheme.primaryGold),
                  label: const Text('إضافة صور',
                      style: TextStyle(color: AppTheme.primaryGold)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.primaryGold),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _saving ? null : _renew,
                        icon: const Icon(Icons.refresh,
                            color: AppTheme.primaryGold),
                        label: const Text('تجديد العرض',
                            style: TextStyle(color: AppTheme.primaryGold)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: AppTheme.primaryGold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: const Icon(Icons.save, color: Colors.black),
                        label: const Text('حفظ التعديلات',
                            style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
          if (_saving)
            Container(
              color: Colors.black.withValues(alpha: 0.7),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(
                        color: AppTheme.primaryGold),
                    const SizedBox(height: 16),
                    Text(_progress,
                        style: const TextStyle(color: AppTheme.textWhite)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _statusBanner() {
    final statusInfo = _statusText(_offer!.sts);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: statusInfo.$2.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: statusInfo.$2.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(statusInfo.$3, color: statusInfo.$2),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'الحالة الحالية: ${statusInfo.$1}',
              style: TextStyle(
                  color: statusInfo.$2, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  (String, Color, IconData) _statusText(int s) {
    switch (s) {
      case 0:
        return ('مسودة', Colors.grey, Icons.edit);
      case 1:
        return ('قيد المراجعة', Colors.orange, Icons.hourglass_empty);
      case 2:
        return ('منشور', Colors.green, Icons.check_circle);
      case 3:
        return ('مرفوض', Colors.red, Icons.cancel);
      case 4:
        return ('منتهي', Colors.grey, Icons.timer_off);
      case 5:
        return ('محجوز', Colors.blue, Icons.lock_clock);
      case 6:
        return ('مكتمل', Colors.teal, Icons.done_all);
      default:
        return ('غير معروف', Colors.grey, Icons.help);
    }
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(
                color: AppTheme.primaryGold, fontWeight: FontWeight.bold)),
      );

  Widget _radioChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryGold : AppTheme.surfaceBlack,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: selected ? AppTheme.primaryGold : AppTheme.textGrey),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.black : AppTheme.textWhite,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _imagesGrid() {
    final items = <Widget>[];
    for (var i = 0; i < _existingImages.length; i++) {
      items.add(_imageTile(
        Image.network(_existingImages[i], fit: BoxFit.cover),
        () => _removeExisting(i),
        'موجودة',
      ));
    }
    for (var i = 0; i < _newImages.length; i++) {
      items.add(_imageTile(
        kIsWeb
            ? Image.network(_newImages[i].path, fit: BoxFit.cover)
            : Image.file(File(_newImages[i].path), fit: BoxFit.cover),
        () => _removeNew(i),
        'جديدة',
      ));
    }

    if (items.isEmpty) {
      return Container(
        height: 80,
        decoration: BoxDecoration(
          color: AppTheme.surfaceBlack,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Center(
          child: Text('لا توجد صور — أضف صور لعرضك',
              style: TextStyle(color: AppTheme.textGrey)),
        ),
      );
    }

    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: items,
    );
  }

  Widget _imageTile(Widget image, VoidCallback onRemove, String tag) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: double.infinity,
            height: double.infinity,
            child: image,
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 14),
            ),
          ),
        ),
        Positioned(
          bottom: 4,
          left: 4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: tag == 'جديدة' ? Colors.green : Colors.blue,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(tag,
                style: const TextStyle(color: Colors.white, fontSize: 10)),
          ),
        ),
      ],
    );
  }
}
