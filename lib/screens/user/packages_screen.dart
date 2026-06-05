import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/config_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_utils.dart';

/// شاشة عرض الباقات والاشتراك
/// تقرأ الباقات من `config.pkg` (3 باقات: 0=مجاني, 1=فضي, 2=ذهبي)
class PackagesScreen extends StatelessWidget {
  const PackagesScreen({super.key});

  // أسعار افتراضية بالدولار — تُقرأ من config لاحقاً عند توفّرها
  static const Map<int, double> _defaultPrices = {
    0: 0,
    1: 10,
    2: 25,
  };

  static const Map<int, List<Color>> _gradients = {
    0: [Color(0xFF424242), Color(0xFF616161)],
    1: [Color(0xFF8E8E8E), Color(0xFFBDBDBD)],
    2: [Color(0xFFD4AF37), Color(0xFFFFD700)],
  };

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final config = context.watch<ConfigProvider>().config;
    final user = auth.userModel;
    final pkgMap = config?.packages ?? {};

    final packages = [0, 1, 2]
        .map((id) => _PackageData.fromConfig(id, pkgMap[id.toString()]))
        .toList();

    return Scaffold(
      backgroundColor: AppTheme.deepBlack,
      appBar: AppBar(
        title: const Text('باقات الاشتراك'),
        backgroundColor: AppTheme.deepBlack,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // البطاقة الحالية
            if (user != null) _currentBadge(user.bPkg, user.pkgEnd),
            const SizedBox(height: 20),
            const Text(
              'اختر الباقة الأنسب لاحتياجك',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textWhite,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'كلما زادت الباقة، زاد عدد العروض ومدة العرض',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textGrey, fontSize: 13),
            ),
            const SizedBox(height: 20),
            ...packages.map((p) => _packageCard(context, p, user?.bPkg ?? 0)),
            const SizedBox(height: 20),
            _infoBox(),
          ],
        ),
      ),
    );
  }

  Widget _currentBadge(int currentPkg, DateTime? pkgEnd) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBlack,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryGold.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.workspace_premium,
              color: AppTheme.primaryGold, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('باقتك الحالية',
                    style:
                        TextStyle(color: AppTheme.textGrey, fontSize: 12)),
                Text(
                  _packageName(currentPkg),
                  style: const TextStyle(
                    color: AppTheme.primaryGold,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (pkgEnd != null && currentPkg > 0)
                  Text(
                    'تنتهي: ${AppUtils.formatTimestamp(pkgEnd)}',
                    style: const TextStyle(
                        color: AppTheme.textGrey, fontSize: 11),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _packageCard(BuildContext context, _PackageData pkg, int currentPkg) {
    final isCurrent = pkg.id == currentPkg;
    final isFree = pkg.id == 0;
    final gradient = _gradients[pkg.id]!;
    final price = _defaultPrices[pkg.id]!;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: gradient[0].withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
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
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pkg.name,
                        style: TextStyle(
                          color: gradient[1],
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (isCurrent)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'باقتك الحالية',
                            style: TextStyle(
                                color: Colors.green,
                                fontSize: 11,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
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
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (!isFree)
                      const Text('/ شهرياً',
                          style: TextStyle(
                              color: AppTheme.textGrey, fontSize: 11)),
                  ],
                ),
              ],
            ),
            const Divider(color: AppTheme.textGrey, height: 24),
            _feature(Icons.list_alt, '${pkg.offers} عروض فعّالة'),
            _feature(Icons.calendar_today, 'مدة العرض ${pkg.duration} يوم'),
            if (pkg.id >= 1) _feature(Icons.star, 'أولوية بالظهور'),
            if (pkg.id >= 2) _feature(Icons.support_agent, 'دعم فني مميّز'),
            if (pkg.id >= 2) _feature(Icons.verified, 'شارة موثّق'),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: (isCurrent || isFree)
                    ? null
                    : () => context.push(
                        '/user/payment?pkg=${pkg.id}&amt=${price.toStringAsFixed(0)}'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: gradient[1],
                  foregroundColor: Colors.black,
                  disabledBackgroundColor: AppTheme.surfaceBlack,
                  disabledForegroundColor: AppTheme.textGrey,
                ),
                child: Text(
                  isCurrent
                      ? 'باقتك الحالية ✓'
                      : isFree
                          ? 'الباقة الافتراضية'
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

  Widget _feature(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primaryGold, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                  color: AppTheme.textWhite, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoBox() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBlack,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.textGrey.withOpacity(0.3)),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: AppTheme.primaryGold, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'يتم تفعيل الباقة بعد موافقة الإدارة على إثبات الدفع. عادة خلال 24 ساعة.',
              style: TextStyle(color: AppTheme.textGrey, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  static String _packageName(int pkg) {
    switch (pkg) {
      case 0:
        return 'مجاني';
      case 1:
        return 'فضي';
      case 2:
        return 'ذهبي';
      default:
        return 'غير معروف';
    }
  }
}

class _PackageData {
  final int id;
  final String name;
  final int offers;
  final int duration;

  _PackageData({
    required this.id,
    required this.name,
    required this.offers,
    required this.duration,
  });

  factory _PackageData.fromConfig(int id, dynamic raw) {
    final m = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    final defaults = const {
      0: {'nm': 'مجاني', 'o': 5, 'd': 30},
      1: {'nm': 'فضي', 'o': 15, 'd': 45},
      2: {'nm': 'ذهبي', 'o': 40, 'd': 60},
    };
    final def = defaults[id]!;
    return _PackageData(
      id: id,
      name: (m['nm'] ?? def['nm']) as String,
      offers: (m['o'] ?? def['o']) as int,
      duration: (m['d'] ?? def['d']) as int,
    );
  }
}
