import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/broker_provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/app_back_button.dart';

/// 🤝 لوحة تحكم الوسيط/السمسار — الشاشة الرئيسية
/// تعرض: ترحيب + إحصائيات سريعة + بطاقات تنقل للأقسام
class BrokerDashboardScreen extends StatefulWidget {
  const BrokerDashboardScreen({super.key});

  @override
  State<BrokerDashboardScreen> createState() => _BrokerDashboardScreenState();
}

class _BrokerDashboardScreenState extends State<BrokerDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _load() {
    final auth = context.read<AuthProvider>();
    final id = auth.userModel?.uid ?? '';
    if (id.isNotEmpty) {
      context.read<BrokerProvider>().fetchBrokerStats(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final broker = context.watch<BrokerProvider>();
    final name = auth.userModel?.brkNm.isNotEmpty == true
        ? auth.userModel!.brkNm
        : (auth.userModel?.nm ?? 'الوسيط');
    final stats = broker.stats;

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      appBar: AppBar(
        leading: const AppBackButton(),
        backgroundColor: AppTheme.scaffoldBackground,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('لوحة الوسيط',
                style: TextStyle(
                    color: AppTheme.textWhite,
                    fontSize: AppTheme.fontSizeTitle,
                    fontWeight: FontWeight.bold)),
            Text('أهلاً، $name 🤝',
                style: TextStyle(
                    color: AppTheme.primaryGold.withOpacity(0.8), fontSize: AppTheme.fontSizeSmall)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.home_outlined, color: AppTheme.primaryGold),
            tooltip: 'الواجهة الرئيسية',
            onPressed: () => context.go('/user/home'),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.primaryGold),
            onPressed: _load,
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.primaryGold,
        onRefresh: () async => _load(),
        child: broker.isLoading && stats.isEmpty
            ? const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryGold))
            : ListView(
                padding: AppTheme.paddingAllLarge,
                children: [
                  // ── شبكة الإحصائيات ──
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.8,
                    children: [
                      _statCard('🏠', 'العروض',
                          '${stats['totalOffers'] ?? 0}', 'منشور: ${stats['publishedOffers'] ?? 0}'),
                      _statCard('📅', 'المواعيد',
                          '${stats['totalAppointments'] ?? 0}', 'مكتمل: ${stats['completedAppointments'] ?? 0}'),
                      _statCard('🤝', 'الصفقات',
                          '${stats['totalDeals'] ?? 0}', 'مكتمل: ${stats['completedDeals'] ?? 0}'),
                      _statCard('💰', 'العمولات',
                          _fmt(stats['totalCommission']), 'إجمالي محقّق'),
                    ],
                  ),
                  AppTheme.gapHeightXXL,
                  const Text('الأقسام',
                      style: TextStyle(
                          color: AppTheme.primaryGold,
                          fontSize: AppTheme.fontSizeSubtitle,
                          fontWeight: FontWeight.bold)),
                  AppTheme.gapHeightMedium,

                  // ── بطاقات التنقل ──
                  _navTile(
                    icon: Icons.calendar_today_outlined,
                    title: 'طلبات المعاينة',
                    subtitle: 'قبول ورفض مواعيد المعاينة',
                    onTap: () => context.push('/broker/appointments'),
                  ),
                  _navTile(
                    icon: Icons.handshake_outlined,
                    title: 'الصفقات',
                    subtitle: 'الصفقات النشطة والمكتملة',
                    onTap: () => context.push('/broker/deals'),
                  ),
                  _navTile(
                    icon: Icons.bar_chart_outlined,
                    title: 'الإحصائيات',
                    subtitle: 'تقارير الأداء التفصيلية',
                    onTap: () => context.push('/broker/stats'),
                  ),
                ],
              ),
      ),
    );
  }

  String _fmt(dynamic v) {
    final n = (v ?? 0) as num;
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}م';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}ألف';
    return n.toStringAsFixed(0);
  }

  Widget _statCard(String emoji, String label, String value, String sub) {
    return Container(
      padding: AppTheme.paddingAllMedium,
      decoration: BoxDecoration(
        color: AppTheme.surfaceBlack,
        borderRadius: AppTheme.borderRadiusLarge,
        border: Border.all(color: AppTheme.primaryGold.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: AppTheme.fontSizeTitle)),
              const SizedBox(width: 6),
              Text(label,
                  style: const TextStyle(
                      color: AppTheme.textGrey, fontSize: AppTheme.fontSizeSmall)),
            ],
          ),
          AppTheme.gapHeightXS,
          Text(value,
              style: const TextStyle(
                  color: AppTheme.primaryGold,
                  fontSize: AppTheme.fontSizeHeadline,
                  fontWeight: FontWeight.bold)),
          Text(sub,
              style: const TextStyle(color: AppTheme.textGrey, fontSize: AppTheme.fontSizeXS)),
        ],
      ),
    );
  }

  Widget _navTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBlack,
        borderRadius: AppTheme.borderRadiusLarge,
        border: Border.all(color: AppTheme.primaryGold.withOpacity(0.15)),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.primaryGold.withOpacity(0.15),
          child: Icon(icon, color: AppTheme.primaryGold),
        ),
        title: Text(title,
            style: const TextStyle(
                color: AppTheme.textWhite, fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle,
            style: const TextStyle(color: AppTheme.textGrey, fontSize: AppTheme.fontSizeSmall)),
        trailing:
            const Icon(Icons.arrow_back_ios, color: AppTheme.primaryGold, size: 16),
        onTap: onTap,
      ),
    );
  }
}
