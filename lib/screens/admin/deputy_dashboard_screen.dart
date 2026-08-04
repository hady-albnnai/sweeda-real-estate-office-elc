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
      backgroundColor: AppTheme.scaffoldBackground,
      appBar: AppBar(
        leading: const AppBackButton(),
        backgroundColor: AppTheme.scaffoldBackground,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('لوحة نائب المدير', style: TextStyle(color: AppTheme.textWhite, fontSize: AppTheme.fontSizeTitle)),
            Text('أهلاً، $name', style: const TextStyle(color: AppTheme.primaryGold, fontSize: AppTheme.fontSizeSmall)),
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
            padding: AppTheme.paddingAllLarge,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('نظرة عامة', style: TextStyle(color: AppTheme.primaryGold, fontSize: AppTheme.fontSizeSubtitle, fontWeight: FontWeight.bold)),
                AppTheme.gapHeightMedium,
                if (loading)
                  const Center(child: CircularProgressIndicator(color: AppTheme.primaryGold))
                else ...[
                  Row(
                    children: [
                      Expanded(child: _statCard('👥', 'المستخدمون', _value(stats['total_users']), 'إجمالي الحسابات')),
                      AppTheme.gapWidthMedium,
                      Expanded(child: _statCard('🏠', 'العروض النشطة', _value(stats['active_offers']), 'منشورة حالياً')),
                    ],
                  ),
                  AppTheme.gapHeightMedium,
                  Row(
                    children: [
                      Expanded(child: _statCard('💰', 'دفعات معلقة', _value(stats['pending_payments']), 'بانتظار الموافقة')),
                      AppTheme.gapWidthMedium,
                      Expanded(child: _statCard('✅', 'توثيقات معلقة', _value(stats['pending_verifications']), 'قيد المراجعة')),
                    ],
                  ),
                ],
                const const SizedBox(height: AppTheme.spacingXXXL),
                const Text('الوصول السريع', style: TextStyle(color: AppTheme.primaryGold, fontSize: AppTheme.fontSizeSubtitle, fontWeight: FontWeight.bold)),
                AppTheme.gapHeightMedium,
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
      padding: AppTheme.paddingAllLarge,
      decoration: BoxDecoration(
        color: AppTheme.surfaceBlack,
        borderRadius: AppTheme.borderRadiusLarge,
        border: Border.all(color: AppTheme.primaryGold.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: AppTheme.fontSizeHeadline)),
          AppTheme.gapHeightSmall,
          Text(label, style: const TextStyle(color: AppTheme.textGrey, fontSize: AppTheme.fontSizeSmall)),
          Text(value, style: const TextStyle(color: AppTheme.primaryGold, fontSize: 22, fontWeight: FontWeight.bold)),
          Text(sub, style: const TextStyle(color: AppTheme.textGrey, fontSize: AppTheme.fontSizeCaption)),
        ],
      ),
    );
  }

  Widget _navCard(BuildContext context, IconData icon, String title, String route) {
    return InkWell(
      onTap: () => context.push(route),
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
            Icon(icon, color: AppTheme.primaryGold, size: 30),
            AppTheme.gapHeightSmall,
            Text(title, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textWhite, fontSize: AppTheme.fontSizeBody)),
          ],
        ),
      ),
    );
  }
}
