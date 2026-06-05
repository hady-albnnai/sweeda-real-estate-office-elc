import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/payment_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/payment_model.dart';
import '../../services/storage_service.dart';
import '../../core/network/supabase_service.dart';

/// شاشة دفع اشتراك الباقة
/// يستقبل: pkg (رقم الباقة) + amt (المبلغ)
class PaymentScreen extends StatefulWidget {
  final int packageId;
  final double amount;

  const PaymentScreen({
    super.key,
    required this.packageId,
    required this.amount,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  int _method = 0; // 0=تحويل بنكي, 1=محفظة, 2=نقداً بالمكتب
  int _currency = 0; // 0=$, 1=ل.س
  final _refCtrl = TextEditingController();
  XFile? _proofImage;
  bool _uploading = false;
  String _progress = '';

  final _storage = StorageService();

  static const Map<int, String> _methodNames = {
    0: 'تحويل بنكي',
    1: 'محفظة إلكترونية',
    2: 'نقداً بالمكتب',
  };

  @override
  void dispose() {
    _refCtrl.dispose();
    super.dispose();
  }

  String get _packageName {
    switch (widget.packageId) {
      case 1:
        return 'الفضية';
      case 2:
        return 'الذهبية';
      default:
        return '';
    }
  }

  Future<void> _pickProof() async {
    final file = await _storage.pickImage(fromCamera: false);
    if (file != null) {
      setState(() => _proofImage = file);
    }
  }

  Future<String?> _uploadProof(String userId) async {
    if (_proofImage == null) return null;
    try {
      final storage = SupabaseService().storage;
      final fileName =
          'proof_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final path = 'payments/$userId/$fileName';

      final bytes = kIsWeb
          ? await _proofImage!.readAsBytes()
          : await (await _storage
                      .compressImage(File(_proofImage!.path)) ??
                  File(_proofImage!.path))
              .readAsBytes();

      // نستخدم نفس bucket offer_images مؤقتاً لتفادي إنشاء bucket جديد
      // إذا أردت bucket مستقل، أنشئ "payment_proofs" في Supabase Storage
      await storage.from(StorageService.offerBucket).uploadBinary(
            path,
            bytes,
            fileOptions:
                const FileOptions(cacheControl: '3600', upsert: true),
          );
      return storage.from(StorageService.offerBucket).getPublicUrl(path);
    } catch (e) {
      debugPrint('❌ uploadProof error: $e');
      return null;
    }
  }

  Future<void> _submit() async {
    final auth = context.read<AuthProvider>();
    final paymentProv = context.read<PaymentProvider>();
    final user = auth.userModel;

    if (user == null) {
      _snack('يجب تسجيل الدخول أولاً');
      return;
    }
    if (_method != 2 && _proofImage == null) {
      _snack('يرجى رفع إثبات الدفع');
      return;
    }
    if (_method != 2 && _refCtrl.text.trim().isEmpty) {
      _snack('يرجى إدخال رقم المرجع / الإشعار');
      return;
    }

    setState(() {
      _uploading = true;
      _progress = 'جارٍ رفع إثبات الدفع...';
    });

    String proofUrl = '';
    if (_proofImage != null) {
      final url = await _uploadProof(user.uid);
      if (url == null) {
        setState(() => _uploading = false);
        _snack('فشل رفع الإثبات، حاول مرة أخرى');
        return;
      }
      proofUrl = url;
    }

    setState(() => _progress = 'جارٍ تسجيل الدفعة...');

    final payment = PaymentModel(
      id: '',
      uid: user.uid,
      tp: 0, // 0 = اشتراك باقة
      pkg: widget.packageId,
      amt: widget.amount,
      cur: _currency,
      mtd: _method,
      proof: proofUrl,
      ref: _refCtrl.text.trim(),
      sts: 0, // قيد المراجعة
      tsCrt: DateTime.now(),
    );

    final ok = await paymentProv.makePayment(payment);

    if (!mounted) return;
    setState(() => _uploading = false);

    if (ok) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          backgroundColor: AppTheme.surfaceBlack,
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 28),
              SizedBox(width: 8),
              Text('تم بنجاح', style: TextStyle(color: AppTheme.textWhite)),
            ],
          ),
          content: const Text(
            'تم تسجيل دفعتك بنجاح ✅\n\nستراجعها الإدارة خلال 24 ساعة وستصلك رسالة عند التفعيل.',
            style: TextStyle(color: AppTheme.textGrey),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                context.go('/user/home');
              },
              child: const Text('حسناً',
                  style: TextStyle(color: AppTheme.primaryGold)),
            ),
          ],
        ),
      );
    } else {
      _snack('حدث خطأ، حاول مرة أخرى');
    }
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.deepBlack,
      appBar: AppBar(
        title: const Text('دفع الاشتراك'),
        backgroundColor: AppTheme.deepBlack,
        elevation: 0,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _summaryCard(),
                const SizedBox(height: 20),
                _sectionTitle('🏦 طريقة الدفع'),
                ..._methodNames.entries.map((e) => _methodRadio(e.key, e.value)),
                const SizedBox(height: 16),
                _sectionTitle('💱 العملة'),
                Row(
                  children: [
                    Expanded(child: _currencyTile(0, 'دولار \$')),
                    const SizedBox(width: 10),
                    Expanded(child: _currencyTile(1, 'ليرة سورية')),
                  ],
                ),
                const SizedBox(height: 20),
                if (_method != 2) ...[
                  _sectionTitle('🔢 رقم المرجع / الإشعار'),
                  TextField(
                    controller: _refCtrl,
                    style: const TextStyle(color: AppTheme.textWhite),
                    decoration: const InputDecoration(
                      hintText: 'مثلاً: TRX-123456',
                      prefixIcon:
                          Icon(Icons.tag, color: AppTheme.primaryGold),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _sectionTitle('📷 إثبات الدفع'),
                  GestureDetector(
                    onTap: _pickProof,
                    child: Container(
                      height: 180,
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceBlack,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _proofImage != null
                              ? Colors.green
                              : AppTheme.primaryGold.withOpacity(0.4),
                          width: 1.5,
                        ),
                      ),
                      child: _proofImage == null
                          ? const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.upload_file,
                                      color: AppTheme.primaryGold, size: 48),
                                  SizedBox(height: 8),
                                  Text(
                                    'اضغط لرفع صورة إيصال التحويل',
                                    style: TextStyle(
                                        color: AppTheme.textGrey,
                                        fontSize: 13),
                                  ),
                                ],
                              ),
                            )
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(11),
                              child: kIsWeb
                                  ? Image.network(_proofImage!.path,
                                      fit: BoxFit.cover,
                                      width: double.infinity)
                                  : Image.file(File(_proofImage!.path),
                                      fit: BoxFit.cover,
                                      width: double.infinity),
                            ),
                    ),
                  ),
                  if (_proofImage != null)
                    TextButton.icon(
                      onPressed: () => setState(() => _proofImage = null),
                      icon: const Icon(Icons.close, color: Colors.red),
                      label: const Text('إزالة الصورة',
                          style: TextStyle(color: Colors.red)),
                    ),
                ] else
                  _cashNote(),
                const SizedBox(height: 20),
                _bankInfoCard(),
                const SizedBox(height: 24),
                SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _uploading ? null : _submit,
                    icon: const Icon(Icons.check, color: Colors.black),
                    label: const Text('تأكيد الدفع',
                        style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
          if (_uploading)
            Container(
              color: Colors.black.withOpacity(0.7),
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

  Widget _summaryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFD4AF37), Color(0xFFFFD700)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('الاشتراك بالباقة',
              style: TextStyle(color: Colors.black87, fontSize: 13)),
          Text(_packageName,
              style: const TextStyle(
                  color: Colors.black,
                  fontSize: 24,
                  fontWeight: FontWeight.bold)),
          const Divider(color: Colors.black26, height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('المبلغ المطلوب:',
                  style: TextStyle(color: Colors.black87)),
              Text(
                '\$${widget.amount.toStringAsFixed(0)}',
                style: const TextStyle(
                    color: Colors.black,
                    fontSize: 22,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 4),
        child: Text(text,
            style: const TextStyle(
                color: AppTheme.primaryGold,
                fontWeight: FontWeight.bold,
                fontSize: 14)),
      );

  Widget _methodRadio(int id, String name) {
    final selected = _method == id;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBlack,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: selected
                ? AppTheme.primaryGold
                : Colors.transparent),
      ),
      child: RadioListTile<int>(
        value: id,
        groupValue: _method,
        onChanged: (v) => setState(() => _method = v!),
        title: Text(name,
            style: const TextStyle(color: AppTheme.textWhite)),
        activeColor: AppTheme.primaryGold,
      ),
    );
  }

  Widget _currencyTile(int id, String label) {
    final selected = _currency == id;
    return GestureDetector(
      onTap: () => setState(() => _currency = id),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primaryGold
              : AppTheme.surfaceBlack,
          borderRadius: BorderRadius.circular(10),
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

  Widget _cashNote() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.withOpacity(0.5)),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: Colors.orange),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'الدفع نقداً يتم في المكتب — اضغط "تأكيد" لحجز الاشتراك وزيارتنا خلال 48 ساعة.',
              style: TextStyle(color: AppTheme.textWhite, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bankInfoCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBlack,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryGold.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.account_balance,
                  color: AppTheme.primaryGold, size: 20),
              SizedBox(width: 8),
              Text('معلومات الحساب البنكي',
                  style: TextStyle(
                      color: AppTheme.primaryGold,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const Divider(color: AppTheme.textGrey, height: 16),
          _kv('البنك', 'بنك السلام – فرع السويداء'),
          _kv('الحساب', '1234-5678-9012-3456'),
          _kv('الاسم', 'المكتب العقاري الإلكتروني'),
          _kv('SWIFT', 'SLAMSYDA'),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(k,
                style: const TextStyle(
                    color: AppTheme.textGrey, fontSize: 12)),
          ),
          Expanded(
            child: SelectableText(
              v,
              style: const TextStyle(
                  color: AppTheme.textWhite,
                  fontSize: 13,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
