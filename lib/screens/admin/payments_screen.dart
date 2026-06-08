import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/network/supabase_service.dart';
import '../../providers/admin_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/payment_model.dart';
import '../../core/theme/app_theme.dart';
import '../../services/storage_service.dart';

/// 💰 إدارة المدفوعات — موافقة/رفض + تفعيل الباقات
class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  List<PaymentModel> _all = [];
  bool _loading = true;
  int _filter = 0; // 0=معلّق(افتراضي), -1=الكل, 1=مقبول, 2=مرفوض

  static const _pkgNames = {0: 'مجاني', 1: 'فضي', 2: 'ذهبي'};
  static const _stsNames = {0: 'معلّق', 1: 'مقبول', 2: 'مرفوض'};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await context.read<AdminProvider>().getAllPayments();
    if (mounted) {
      setState(() {
        _all = list;
        _loading = false;
      });
    }
  }

  List<PaymentModel> get _filtered =>
      _filter == -1 ? _all : _all.where((p) => p.sts == _filter).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.deepBlack,
      appBar: AppBar(
        title: const Text('المدفوعات'),
        backgroundColor: AppTheme.deepBlack,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.primaryGold),
            onPressed: _load,
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              children: [
                _chip('معلّق', 0),
                _chip('الكل', -1),
                _chip('مقبول', 1),
                _chip('مرفوض', 2),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppTheme.primaryGold))
                : _filtered.isEmpty
                    ? const Center(
                        child: Text('لا توجد مدفوعات',
                            style: TextStyle(color: AppTheme.textGrey)))
                    : RefreshIndicator(
                        color: AppTheme.primaryGold,
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _filtered.length,
                          itemBuilder: (_, i) => _payTile(_filtered[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, int value) {
    final selected = _filter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label,
            style: TextStyle(
              color: selected ? AppTheme.deepBlack : AppTheme.textWhite,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            )),
        selected: selected,
        selectedColor: AppTheme.primaryGold,
        backgroundColor: AppTheme.surfaceBlack,
        checkmarkColor: AppTheme.deepBlack,
        side: BorderSide(color: AppTheme.primaryGold.withValues(alpha: 0.3)),
        onSelected: (_) => setState(() => _filter = value),
      ),
    );
  }

  Color _stsColor(int sts) {
    switch (sts) {
      case 1:
        return Colors.green;
      case 2:
        return AppTheme.errorRed;
      default:
        return Colors.orange;
    }
  }

  Widget _payTile(PaymentModel p) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBlack,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primaryGold.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${p.amt.toStringAsFixed(0)} ${p.cur == 0 ? '\$' : 'ل.س'}',
                  style: const TextStyle(
                      color: AppTheme.primaryGold,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: _stsColor(p.sts).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _stsColor(p.sts).withValues(alpha: 0.5)),
                ),
                child: Text(_stsNames[p.sts] ?? '—',
                    style: TextStyle(color: _stsColor(p.sts), fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _row('المستخدم', _short(p.uid)),
          _row('الباقة', _pkgNames[p.pkg] ?? '—'),
          _row('قناة الدفع', p.channelDisplayName()),
          if (p.ref.isNotEmpty) _row('المرجع', p.ref),
          _row('التاريخ', p.tsCrt.toString().split(' ').first),
          if (p.proof.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: GestureDetector(
                onTap: () => _showProof(p.proof),
                child: const Row(
                  children: [
                    Icon(Icons.receipt_long, color: AppTheme.primaryGold, size: 16),
                    SizedBox(width: 4),
                    Text('عرض إثبات الدفع',
                        style: TextStyle(
                            color: AppTheme.primaryGold,
                            fontSize: 12,
                            decoration: TextDecoration.underline)),
                  ],
                ),
              ),
            ),
          if (p.sts == 0) ...[
            const Divider(color: Colors.white12, height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _approve(p),
                  icon: const Icon(Icons.check_circle, size: 18),
                  label: const Text('قبول وتفعيل'),
                  style: TextButton.styleFrom(foregroundColor: Colors.green),
                ),
                TextButton.icon(
                  onPressed: () => _reject(p),
                  icon: const Icon(Icons.cancel, size: 18),
                  label: const Text('رفض'),
                  style: TextButton.styleFrom(foregroundColor: AppTheme.errorRed),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// عرض إثبات الدفع — يدعم الحالتين:
  ///   1. URL كامل (سجلات قديمة من offer_images bucket عام)
  ///   2. path داخل bucket payment_proofs (خاص) → نولّد signed URL
  Future<void> _showProof(String proof) async {
    String? finalUrl;
    if (proof.startsWith('http')) {
      finalUrl = proof;
    } else {
      // path داخل payment_proofs → نولّد signed URL (صالح لساعة)
      try {
        finalUrl = await SupabaseService()
            .storage
            .from(StorageService.paymentProofsBucket)
            .createSignedUrl(proof, 3600);
      } catch (e) {_snack('فشل تحميل الإيصال');
        return;
      }
    }

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: AppTheme.surfaceBlack,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            InteractiveViewer(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Image.network(
                  finalUrl!,
                  errorBuilder: (_, __, ___) => const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('تعذّر تحميل الصورة',
                        style: TextStyle(color: AppTheme.textGrey)),
                  ),
                  loadingBuilder: (_, child, p) => p == null
                      ? child
                      : const Padding(
                          padding: EdgeInsets.all(40),
                          child: CircularProgressIndicator(
                              color: AppTheme.primaryGold),
                        ),
                ),
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
                style: IconButton.styleFrom(
                    backgroundColor: Colors.black54),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _approve(PaymentModel p) async {
    final adminId = context.read<AuthProvider>().userModel?.uid ?? '';
    if (await context
        .read<AdminProvider>()
        .approvePayment(p.id, adminId)) {
      _snack('تمت الموافقة وتفعيل الباقة');
      _load();
    }
  }

  Future<void> _reject(PaymentModel p) async {
    final adminId = context.read<AuthProvider>().userModel?.uid ?? '';
    if (await context.read<AdminProvider>().rejectPayment(p.id, adminId)) {
      _snack('تم رفض الدفعة');
      _load();
    }
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(color: AppTheme.textGrey, fontSize: 13)),
          Flexible(
            child: Text(value,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppTheme.textWhite, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  String _short(String s) => s.length >= 8 ? s.substring(0, 8) : s;

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
