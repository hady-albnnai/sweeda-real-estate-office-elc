import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/services/permission_service.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/admin_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_back_button.dart';

/// داشبورد نائب المدير (role = 5)
class DeputyDashboardScreen extends StatelessWidget {
  const DeputyDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.userModel;
    final name = user?.nm ?? 'نائب المدير';

    return Scaffold(
      backgroundColor: AppTheme.deepBlack,
      appBar: AppBar(
        leading: const AppBackButton(),
        backgroundColor: AppTheme.deepBlack,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('لوحة نائب المدير', style: TextStyle(color: AppTheme.textWhite, fontSize: 18)),
            Text('أهلاً، $name', style: const TextStyle(color: AppTheme.primaryGold, fontSize: 12)),
          ],
        ),
        actions: [
          if (PermissionService.has(user, PermissionKeys.manageStaff))
            IconButton(
              icon: const Icon(Icons.people, color: AppTheme.primaryGold),
              onPressed: () => context.push('/admin/employee-management'),
              tooltip: 'إدارة الموظفين',
            ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: user == null
            ? Future.value({})
            : context.read<AdminProvider>().getStaffStatsInternal(user.uid),
        builder: (context, snapshot) {
          final stats = snapshot.data ?? {};
          final loading = snapshot.connectionState == ConnectionState.waiting;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('نظرة عامة', style: TextStyle(color: AppTheme.primaryGold, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                if (loading)
                  const Center(child: CircularProgressIndicator(color: AppTheme.primaryGold))
                else ...[
                  Row(
                    children: [
                      Expanded(child: _statCard('👥', 'المستخدمون', _value(stats['total_users']), 'إجمالي الحسابات')),
                      const SizedBox(width: 12),
                      Expanded(child: _statCard('🏠', 'العروض النشطة', _value(stats['active_offers']), 'منشورة حالياً')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _statCard('💰', 'دفعات معلقة', _value(stats['pending_payments']), 'بانتظار الموافقة')),
                      const SizedBox(width: 12),
                      Expanded(child: _statCard('✅', 'توثيقات معلقة', _value(stats['pending_verifications']), 'قيد المراجعة')),
                    ],
                  ),
                ],
                const SizedBox(height: 32),
                const Text('الوصول السريع', style: TextStyle(color: AppTheme.primaryGold, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.6,
                  children: [
                    if (PermissionService.has(user, PermissionKeys.manageStaff))
                      _navCard(context, Icons.people, 'إدارة الموظفين', '/admin/employee-management'),
                    if (PermissionService.has(user, PermissionKeys.reviewOffers))
                      _navCard(context, Icons.fact_check, 'مراجعة العروض', '/admin/review-offers'),
                    if (PermissionService.has(user, PermissionKeys.manageAppointments))
                      _navCard(context, Icons.calendar_month, 'المواعيد', '/admin/appointments'),
                    if (PermissionService.has(user, PermissionKeys.managePayments))
                      _navCard(context, Icons.payments, 'المدفوعات', '/admin/payments'),
                    if (PermissionService.has(user, PermissionKeys.completionRequests))
                      _navCard(context, Icons.assignment_turned_in, 'طلبات الإتمام', '/admin/completion-requests'),
                    if (PermissionService.has(user, PermissionKeys.reviewVerifications))
                      _navCard(context, Icons.verified_user, 'طلبات التوثيق', '/admin/review-verifications'),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _value(dynamic value) => (value ?? 0).toString();

  Widget _statCard(String emoji, String label, String value, String sub) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBlack,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryGold.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: AppTheme.textGrey, fontSize: 12)),
          Text(value, style: const TextStyle(color: AppTheme.primaryGold, fontSize: 22, fontWeight: FontWeight.bold)),
          Text(sub, style: const TextStyle(color: AppTheme.textGrey, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _navCard(BuildContext context, IconData icon, String title, String route) {
    return InkWell(
      onTap: () => context.push(route),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceBlack,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.primaryGold.withValues(alpha: 0.15)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppTheme.primaryGold, size: 30),
            const SizedBox(height: 10),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textWhite, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
