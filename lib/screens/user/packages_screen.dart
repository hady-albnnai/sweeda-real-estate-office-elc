import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/config_provider.dart';
import '../../providers/payment_provider.dart';
import '../../models/user_model.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../models/config_model.dart';

/// شاشة الباقات — مع دعم grace period + دفعة معلقة + السعر من Config
class PackagesScreen extends StatefulWidget {
  const PackagesScreen({super.key});
  @override
  State<PackagesScreen> createState() => _PackagesScreenState();
}

class _PackagesScreenState extends State<PackagesScreen> {
  static const Map<int, List<Color>> _gradients = {
    0: [Color(0xFF424242), Color(0xFF616161)],
    1: [Color(0xFF8E8E8E), Color(0xFFBDBDBD)],
    2: [Color(0xFFD4AF37), Color(0xFFFFD700)],
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uid = context.read<AuthProvider>().userModel?.uid;
      if (uid != null) {
        context.read<PaymentProvider>().fetchPayments(uid);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth    = context.watch<AuthProvider>();
    final config  = context.watch<ConfigProvider>().config;
    final payProv = context.watch<PaymentProvider>();
    final user    = auth.userModel;
    final pkgMap  = config?.packages ?? {};

    final packages = [0, 1, 2]
        .map((id) => _PackageData.fromConfig(id, pkgMap[id.toString()]))
        .toList();

    // دفعات معلقة للمستخدم
    final pendingPayments = payProv.payments
        .where((p) => p.sts == 0 && p.tp == 0)
        .toList();

    return Scaffold(
      backgroundColor: AppTheme.deepBlack,
      appBar: AppBar(
        title: const Text('باقات الاشتراك'),
        backgroundColor: AppTheme.deepBlack,
        elevation: 0,
        actions: [
          // زر "دفعاتي"
          TextButton.icon(
            onPressed: () => context.push('/user/my-payments'),
            icon: const Icon(Icons.receipt_long,
                color: AppTheme.primaryGold, size: 18),
            label: const Text('دفعاتي',
                style: TextStyle(color: AppTheme.primaryGold, fontSize: 13)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // بطاقة الباقة الحالية
            if (user != null) _currentBadge(user),
            const SizedBox(height: 12),

            // تنبيه دفعة معلقة
            if (pendingPayments.isNotEmpty) ...[
              _pendingPaymentBanner(pendingPayments.first.pkg),
              const SizedBox(height: 12),
            ],

            const Text(
              'اختر الباقة الأنسب لاحتياجك',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppTheme.textWhite,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'كلما زادت الباقة، زاد عدد العروض ومدة العرض',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textGrey, fontSize: 13),
            ),
            const SizedBox(height: 20),

            ...packages.map((p) => _packageCard(
                  context, p, user,
                  config: config,
                  pendingPkgIds:
                      pendingPayments.map((pp) => pp.pkg).toSet(),
                )),

            const SizedBox(height: 20),
            _infoBox(config),
          ],
        ),
      ),
    );
  }

  // ─── بطاقة الباقة الحالية ───
  Widget _currentBadge(UserModel user) {
    final isPkgActive      = user.isPkgActive;
    final isInGrace        = user.isInGracePeriod;
    final isExpired        = user.bPkg > 0 && !isPkgActive && !isInGrace;

    Color borderColor = AppTheme.primaryGold.withOpacity(0.4);
    if (isInGrace)  borderColor = Colors.orange.withOpacity(0.6);
    if (isExpired)  borderColor = Colors.red.withOpacity(0.5);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBlack,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(children: [
        Icon(
          isInGrace  ? Icons.hourglass_bottom :
          isExpired  ? Icons.warning_amber :
                       Icons.workspace_premium,
          color: isInGrace ? Colors.orange :
                 isExpired  ? Colors.red :
                              AppTheme.primaryGold,
          size: 32,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isInGrace ? 'فترة السماح — باقة ${_pkgName(user.bPkg)}' :
                isExpired  ? 'انتهت الباقة — ${_pkgName(user.bPkg)}' :
                user.bPkg == 0 ? 'الباقة المجانية' :
                'باقة ${_pkgName(user.bPkg)} — نشطة',
                style: TextStyle(
                  color: isInGrace ? Colors.orange :
                         isExpired  ? Colors.red :
                                      AppTheme.primaryGold,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              if (user.pkgEnd != null && user.bPkg > 0)
                Text(
                  isPkgActive
                      ? 'تنتهي: ${AppUtils.formatTimestamp(user.pkgEnd!)}'
                      : isInGrace
                          ? '⚠️ فترة السماح تنتهي: ${AppUtils.formatTimestamp(user.pkgGrace!)} (${user.graceDaysLeft} يوم متبق)'
                          : '⛔ انتهت — جدّد اشتراكك الآن',
                  style: TextStyle(
                    color: isInGrace ? Colors.orange :
                           isExpired  ? Colors.red :
                                        AppTheme.textGrey,
                    fontSize: 11,
                    fontWeight: (isInGrace || isExpired)
                        ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
            ],
          ),
        ),
        // زر تجديد سريع إذا انتهت أو في فترة السماح
        if ((isExpired || isInGrace) && user.bPkg > 0) ...[
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => context.push('/user/payment?pkg=${user.bPkg}'),
            style: ElevatedButton.styleFrom(
              backgroundColor: isInGrace ? Colors.orange : AppTheme.primaryGold,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: const Text('جدّد', style: TextStyle(fontSize: 12)),
          ),
        ],
      ]),
    );
  }

  // ─── تنبيه دفعة معلقة ───
  Widget _pendingPaymentBanner(int pkgId) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue.withOpacity(0.4)),
      ),
      child: Row(children: [
        const Icon(Icons.pending_actions, color: Colors.blue, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'لديك دفعة معلقة للباقة ${_pkgName(pkgId)} — في انتظار موافقة الإدارة (عادة < 24 ساعة).',
            style:
                const TextStyle(color: Colors.blue, fontSize: 12, height: 1.4),
          ),
        ),
        TextButton(
          onPressed: () => context.push('/user/my-payments'),
          child: const Text('متابعة',
              style: TextStyle(color: Colors.blue, fontSize: 12)),
        ),
      ]),
    );
  }

  // ─── بطاقة باقة ───
  Widget _packageCard(
    BuildContext context,
    _PackageData pkg,
    UserModel? user, {
    ConfigModel? config,
    required Set<int> pendingPkgIds,
  }) {
    final effectivePkg  = user?.effectivePkg ?? 0;
    final isCurrent     = pkg.id == effectivePkg && pkg.id > 0;
    final isFree        = pkg.id == 0;
    final isPending     = pendingPkgIds.contains(pkg.id);
    final gradient      = _gradients[pkg.id]!;

    // السعر من Config مباشرة — لا من URL
    final price = pkg.price;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
            colors: gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        boxShadow: [
          BoxShadow(
              color: gradient[0].withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Container(
        margin: const EdgeInsets.all(2),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surfaceBlack,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pkg.name,
                      style: TextStyle(
                          color: gradient[1],
                          fontSize: 22,
                          fontWeight: FontWeight.bold),
                    ),
                    if (isCurrent)
                      _badge('باقتك الحالية', Colors.green),
                    if (isPending && !isCurrent)
                      _badge('دفعة معلقة ⏳', Colors.blue),
                    if (user?.isInGracePeriod == true &&
                        pkg.id == user?.bPkg &&
                        !isCurrent)
                      _badge('فترة السماح', Colors.orange),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    isFree ? 'مجاناً' : '\$${price.toStringAsFixed(0)}',
                    style: TextStyle(
                        color: gradient[1],
                        fontSize: 26,
                        fontWeight: FontWeight.bold),
                  ),
                  if (!isFree)
                    const Text('/ شهرياً',
                        style:
                            TextStyle(color: AppTheme.textGrey, fontSize: 11)),
                ],
              ),
            ]),
            const Divider(color: AppTheme.textGrey, height: 24),
            _feature(Icons.list_alt, '${pkg.offers} عروض فعّالة'),
            _feature(Icons.calendar_today, 'مدة العرض ${pkg.duration} يوم'),
            _feature(Icons.hourglass_bottom, '${config?.pkgGraceDays ?? 3} أيام سماح بعد الانتهاء'),
            if (pkg.id >= 1) _feature(Icons.star, 'أولوية بالظهور'),
            if (pkg.id >= 2) _feature(Icons.support_agent, 'دعم فني مميّز'),
            if (pkg.id >= 2) _feature(Icons.handshake, 'شارة موثوق'),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: _btnAction(
                    context, pkg, isCurrent, isFree, isPending, price),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isPending
                      ? Colors.blue.withOpacity(0.3)
                      : gradient[1],
                  foregroundColor: Colors.black,
                  disabledBackgroundColor: AppTheme.surfaceBlack,
                  disabledForegroundColor: AppTheme.textGrey,
                ),
                child: Text(
                  isCurrent
                      ? 'باقتك الحالية ✓'
                      : isFree
                          ? 'الباقة الافتراضية'
                          : isPending
                              ? 'دفعة معلقة — قيد المراجعة'
                              : 'الاشتراك الآن',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  VoidCallback? _btnAction(BuildContext ctx, _PackageData pkg, bool isCurrent,
      bool isFree, bool isPending, double price) {
    if (isCurrent || isFree) return null;
    if (isPending) {
      return () => ctx.push('/user/my-payments');
    }
    // السعر يأتي من Config مباشرة — لا من URL قابل للتعديل
    return () => ctx.push(
        '/user/payment?pkg=${pkg.id}');
  }

  Widget _badge(String label, Color color) => Container(
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label,
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.bold)),
      );

  Widget _feature(IconData icon, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Icon(icon, color: AppTheme.primaryGold, size: 18),
          const SizedBox(width: 10),
          Expanded(
              child: Text(text,
                  style: const TextStyle(
                      color: AppTheme.textWhite, fontSize: 14))),
        ]),
      );

  Widget _infoBox(ConfigModel? config) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surfaceBlack,
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: AppTheme.textGrey.withOpacity(0.3)),
        ),
                child: Row(children: [
          const Icon(Icons.info_outline, color: AppTheme.primaryGold, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'يتم تفعيل الباقة بعد موافقة الإدارة على إثبات الدفع (عادة < 24 ساعة). '
              'بعد انتهاء الباقة لديك ${config?.pkgGraceDays ?? 3} أيام سماح قبل التحول للمجانية.',
              style: TextStyle(color: AppTheme.textGrey, fontSize: 12),
            ),
          ),
        ]),
      );

  static String _pkgName(int pkg) {
    switch (pkg) {
      case 1: return 'الفضية';
      case 2: return 'الذهبية';
      default: return 'المجانية';
    }
  }
}

class _PackageData {
  final int    id;
  final String name;
  final int    offers;
  final int    duration;
  final double price;

  _PackageData({
    required this.id,
    required this.name,
    required this.offers,
    required this.duration,
    required this.price,
  });

  factory _PackageData.fromConfig(int id, dynamic raw) {
    final m = raw is Map
        ? Map<String, dynamic>.from(raw)
        : <String, dynamic>{};
    const defaults = {
      0: {'nm': 'مجاني',  'o': 5,  'd': 30, 'pr': 0},
      1: {'nm': 'فضي',   'o': 15, 'd': 45, 'pr': 10},
      2: {'nm': 'ذهبي',  'o': 40, 'd': 60, 'pr': 25},
    };
    final def = defaults[id]!;
    return _PackageData(
      id:       id,
      name:     (m['nm'] ?? def['nm']) as String,
      offers:   (m['o']  ?? def['o'])  as int,
      duration: (m['d']  ?? def['d'])  as int,
      price:    ((m['pr'] ?? def['pr']) as num).toDouble(),
    );
  }
}
