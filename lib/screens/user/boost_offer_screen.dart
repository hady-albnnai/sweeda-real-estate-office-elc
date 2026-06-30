import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/config_provider.dart';
import '../../providers/offer_provider.dart';
import '../../models/offer_model.dart';
import '../../core/theme/app_theme.dart';
import '../../core/network/supabase_service.dart';

/// شاشة ترقيات العرض (spd)
/// 5 خيارات: تجديد / تثبيت / Boost / خصم 5% / عرض مميّز
class BoostOfferScreen extends StatefulWidget {
  final String offerId;
  const BoostOfferScreen({super.key, required this.offerId});

  @override
  State<BoostOfferScreen> createState() => _BoostOfferScreenState();
}

class _BoostOfferScreenState extends State<BoostOfferScreen> {
  OfferModel? _offer;
  bool _loading = true;
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final prov = context.read<OfferProvider>();
    final userId = context.read<AuthProvider>().userModel?.uid;
    var offer = prov.getOfferById(widget.offerId);
    offer ??= await prov.fetchOfferById(widget.offerId, userId: userId);
    if (!mounted) return;
    setState(() {
      _offer = offer;
      _loading = false;
    });
  }

  Future<void> _purchase(String boostType, int cost, String label) async {
    final auth = context.read<AuthProvider>();
    final user = auth.userModel;
    if (user == null || _offer == null) return;

    if (user.pt < cost) {
      _snack('رصيدك ${user.pt} نقطة، تحتاج $cost نقطة');
      return;
    }

    // تأكيد قبل الشراء
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surfaceBlack,
        title: const Row(children: [
          Icon(Icons.shopping_cart, color: AppTheme.primaryGold),
          SizedBox(width: 8),
          Text('تأكيد الشراء',
              style: TextStyle(color: AppTheme.textWhite)),
        ]),
        content: Text(
          'هل تريد شراء "$label" بـ $cost نقطة؟\n\n'
          'رصيدك الحالي: ${user.pt} نقطة\n'
          'الرصيد بعد الشراء: ${user.pt - cost} نقطة',
          style: const TextStyle(color: AppTheme.textGrey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء',
                style: TextStyle(color: AppTheme.textGrey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('شراء',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _processing = true);
    try {
      // ✅ Secure via Edge Function (user-offers) — purchase_offer_boost is locked to service_role
      final res = await SupabaseService().invokeFunction(
        'user-offers',
        body: {
          'action': 'purchase_boost',
          'user_uid': user.uid,
          'offer_id': _offer!.id,
          'boost_type': boostType,
        },
      );

      if (!mounted) return;
      setState(() => _processing = false);

      final data = res.data as Map<String, dynamic>?;
      final result = data?['result'] as Map<String, dynamic>? ?? data;
      if (result?['success'] == true || data?['success'] == true) {
        await auth.refreshUser();
        await context.read<OfferProvider>().fetchOffers();
        _snack('✅ تم تفعيل "$label" بنجاح');
        if (mounted) Navigator.pop(context, true);
      } else {
        final err = result?['error']?.toString() ?? 'UNKNOWN';
        _snack('فشل: ${_errorText(err)}');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _processing = false);
      _snack('فشل: $e');
    }
  }

  String _errorText(String code) {
    switch (code) {
      case 'INSUFFICIENT_POINTS':
        return 'نقاطك غير كافية';
      case 'OFFER_NOT_FOUND':
        return 'العرض غير موجود';
      case 'NOT_OWNER':
        return 'ليس لديك صلاحية';
      case 'INVALID_BOOST_TYPE':
        return 'نوع غير صالح';
      default:
        return code;
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
        body: Center(
            child: CircularProgressIndicator(color: AppTheme.primaryGold)),
      );
    }
    if (_offer == null) {
      return Scaffold(
        backgroundColor: AppTheme.deepBlack,
        appBar: AppBar(title: const Text('ترقية العرض')),
        body: const Center(
          child: Text('العرض غير موجود',
              style: TextStyle(color: AppTheme.textGrey)),
        ),
      );
    }

    final auth = context.watch<AuthProvider>();
    final config = context.watch<ConfigProvider>().config;
    final user = auth.userModel;
    final spd = config?.data['spd'] as Map<String, dynamic>? ??
        {'ren': 500, 'pin': 2000, 'bst': 4000, 'dsc5': 3000, 'fms': 8000};

    return Scaffold(
      backgroundColor: AppTheme.deepBlack,
      appBar: AppBar(
        title: const Text('ترقية العرض'),
        backgroundColor: AppTheme.deepBlack,
        elevation: 0,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _offerSummary(_offer!),
                const SizedBox(height: 16),
                _pointsBalance(user?.pt ?? 0),
                const SizedBox(height: 20),
                const Text('🚀 خيارات الترقية',
                    style: TextStyle(
                        color: AppTheme.primaryGold,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),

                _boostCard(
                  icon: Icons.refresh,
                  title: 'تجديد العرض',
                  description: 'تمديد العرض لـ 30 يوم إضافية',
                  cost: (spd['ren'] ?? 500) as int,
                  active: false,
                  boostType: 'ren',
                  color: Colors.blue,
                ),
                _boostCard(
                  icon: Icons.push_pin,
                  title: 'تثبيت في الأعلى',
                  description: 'يظهر عرضك بأعلى نتائج البحث لمدة 7 أيام',
                  cost: (spd['pin'] ?? 2000) as int,
                  active: _offer!.iPin == 1,
                  activeUntil: _offer!.pinEnd,
                  boostType: 'pin',
                  color: Colors.orange,
                ),
                _boostCard(
                  icon: Icons.rocket_launch,
                  title: 'Boost — وصول أكبر',
                  description: 'ضاعف ظهور عرضك للمستخدمين لمدة 14 يوم',
                  cost: (spd['bst'] ?? 4000) as int,
                  active: _offer!.iBst == 1,
                  activeUntil: _offer!.bstEnd,
                  boostType: 'bst',
                  color: Colors.purple,
                ),
                _boostCard(
                  icon: Icons.discount,
                  title: 'خصم 5% على عمولة المكتب',
                  description: 'يخفّض عمولة البيع 5% عند إتمام الصفقة',
                  cost: (spd['dsc5'] ?? 3000) as int,
                  active: _offer!.dscPct > 0,
                  activeUntil: _offer!.dscEnd,
                  boostType: 'dsc5',
                  color: Colors.green,
                ),
                _boostCard(
                  icon: Icons.star,
                  title: 'عرض مميّز (Featured)',
                  description: 'شارة مميّز + ظهور في قسم خاص لمدة 30 يوم',
                  cost: (spd['fms'] ?? 8000) as int,
                  active: _offer!.iFms == 1,
                  activeUntil: _offer!.fmsEnd,
                  boostType: 'fms',
                  color: AppTheme.primaryGold,
                ),
                const SizedBox(height: 16),
                _infoBox(),
                const SizedBox(height: 20),
              ],
            ),
          ),
          if (_processing)
            Container(
              color: Colors.black.withOpacity(0.7),
              child: const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryGold),
              ),
            ),
        ],
      ),
    );
  }

  Widget _offerSummary(OfferModel o) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBlack,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 60,
              height: 60,
              child: o.imgs.isNotEmpty
                  ? Image.network(o.imgs.first.toString(),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                          Icons.image, color: AppTheme.textGrey))
                  : Container(
                      color: AppTheme.deepBlack,
                      child: const Icon(Icons.image,
                          color: AppTheme.textGrey)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(o.ttl,
                    style: const TextStyle(
                        color: AppTheme.textWhite,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 3),
                Text(
                  '${o.prc.toStringAsFixed(0)} ${o.cur == 0 ? '\$' : 'ل.س'}',
                  style: const TextStyle(
                      color: AppTheme.primaryGold,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pointsBalance(int pts) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFD4AF37), Color(0xFFFFD700)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.stars, color: Colors.black, size: 28),
          const SizedBox(width: 10),
          const Text('رصيدك من النقاط:',
              style: TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.bold,
                  fontSize: 14)),
          const Spacer(),
          Text('$pts',
              style: const TextStyle(
                  color: Colors.black,
                  fontSize: 22,
                  fontWeight: FontWeight.bold)),
          const SizedBox(width: 4),
          const Text('نقطة',
              style: TextStyle(color: Colors.black87, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _boostCard({
    required IconData icon,
    required String title,
    required String description,
    required int cost,
    required bool active,
    DateTime? activeUntil,
    required String boostType,
    required Color color,
  }) {
    final user = context.watch<AuthProvider>().userModel;
    final canAfford = (user?.pt ?? 0) >= cost;

    // تقييد التجديد (ren): متاح للمدفوع دائماً، وللمجاني قبل يومين من الانتهاء فقط
    bool isEnabled = true;
    if (boostType == 'ren' && user?.bPkg == 0) {
      final daysLeft = _offer?.daysUntilExpiration ?? 30;
      if (daysLeft > 2) {
        isEnabled = false;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBlack,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: active ? Colors.green : color.withOpacity(0.3),
          width: active ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            color: AppTheme.textWhite,
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
                    Text(description,
                        style: const TextStyle(
                            color: AppTheme.textGrey, fontSize: 11)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('$cost',
                      style: TextStyle(
                          color: color,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  const Text('نقطة',
                      style: TextStyle(
                          color: AppTheme.textGrey, fontSize: 10)),
                ],
              ),
            ],
          ),
          if (active && activeUntil != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle,
                      color: Colors.green, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    'مفعّل حتى ${activeUntil.day}/${activeUntil.month}/${activeUntil.year}',
                    style: const TextStyle(
                        color: Colors.green,
                        fontSize: 11,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 38,
              child: ElevatedButton.icon(
                onPressed: (isEnabled && canAfford) ? () => _purchase(boostType, cost, title) : null,
                icon: (isEnabled && canAfford)
                    ? Icon(Icons.shopping_cart, color: Colors.black, size: 16)
                    : Icon(isEnabled ? Icons.money_off : Icons.lock,
                        color: Colors.black, size: 16),
                label: Text(!isEnabled
                    ? 'التجديد متاح قبل يومين من الانتهاء'
                    : (canAfford ? 'شراء بـ $cost نقطة' : 'نقاطك غير كافية'),
                    style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: (isEnabled && canAfford) ? color : Colors.grey,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoBox() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBlack,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: AppTheme.primaryGold, size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'النقاط تُكتسب من النشاط بالتطبيق (إضافة عروض، إكمال صفقات، دعوة أصدقاء، تسجيل دخول يومي).',
              style: TextStyle(color: AppTheme.textGrey, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}
