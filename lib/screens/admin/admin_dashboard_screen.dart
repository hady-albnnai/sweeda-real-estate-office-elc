import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/admin_provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/permission_service.dart';

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
    final stats = await admin.getStats();
    final counts = await admin.getActionCounts();
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
      backgroundColor: AppTheme.deepBlack,
      appBar: AppBar(
        backgroundColor: AppTheme.deepBlack,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('لوحة الإدارة',
                style: TextStyle(
                    color: AppTheme.textWhite,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            Text('أهلاً، $name 🛡️',
                style: TextStyle(
                    color: AppTheme.primaryGold.withValues(alpha: 0.8), fontSize: 12)),
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
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryGold))
          : RefreshIndicator(
              color: AppTheme.primaryGold,
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ── تنبيهات الإجراءات المطلوبة ──
                  if (_totalActions() > 0) _actionsBanner(),

                  // ── إحصائيات عامة ──
                  const SizedBox(height: 4),
                  const Text('نظرة عامة',
                      style: TextStyle(
                          color: AppTheme.primaryGold,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth >= 520;
                      return GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: wide ? 2.15 : 1.85,
                        children: [
                      _statCard('👥', 'المستخدمون',
                          '${_stats['totalUsers'] ?? 0}', 'نشط: ${_stats['activeUsers'] ?? 0}'),
                      _statCard('🏠', 'العروض',
                          '${_stats['totalOffers'] ?? 0}', 'منشور: ${_stats['publishedOffers'] ?? 0}'),
                      _statCard('🤝', 'الصفقات',
                          '${_stats['totalDeals'] ?? 0}', 'مكتمل: ${_stats['completedDeals'] ?? 0}'),
                      _statCard('💰', 'العمولات',
                          _fmt(_stats['totalCommission']), 'إجمالي محقّق'),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 24),
                  const Text('الإدارة',
                      style: TextStyle(
                          color: AppTheme.primaryGold,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),

                  // ── شبكة الأقسام ──
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.3,
                    children: [
                      _navCard(Icons.fact_check_outlined, 'فحص النظام',
                          '/admin/qa'),
                      if (PermissionService.has(auth.userModel, PermissionKeys.officeOperations))
                        _navCard(Icons.support_agent_outlined, 'عمليات المكتب',
                            '/admin/office-operations'),
                      if (PermissionService.has(auth.userModel, PermissionKeys.managePermissions))
                        _navCard(Icons.admin_panel_settings_outlined, 'الصلاحيات',
                            '/admin/permissions'),
                      if (PermissionService.has(auth.userModel, PermissionKeys.reviewOffers))
                        _navCard(Icons.fact_check_outlined, 'مراجعة العروض',
                            '/admin/review-offers',
                            badge: _counts['pendingOffers'] ?? 0),
                      if (PermissionService.has(auth.userModel, PermissionKeys.photographyManagement))
                        _navCard(Icons.add_a_photo_outlined, 'مهام التصوير',
                            '/admin/photography-management'),
                      if (PermissionService.has(auth.userModel, PermissionKeys.mediaReview))
                        _navCard(Icons.photo_library_outlined, 'إدارة الوسائط',
                            '/admin/media-review'),
                      if (PermissionService.has(auth.userModel, PermissionKeys.reviewVerifications))
                        _navCard(Icons.verified_user_outlined, 'طلبات التوثيق',
                            '/admin/review-verifications',
                            badge: _counts['pendingVerifications'] ?? 0),
                      if (PermissionService.has(auth.userModel, PermissionKeys.manageUsers))
                        _navCard(Icons.people_outline, 'المستخدمون',
                            '/admin/users'),
                      if (PermissionService.has(auth.userModel, PermissionKeys.manageAppointments))
                        _navCard(Icons.calendar_month_outlined, 'المواعيد',
                            '/admin/appointments'),
                      if (PermissionService.has(auth.userModel, PermissionKeys.manageDeals))
                        _navCard(Icons.handshake_outlined, 'الصفقات',
                            '/admin/deals'),
                      if (PermissionService.has(auth.userModel, PermissionKeys.managePayments))
                        _navCard(Icons.payments_outlined, 'المدفوعات',
                            '/admin/payments',
                            badge: _counts['pendingPayments'] ?? 0),
                      if (PermissionService.has(auth.userModel, PermissionKeys.manageReports))
                        _navCard(Icons.flag_outlined, 'التبليغات',
                            '/admin/reports',
                            badge: _counts['openReports'] ?? 0),
                      if (PermissionService.has(auth.userModel, PermissionKeys.manageConfig))
                        _navCard(Icons.tune_outlined, 'الإعدادات',
                            '/admin/config'),
                      if (PermissionService.has(auth.userModel, PermissionKeys.viewAnalytics))
                        _navCard(Icons.analytics_outlined, 'التحليلات',
                            '/admin/analytics'),
                      if (PermissionService.has(auth.userModel, PermissionKeys.fraudSuspects))
                        _navCard(Icons.security, 'كشف الاحتيال',
                            '/admin/fraud-suspects'),
                    ],
                  ),
                  const SizedBox(height: 20),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.errorRed.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.errorRed.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.notification_important, color: AppTheme.errorRed),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'لديك ${_totalActions()} عنصر بانتظار الإجراء '
              '(${_counts['pendingOffers'] ?? 0} عرض · '
              '${_counts['pendingPayments'] ?? 0} دفعة · '
              '${_counts['openReports'] ?? 0} تبليغ · '
              '${_counts['pendingVerifications'] ?? 0} توثيق)',
              style: const TextStyle(color: AppTheme.textWhite, fontSize: 13),
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
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBlack,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryGold.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 17)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppTheme.textGrey, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              value,
              maxLines: 1,
              style: const TextStyle(
                color: AppTheme.primaryGold,
                fontSize: 21,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Text(
            sub,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppTheme.textGrey, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _navCard(IconData icon, String title, String route, {int badge = 0}) {
    return InkWell(
      onTap: () => context.push(route),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surfaceBlack,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.primaryGold.withValues(alpha: 0.15)),
        ),
        child: Stack(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(icon, color: AppTheme.primaryGold, size: 34),
                const SizedBox(height: 10),
                Text(title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: AppTheme.textWhite,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ],
            ),
            if (badge > 0)
              Positioned(
                top: 0,
                left: 0,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.errorRed,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('$badge',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
