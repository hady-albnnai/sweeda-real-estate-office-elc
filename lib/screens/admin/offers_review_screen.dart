import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/admin_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/config_provider.dart';
import '../../models/offer_model.dart';
import '../../models/user_model.dart';
import '../../core/services/business_service.dart';
import '../../core/network/supabase_service.dart';
import '../../core/constants/db_constants.dart';
import '../../core/theme/app_theme.dart';

/// شاشة مراجعة العروض الجديدة للإدارة
/// تعرض الصور + معلومات المرسل + التفاصيل + كشف العروض المكررة
/// + إجراءات قبول/رفض بسبب
class OffersReviewScreen extends StatefulWidget {
  const OffersReviewScreen({super.key});

  @override
  State<OffersReviewScreen> createState() => _OffersReviewScreenState();
}

class _OffersReviewScreenState extends State<OffersReviewScreen> {
  List<OfferModel> _offers = [];
  bool _loading = true;

  // كاش بيانات المرسلين: userId → UserModel
  final Map<String, UserModel> _ownersCache = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final admin = context.read<AdminProvider>();
    final adminUid = context.read<AuthProvider>().userModel?.uid ?? '';
    final offers = await admin.getPendingOffers(adminUid);

    // اجلب بيانات المرسلين + مضيفي الإدارة دفعة واحدة
    final uids = {
      ...offers.map((o) => o.usrId),
      ...offers.where((o) => o.addedBy != null).map((o) => o.addedBy!),
    }.where((id) => id.isNotEmpty).toList();

    if (uids.isNotEmpty) {
      try {
        final usersData = await SupabaseService()
            .client
            .from(DbTables.users)
            .select()
            .inFilter('id', uids);
        for (final u in usersData as List) {
          final m = Map<String, dynamic>.from(u as Map);
          final user = UserModel.fromSupabase(m, m['id'] as String);
          _ownersCache[user.uid] = user;
        }
      } catch (e) {
      // تم تجاهل الخطأ عمداً للحفاظ على التدفق الحالي.
    }
    }

