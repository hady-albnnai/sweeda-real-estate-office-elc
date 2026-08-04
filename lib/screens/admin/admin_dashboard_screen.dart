import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/admin_provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/app_back_button.dart';
import '../../widgets/e2e.dart';

/// 🛡️ لوحة الإدارة الرئيسية
/// تعرض: إحصائيات عامة + عدّادات الإجراءات المطلوبة + شبكة تنقّل للأقسام
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  Map<String, dynamic> _stats = {};
  Map<String, int> _counts = {};
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
    final stats = await admin.getStats(adminUid);
    final counts = await admin.getActionCounts(adminUid);
    if (mounted) {
      setState(() {
        _stats = stats;
        _counts = counts;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final name = auth.userModel?.nm ?? 'المدير';

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      appBar: AppBar(
        leading: const AppBackButton(),
        backgroundColor: AppTheme.scaffoldBackground,
        elevation: 0,
        title: E2E(
          id: 'e2e_screen_admin_dashboard',
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('لوحة الإدارة',
                style: TextStyle(
                    color: AppTheme.textWhite,
                    fontSize: AppTheme.fontSizeTitle,
                    fontWeight: FontWeight.bold)),
            Text('أهلاً، $name 🛡️',
                style: TextStyle(
                    color: AppTheme.primaryGold.withOpacity(0.8), fontSize: AppTheme.fontSizeSmall)),
          ],
          ),
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
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryGold))
          : RefreshIndicator(
              color: AppTheme.primaryGold,
              onRefresh: _load,
              child: ListView(
                padding: AppTheme.paddingAllLarge,
                children: [
                  // ── تنبيهات الإجراءات المطلوبة ──
                  if (_totalActions() > 0) _actionsBanner(),

                  // ── إحصائيات عامة ──
                  AppTheme.gapHeightXS,
                  const Text('نظرة عامة',
                      style: TextStyle(
                          color: AppTheme.primaryGold,
                          fontSize: AppTheme.fontSizeSubtitle,
                          fontWeight: FontWeight.bold)),
                  AppTheme.gapHeightMedium,
                  Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: _statCard('👥', 'المستخدمون', '${_stats['totalUsers'] ?? 0}', 'نشط: ${_stats['activeUsers'] ?? 0}')),
                          AppTheme.gapWidthSmall,
                          Expanded(child: _statCard('🏠', 'العروض', '${_stats['totalOffers'] ?? 0}', 'منشور: ${_stats['publishedOffers'] ?? 0}')),
                        ],
                      ),
                      AppTheme.gapHeightSmall,
                      Row(
                        children: [
                          Expanded(child: _statCard('🤝', 'الصفقات', '${_stats['totalDeals'] ?? 0}', 'مكتمل: ${_stats['completedDeals'] ?? 0}')),
                          AppTheme.gapWidthSmall,
                          Expanded(child: _statCard('💰', 'العمولات', _fmt(_stats['totalCommission']), 'إجمالي محقّق')),
                        ],
                      ),
                    ],
                  ),

                  AppTheme.gapHeightXXL,
                  const Text('الإدارة',
                      style: TextStyle(
                          color: AppTheme.primaryGold,
                          fontSize: AppTheme.fontSizeSubtitle,
                          fontWeight: FontWeight.bold)),
                  AppTheme.gapHeightMedium,

                  // ── مدخل الأقسام ──
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    children: [
                      _actionCard(
                        Icons.apps_outlined,
                        'أقسام الإدارة',
                        'المراجعات · العمليات · المالية · الإعدادات',
                        () => context.push('/admin/sections'),
                      ),
                    ],
                  ),
                  AppTheme.gapHeightXL,
                ],
              ),
            ),
    );
  }

  int _totalActions() =>
      (_counts['pendingOffers'] ?? 0) +
      (_counts['pendingPayments'] ?? 0) +
      (_counts['openReports'] ?? 0) +
      (_counts['pendingVerifications'] ?? 0);

  Widget _actionsBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: AppTheme.paddingAllLarge,
      decoration: BoxDecoration(
        color: AppTheme.errorRed.withOpacity(0.12),
        borderRadius: AppTheme.borderRadiusLarge,
        border: Border.all(color: AppTheme.errorRed.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.notification_important, color: AppTheme.errorRed),
          AppTheme.gapWidthMedium,
          Expanded(
            child: Text(
              'لديك ${_totalActions()} عنصر بانتظار الإجراء '
              '(${_counts['pendingOffers'] ?? 0} عرض · '
              '${_counts['pendingPayments'] ?? 0} دفعة · '
              '${_counts['openReports'] ?? 0} تبليغ · '
              '${_counts['pendingVerifications'] ?? 0} توثيق)',
              style: const TextStyle(color: AppTheme.textWhite, fontSize: AppTheme.fontSizeBody),
            ),
          ),
        ],
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
      height: 78,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBlack,
        borderRadius: AppTheme.borderRadiusLarge,
        border: Border.all(color: AppTheme.primaryGold.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: AppTheme.fontSizeHeadline)),
          AppTheme.gapWidthSmall,
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppTheme.textGrey, fontSize: AppTheme.fontSizeCaption)),
                AppTheme.gapHeightXXS,
                Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppTheme.primaryGold,
                        fontSize: AppTheme.fontSizeTitle,
                        fontWeight: FontWeight.bold)),
                AppTheme.gapHeightXXS,
                Text(sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppTheme.textGrey, fontSize: 9)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionCard(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppTheme.borderRadiusLarge,
      child: Container(
        padding: AppTheme.paddingAllLarge,
        decoration: BoxDecoration(
          color: AppTheme.surfaceBlack,
          borderRadius: AppTheme.borderRadiusLarge,
          border: Border.all(color: AppTheme.primaryGold.withOpacity(0.15)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppTheme.primaryGold, size: 34),
            AppTheme.gapHeightSmall,
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.textWhite,
                fontSize: AppTheme.fontSizeBody,
                fontWeight: FontWeight.w600,
              ),
            ),
            AppTheme.gapHeightXS,
            Text(
              subtitle,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppTheme.textGrey, fontSize: AppTheme.fontSizeXS),
            ),
          ],
        ),
      ),
    );
  }


}
