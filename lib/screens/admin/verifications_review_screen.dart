import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../providers/admin_provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/network/supabase_service.dart';
import '../../services/storage_service.dart';

/// 🛡️ شاشة مراجعة طلبات التوثيق الرسمي للمستخدمين (vrf=1).
///
/// تعرض قائمة المستخدمين الذين رفعوا هويتهم وينتظرون اعتماد الإدارة،
/// مع صورة الهوية والاسم والرقم الوطني،
/// وأزرار "اعتماد" (vrf → 2) أو "رفض" (vrf → 0).
///
/// مرجع: docs/LOGIC_SPEC.md §2.1
class VerificationsReviewScreen extends StatefulWidget {
  const VerificationsReviewScreen({super.key});

  @override
  State<VerificationsReviewScreen> createState() =>
      _VerificationsReviewScreenState();
}

class _VerificationsReviewScreenState extends State<VerificationsReviewScreen> {
  List<Map<String, dynamic>> _pending = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final admin = context.read<AdminProvider>();
    final adminUid = context.read<AuthProvider>().userModel?.uid ?? '';
    final list = adminUid.isEmpty ? <Map<String, dynamic>>[] : await admin.getPendingVerifications(adminUid);
    if (mounted) {
      setState(() {
        _pending = list;
        _loading = false;
      });
    }
  }

  Future<void> _approve(String userId, String name) async {
    final adminUid = context.read<AuthProvider>().userModel?.uid ?? '';
    final ok = await context.read<AdminProvider>().approveVerification(adminUid, userId);
    if (!mounted) return;
    AppTheme.showSnackBar(context, SnackBar(
      content: Text(ok ? '✅ تم اعتماد توثيق $name' : '❌ فشل الاعتماد'),
      backgroundColor: ok ? Colors.green : Colors.red,
    ));
    if (ok) _load();
  }

  Future<void> _reject(String userId, String name) async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceBlack,
        title: const Text('رفض التوثيق',
            style: TextStyle(color: AppTheme.textWhite)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'سيُعاد $name إلى حالة "غير موثق" وسيصله إشعار. اذكر سبب الرفض (اختياري):',
              style: const TextStyle(color: AppTheme.textGrey),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: reasonCtrl,
              maxLines: 2,
              style: const TextStyle(color: AppTheme.textWhite),
              decoration: const InputDecoration(
                hintText: 'مثال: صورة الهوية غير واضحة',
                hintStyle: TextStyle(color: AppTheme.textGrey),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء',
                style: TextStyle(color: AppTheme.textGrey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('رفض', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final adminUid = context.read<AuthProvider>().userModel?.uid ?? '';
    final ok = await context
        .read<AdminProvider>()
        .rejectVerification(adminUid, userId, reason: reasonCtrl.text.trim());
    if (!mounted) return;
    AppTheme.showSnackBar(context, SnackBar(
      content: Text(ok ? '🚫 تم رفض توثيق $name' : '❌ فشل الرفض'),
      backgroundColor: ok ? Colors.orange : Colors.red,
    ));
    if (ok) _load();
  }

  /// 🔒 Phase 9: عرض صورة هوية من bucket الخاص عبر signed URL مؤقت (60 ثانية).
  /// الـpath قد يكون: (أ) URL كامل قديم، (ب) مسار جديد داخل ids_private.
  Future<void> _showIdImage(String imgPathOrUrl) async {
    String? displayUrl;
    if (imgPathOrUrl.startsWith('http')) {
      // مسار قديم (URL كامل) — للتوافق الخلفي
      displayUrl = imgPathOrUrl;
    } else {
      // مسار جديد داخل ids_private — نجلب signed URL
      try {
        displayUrl = await SupabaseService()
            .storage
            .from(StorageService.idsPrivateBucket)
            .createSignedUrl(imgPathOrUrl, 60);
      } catch (e) {
        if (!mounted) return;
        AppTheme.showSnackBar(context,
          SnackBar(content: Text('❌ تعذّر فتح الصورة: $e')),
        );
        return;
      }
    }
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        child: InteractiveViewer(
          child: Image.network(
            displayUrl!,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Padding(
              padding: EdgeInsets.all(40),
              child: Icon(Icons.broken_image,
                  color: AppTheme.textGrey, size: 80),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      appBar: AppBar(
        title: const Text('مراجعة طلبات التوثيق'),
        backgroundColor: AppTheme.scaffoldBackground,
        foregroundColor: AppTheme.primaryGold,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryGold))
          : _pending.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.verified_user_outlined,
                          color: AppTheme.textGrey, size: 80),
                      const SizedBox(height: 16),
                      const Text('لا توجد طلبات توثيق قيد المراجعة',
                          style: TextStyle(
                              color: AppTheme.textGrey, fontSize: 16)),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh,
                            color: AppTheme.primaryGold),
                        label: const Text('تحديث',
                            style: TextStyle(color: AppTheme.primaryGold)),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppTheme.primaryGold,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _pending.length,
                    itemBuilder: (_, i) => _buildCard(_pending[i]),
                  ),
                ),
    );
  }

  Widget _buildCard(Map<String, dynamic> u) {
    final id = u['id'] as String;
    final name = (u['nm'] as String?)?.trim().isNotEmpty == true
        ? u['nm'] as String
        : 'بدون اسم';
    final phone = u['ph'] as String? ?? '';
    final sid = u['sid'] as String? ?? '';
    final img = u['img'] as String? ?? '';
    final isBroker = (u['brk'] ?? 0) == 1;
    final role = u['role'] ?? 0;
    final brkNm = u['brk_nm'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBlack,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: AppTheme.primaryGold.withOpacity(0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── رأس البطاقة: الاسم + شارة الدور ──
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isBroker
                      ? AppTheme.primaryGold
                      : Colors.blueGrey,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isBroker ? 'وسيط' : (role >= UserRole.minAdmin ? 'موظف' : 'مستخدم'),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                      color: AppTheme.textWhite,
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (isBroker && brkNm.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('🏢 $brkNm',
                style: const TextStyle(
                    color: AppTheme.primaryGold, fontSize: 13)),
          ],
          const SizedBox(height: 8),
          // ── المعلومات ──
          _infoRow(Icons.phone, 'الهاتف', phone),
          _infoRow(Icons.badge, 'الرقم الوطني', sid.isEmpty ? '—' : sid),
          const SizedBox(height: 10),
          // ── صورة الهوية ──
          if (img.isNotEmpty) ...[
            // 🔒 Phase 9: للأمان، لا نُحمّل صورة الهوية تلقائياً.
            // الأدمن يضغط زراً يفتح signed URL مؤقت (60s).
            InkWell(
              onTap: () => _showIdImage(img),
              child: Container(
                height: 90,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppTheme.deepBlack,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.primaryGold),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.badge_outlined,
                        color: AppTheme.primaryGold, size: 32),
                    SizedBox(height: 4),
                    Text('اضغط لعرض صورة الهوية',
                        style: TextStyle(
                            color: AppTheme.primaryGold,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                    Text('(رابط مؤقت 60 ثانية)',
                        style: TextStyle(
                            color: AppTheme.textGrey, fontSize: 10)),
                  ],
                ),
              ),
            ),
          ] else
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red),
              ),
              child: const Row(children: [
                Icon(Icons.warning, color: Colors.red, size: 18),
                SizedBox(width: 6),
                Text('⚠️ لا توجد صورة هوية مرفوعة',
                    style: TextStyle(color: Colors.red, fontSize: 13)),
              ]),
            ),
          const SizedBox(height: 12),
          // ── الأزرار ──
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _reject(id, name),
                icon: const Icon(Icons.close, color: Colors.red),
                label: const Text('رفض',
                    style: TextStyle(color: Colors.red)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: img.isEmpty ? null : () => _approve(id, name),
                icon: const Icon(Icons.verified, color: Colors.white),
                label: const Text('اعتماد',
                    style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        Icon(icon, color: AppTheme.primaryGold, size: 16),
        const SizedBox(width: 6),
        Text('$label: ',
            style: const TextStyle(color: AppTheme.textGrey, fontSize: 13)),
        Expanded(
          child: Text(value,
              style: const TextStyle(
                  color: AppTheme.textWhite, fontSize: 13),
              overflow: TextOverflow.ellipsis),
        ),
      ]),
    );
  }
}
