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
                  Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: _statCard('👥', 'المستخدمون', '${_stats['totalUsers'] ?? 0}', 'نشط: ${_stats['activeUsers'] ?? 0}')),
                          const SizedBox(width: 10),
                          Expanded(child: _statCard('🏠', 'العروض', '${_stats['totalOffers'] ?? 0}', 'منشور: ${_stats['publishedOffers'] ?? 0}')),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: _statCard('🤝', 'الصفقات', '${_stats['totalDeals'] ?? 0}', 'مكتمل: ${_stats['completedDeals'] ?? 0}')),
                          const SizedBox(width: 10),
                          Expanded(child: _statCard('💰', 'العمولات', _fmt(_stats['totalCommission']), 'إجمالي محقّق')),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                  const Text('الإدارة',
                      style: TextStyle(
                          color: AppTheme.primaryGold,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),

                  // ── مدخل الأقسام ──
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.3,
                    children: [
                      if (PermissionService.has(auth.userModel, PermissionKeys.manageStaff))
                        _navCard(Icons.badge_outlined, 'إدارة الموظفين',
                            '/admin/employee-management'),
                      _actionCard(
                        Icons.apps_outlined,
                        'أقسام الإدارة',
                        'المراجعات · العمليات · المالية · الإعدادات',
                        () => _showAdminSectionsSheet(context, auth.userModel),
                      ),
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
      height: 78,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBlack,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryGold.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppTheme.textGrey, fontSize: 11)),
                const SizedBox(height: 2),
                Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppTheme.primaryGold,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
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

  void _showAdminSectionsSheet(BuildContext context, dynamic user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceBlack,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.78,
            minChildSize: 0.45,
            maxChildSize: 0.92,
            builder: (context, controller) => ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppTheme.textGrey.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const Text(
                  'أقسام الإدارة',
                  style: TextStyle(color: AppTheme.primaryGold, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                const Text(
                  'هذه صفحات متابعة وإدارة، وليست صفحات تنفيذ ميداني خاصة بالمنفذ أو المصور.',
                  style: TextStyle(color: AppTheme.textGrey, fontSize: 12),
                ),
                const SizedBox(height: 18),
                _sheetSection('التنظيم', [
                  if (PermissionService.has(user, PermissionKeys.manageStaff))
                    _sheetTile(Icons.badge_outlined, 'إدارة الموظفين', '/admin/employee-management'),
                  if (PermissionService.has(user, PermissionKeys.manageUsers))
                    _sheetTile(Icons.people_outline, 'إدارة الحسابات والعملاء', '/admin/users'),
                  if (PermissionService.has(user, PermissionKeys.managePermissions))
                    _sheetTile(Icons.admin_panel_settings_outlined, 'الصلاحيات', '/admin/permissions'),
                  if (PermissionService.has(user, PermissionKeys.officeOperations))
                    _sheetTile(Icons.support_agent_outlined, 'عمليات المكتب', '/admin/office-operations'),
                ]),
                _sheetSection('المراجعات والرقابة', [
                  if (PermissionService.has(user, PermissionKeys.reviewOffers))
                    _sheetTile(Icons.fact_check_outlined, 'مراجعة العروض', '/admin/review-offers', badge: _counts['pendingOffers'] ?? 0),
                  if (PermissionService.has(user, PermissionKeys.mediaReview))
                    _sheetTile(Icons.photo_library_outlined, 'إدارة الوسائط', '/admin/media-review'),
                  if (PermissionService.has(user, PermissionKeys.reviewVerifications))
                    _sheetTile(Icons.verified_user_outlined, 'طلبات التوثيق', '/admin/review-verifications', badge: _counts['pendingVerifications'] ?? 0),
                  if (PermissionService.has(user, PermissionKeys.fraudSuspects))
                    _sheetTile(Icons.security, 'كشف الاحتيال', '/admin/fraud-suspects'),
                ]),
                _sheetSection('متابعة العمليات', [
                  if (PermissionService.has(user, PermissionKeys.manageAppointments))
                    _sheetTile(Icons.calendar_month_outlined, 'المواعيد والمتابعة', '/admin/appointments'),
                  if (PermissionService.has(user, PermissionKeys.completionRequests))
                    _sheetTile(Icons.assignment_turned_in_outlined, 'طلبات الإتمام', '/admin/completion-requests'),
                  if (PermissionService.has(user, PermissionKeys.photographyManagement))
                    _sheetTile(Icons.add_a_photo_outlined, 'إدارة مهام التصوير', '/admin/photography-management'),
                  if (PermissionService.has(user, PermissionKeys.manageRequests))
                    _sheetTile(Icons.assignment_outlined, 'طلبات العملاء', '/admin/requests'),
                ]),
                _sheetSection('المالية والتقارير', [
                  if (PermissionService.has(user, PermissionKeys.managePayments))
                    _sheetTile(Icons.payments_outlined, 'المدفوعات', '/admin/payments', badge: _counts['pendingPayments'] ?? 0),
                  if (PermissionService.has(user, PermissionKeys.manageDeals))
                    _sheetTile(Icons.handshake_outlined, 'الصفقات', '/admin/deals'),
                  if (PermissionService.has(user, PermissionKeys.manageReports))
                    _sheetTile(Icons.flag_outlined, 'التبليغات', '/admin/reports', badge: _counts['openReports'] ?? 0),
                  if (PermissionService.has(user, PermissionKeys.viewAnalytics))
                    _sheetTile(Icons.analytics_outlined, 'التحليلات', '/admin/analytics'),
                  if (PermissionService.has(user, PermissionKeys.manageConfig))
                    _sheetTile(Icons.tune_outlined, 'الإعدادات', '/admin/config'),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sheetSection(String title, List<Widget> children) {
    if (children.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.deepBlack,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryGold.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: AppTheme.primaryGold, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  Widget _sheetTile(IconData icon, String title, String route, {int badge = 0}) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: AppTheme.primaryGold.withValues(alpha: 0.12),
        child: Icon(icon, color: AppTheme.primaryGold),
      ),
      title: Text(title, style: const TextStyle(color: AppTheme.textWhite, fontSize: 13)),
      trailing: badge > 0
          ? CircleAvatar(
              radius: 11,
              backgroundColor: AppTheme.errorRed,
              child: Text('$badge', style: const TextStyle(color: Colors.white, fontSize: 10)),
            )
          : const Icon(Icons.chevron_left, color: AppTheme.textGrey),
      onTap: () {
        Navigator.pop(context);
        context.push(route);
      },
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
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surfaceBlack,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.primaryGold.withValues(alpha: 0.15)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppTheme.primaryGold, size: 30),
            const SizedBox(height: 8),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textWhite, fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(subtitle, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.textGrey, fontSize: 10)),
          ],
        ),
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
