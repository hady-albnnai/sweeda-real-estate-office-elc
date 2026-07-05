import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/permission_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/admin_provider.dart';

/// مركز عمليات المكتب — شاشة تشغيلية مركزة لموظف المكتب/الإدارة.
/// تعتمد على الجداول الحالية ولا تضيف نموذج بيانات جديد.
class OfficeOperationsScreen extends StatefulWidget {
  const OfficeOperationsScreen({super.key});

  @override
  State<OfficeOperationsScreen> createState() => _OfficeOperationsScreenState();
}

class _OfficeOperationsScreenState extends State<OfficeOperationsScreen> {
  bool _loading = true;
  Map<String, int> _counts = {};
  Map<String, dynamic> _stats = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final admin = context.read<AdminProvider>();
    final adminUid = context.read<AuthProvider>().userModel?.uid ?? '';
    final results = await Future.wait([
      admin.getActionCounts(adminUid),
      admin.getStats(adminUid),
    ]);
    if (!mounted) return;
    setState(() {
      _counts = Map<String, int>.from(results[0] as Map);
      _stats = Map<String, dynamic>.from(results[1] as Map);
      _loading = false;
    });
  }

  int get _totalPending =>
      (_counts['pendingOffers'] ?? 0) +
      (_counts['pendingPayments'] ?? 0) +
      (_counts['openReports'] ?? 0) +
      (_counts['pendingVerifications'] ?? 0);

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.scaffoldBackground,
        title: const Text('مركز عمليات المكتب'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.primaryGold),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGold))
          : RefreshIndicator(
              color: AppTheme.primaryGold,
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _headerCard(),
                  const SizedBox(height: 16),
                  _sectionTitle('الأولويات'),
                  if (PermissionService.has(auth.userModel, PermissionKeys.reviewOffers))
                    _priorityTile(
                    icon: Icons.fact_check_outlined,
                    title: 'عروض بانتظار المراجعة',
                    count: _counts['pendingOffers'] ?? 0,
                    route: '/admin/review-offers',
                    color: Colors.orange,
                  ),
                  if (PermissionService.has(auth.userModel, PermissionKeys.managePayments))
                    _priorityTile(
                    icon: Icons.payments_outlined,
                    title: 'مدفوعات بانتظار الموافقة',
                    count: _counts['pendingPayments'] ?? 0,
                    route: '/admin/payments',
                    color: Colors.green,
                  ),
                  if (PermissionService.has(auth.userModel, PermissionKeys.manageReports))
                    _priorityTile(
                    icon: Icons.flag_outlined,
                    title: 'تبليغات مفتوحة',
                    count: _counts['openReports'] ?? 0,
                    route: '/admin/reports',
                    color: AppTheme.errorRed,
                  ),
                  if (PermissionService.has(auth.userModel, PermissionKeys.reviewVerifications))
                    _priorityTile(
                    icon: Icons.verified_user_outlined,
                    title: 'طلبات توثيق',
                    count: _counts['pendingVerifications'] ?? 0,
                    route: '/admin/review-verifications',
                    color: Colors.blue,
                  ),
                  const SizedBox(height: 20),
                  _sectionTitle('اختصارات التشغيل'),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    children: [
                      if (PermissionService.has(auth.userModel, PermissionKeys.manageAppointments))
                        _shortcut(Icons.calendar_month_outlined, 'المواعيد', '/admin/appointments'),
                      if (PermissionService.has(auth.userModel, PermissionKeys.manageDeals))
                        _shortcut(Icons.handshake_outlined, 'الصفقات', '/admin/deals'),
                      if (PermissionService.has(auth.userModel, PermissionKeys.manageUsers))
                        _shortcut(Icons.people_outline, 'المستخدمون', '/admin/users'),
                      if (PermissionService.has(auth.userModel, PermissionKeys.viewAnalytics))
                        _shortcut(Icons.analytics_outlined, 'التحليلات', '/admin/analytics'),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _sectionTitle('ملخص سريع'),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    children: [
                      _stat('المستخدمون', _stats['totalUsers'] ?? 0, Icons.people_outline),
                      _stat('العروض', _stats['totalOffers'] ?? 0, Icons.home_work_outlined),
                      _stat('المواعيد', _stats['totalAppointments'] ?? 0, Icons.event_available_outlined),
                      _stat('الصفقات', _stats['totalDeals'] ?? 0, Icons.handshake_outlined),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _headerCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBlack,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.primaryGold.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: AppTheme.primaryGold.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.support_agent, color: AppTheme.primaryGold, size: 30),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'لوحة متابعة الأعمال اليومية',
                  style: TextStyle(color: AppTheme.textWhite, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  _totalPending == 0
                      ? 'لا توجد عناصر عاجلة حالياً.'
                      : 'يوجد $_totalPending عنصر يحتاج متابعة.',
                  style: TextStyle(color: AppTheme.textGrey, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: const TextStyle(color: AppTheme.primaryGold, fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _priorityTile({
    required IconData icon,
    required String title,
    required int count,
    required String route,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBlack,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.12),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: TextStyle(color: AppTheme.textWhite, fontWeight: FontWeight.w600)),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text('$count', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        ),
        onTap: () => context.push(route),
      ),
    );
  }

  Widget _shortcut(IconData icon, String title, String route) {
    return InkWell(
      onTap: () => context.push(route),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surfaceBlack,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.primaryGold.withOpacity(0.18)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppTheme.primaryGold, size: 32),
            const SizedBox(height: 10),
            Text(title, textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textWhite, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _stat(String title, dynamic value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBlack,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryGold.withOpacity(0.16)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppTheme.primaryGold),
          const SizedBox(height: 8),
          Text('$value', style: const TextStyle(color: AppTheme.primaryGold, fontSize: 22, fontWeight: FontWeight.bold)),
          Text(title, style: TextStyle(color: AppTheme.textGrey, fontSize: 12)),
        ],
      ),
    );
  }
}