    if (!mounted) return;
    setState(() {
      _offers = offers;
      _loading = false;
    });
  }

  Future<void> _approve(OfferModel o) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surfaceBlack,
        title: Text('تأكيد القبول',
            style: TextStyle(color: AppTheme.textWhite)),
        content: Text(
            'سيتم نشر العرض ليصبح مرئياً للجميع. هل أنت متأكد؟',
            style: TextStyle(color: AppTheme.textGrey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('إلغاء',
                style: TextStyle(color: AppTheme.textGrey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('نشر',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    final admin = context.read<AdminProvider>();
    final adminUid = context.read<AuthProvider>().userModel?.uid ?? '';
    final ok = await admin.reviewOffer(adminUid, o.id, true);
    if (!mounted) return;
    if (ok) {
      try {
        final config = context.read<ConfigProvider>().config;
        await BusinessService().awardEvent(o.usrId, config, 'addO', fallback: 500);
      } catch (_) {
      // تم تجاهل الخطأ عمداً للحفاظ على التدفق الحالي.
    }
      _snack('✅ تم نشر العرض');
      _load();
    } else {
      _snack('فشل النشر');
    }
  }

  Future<void> _reject(OfferModel o) async {
    final reason = await _askReason();
    if (reason == null || !mounted) return;

    final admin = context.read<AdminProvider>();
    final adminUid = context.read<AuthProvider>().userModel?.uid ?? '';
    final ok = await admin.reviewOffer(adminUid, o.id, false, reason: reason);
    if (!mounted) return;
    if (ok) {
      _snack('تم رفض العرض');
      _load();
    } else {
      _snack('فشل الرفض');
    }
  }

  Future<String?> _askReason() async {
    final ctrl = TextEditingController();
    String? selected;
    final presets = [
      'صور غير واضحة',
      'بيانات ناقصة',
      'سعر غير منطقي',
      'عرض مكرر',
      'محتوى مخالف',
      'سبب آخر',
    ];

    return showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          return AlertDialog(
            backgroundColor: AppTheme.surfaceBlack,
            title: Text('سبب الرفض',
                style: TextStyle(color: AppTheme.textWhite)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ...presets.map((p) => RadioListTile<String>(
                        title: Text(p,
                            style: TextStyle(color: AppTheme.textWhite)),
                        value: p,
                        groupValue: selected,
                        onChanged: (value) => setS(() => selected = value),
                        activeColor: AppTheme.primaryGold,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      )),
                  const SizedBox(height: 8),
                  TextField(
                    controller: ctrl,
                    maxLines: 2,
                    style: TextStyle(color: AppTheme.textWhite),
                    decoration: const InputDecoration(
                      hintText: 'تفاصيل إضافية (اختياري)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('إلغاء',
                    style: TextStyle(color: AppTheme.textGrey)),
              ),
              ElevatedButton(
                onPressed: () {
                  if (selected == null) return;
                  final extra = ctrl.text.trim();
                  final result =
                      extra.isEmpty ? selected! : '$selected — $extra';
                  Navigator.pop(ctx, result);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('رفض',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _snack(String m) =>
      AppTheme.showSnackBar(context, SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      appBar: AppBar(
        title: Text('مراجعة العروض (${_offers.length})'),
        backgroundColor: AppTheme.scaffoldBackground,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.primaryGold),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryGold))
          : _offers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline,
                          size: 80,
                          color: Colors.green.withOpacity(0.6)),
                      const SizedBox(height: 20),
                      Text(
                        'لا توجد عروض بانتظار المراجعة 🎉',
                        style: TextStyle(
                            color: AppTheme.textGrey, fontSize: 16),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: AppTheme.primaryGold,
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _offers.length,
                    itemBuilder: (_, i) => _offerCard(_offers[i]),
                  ),
                ),
    );
  }

  Widget _offerCard(OfferModel o) {
    final owner = _ownersCache[o.usrId];
    final hasImage = o.imgs.isNotEmpty;
    final isDup = o.iDup == 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBlack,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDup ? Colors.orange : AppTheme.primaryGold.withOpacity(0.3),
          width: isDup ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // تحذير العرض المكرر
          if (isDup)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(13)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber,
                      color: Colors.orange, size: 16),
                  SizedBox(width: 6),
                  Text('⚠️ عرض مكرّر محتمل',
                      style: TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                          fontSize: 12)),
                ],
              ),
            ),

          // الصور
          if (hasImage)
            SizedBox(
              height: 180,
              child: PageView.builder(
                itemCount: o.imgs.length,
                itemBuilder: (_, i) => Image.network(
                  o.imgs[i].toString(),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: AppTheme.deepBlack,
                    child: Center(
                      child: Icon(Icons.broken_image,
                          color: AppTheme.textGrey, size: 50),
                    ),
                  ),
                ),
              ),
            )
          else
            Container(
              height: 120,
              color: AppTheme.deepBlack,
              child: Center(
                child: Icon(Icons.image_not_supported,
                    color: AppTheme.textGrey, size: 50),
              ),
            ),

          // التفاصيل
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // عنوان + سعر
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        o.ttl,
                        style: TextStyle(
                            color: AppTheme.textWhite,
                            fontSize: 16,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    Text(
                      '${o.prc.toStringAsFixed(0)} ${o.cur == 0 ? '\$' : 'ل.س'}',
                      style: const TextStyle(
                          color: AppTheme.primaryGold,
                          fontWeight: FontWeight.bold,
                          fontSize: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // النوع + المعاملة
                Wrap(spacing: 6, children: [
                  _chip(o.typ == 0 ? '🏠 عقار' : '🚗 سيارة', Colors.blue),
                  _chip(o.trx == 0 ? 'بيع' : 'إيجار', Colors.purple),
                  if (o.imgs.isNotEmpty)
                    _chip('${o.imgs.length} صور',
                        AppTheme.primaryGold),
                ]),
                const SizedBox(height: 10),

                // الموقع
                Row(
                  children: [
                    Icon(Icons.location_on,
                        color: AppTheme.textGrey, size: 14),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        (o.loc['d'] ?? 'غير محدد').toString(),
                        style: TextStyle(
                            color: AppTheme.textGrey, fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // الوصف
                if (o.descript.isNotEmpty) ...[
                  Text(
                    o.descript,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: AppTheme.textWhite, fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                ],

                // تنويه داخلي: من أضاف العرض (إذا أضافته الإدارة)
                if (o.addedBy != null && o.addedBy!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.withOpacity(0.3)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.admin_panel_settings,
                          color: Colors.amber, size: 14),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          // نعرض اسم الموظف إذا توفر، وإلا ID مختصر
                          'أُضيف بواسطة: ${_ownersCache[o.addedBy]?.nm.isNotEmpty == true ? _ownersCache[o.addedBy]!.nm : 'موظف (${o.addedBy!.substring(0, 8)})'}',
                          style: const TextStyle(color: Colors.amber, fontSize: 11),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 8),
                ],

                // المرسل (صاحب العرض)
                Divider(color: AppTheme.textGrey, height: 16),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: AppTheme.primaryGold,
                      child: Text(
                        (owner?.nm.isNotEmpty == true
                                ? owner!.nm[0]
                                : '؟')
                            .toUpperCase(),
                        style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            owner?.nm.isNotEmpty == true
                                ? owner!.nm
                                : 'مستخدم بدون اسم',
                            style: TextStyle(
                                color: AppTheme.textWhite,
                                fontWeight: FontWeight.bold,
                                fontSize: 13),
                          ),
                          Text(
                            owner?.ph ?? '—',
                            style: TextStyle(
                                color: AppTheme.textGrey, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    if (owner != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGold.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${owner.pt} نقطة',
                          style: const TextStyle(
                              color: AppTheme.primaryGold,
                              fontSize: 11,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // أزرار الإجراءات
          Container(
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: AppTheme.deepBlack, width: 1),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _reject(o),
                    icon: const Icon(Icons.cancel, color: Colors.red),
                    label: const Text('رفض',
                        style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold)),
                    style: TextButton.styleFrom(
                      padding:
                          const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                Container(width: 1, height: 36, color: AppTheme.deepBlack),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => context.push('/offer/${o.id}'),
                    icon: Icon(Icons.preview,
                        color: AppTheme.textWhite),
                    label: Text('معاينة',
                        style: TextStyle(color: AppTheme.textWhite)),
                    style: TextButton.styleFrom(
                      padding:
                          const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                Container(width: 1, height: 36, color: AppTheme.deepBlack),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _approve(o),
                    icon: const Icon(Icons.check_circle,
                        color: Colors.green),
                    label: const Text('قبول',
                        style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold)),
                    style: TextButton.styleFrom(
                      padding:
                          const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}
