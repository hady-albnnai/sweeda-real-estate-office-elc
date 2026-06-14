import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/services/permission_service.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/admin_provider.dart';
import '../../providers/auth_provider.dart';

/// داشبورد موظف المكتب (role = 4)
class EmployeeDashboardScreen extends StatelessWidget {
  const EmployeeDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.userModel;
    final name = user?.nm ?? 'موظف المكتب';

    return Scaffold(
      backgroundColor: AppTheme.deepBlack,
      appBar: AppBar(
        backgroundColor: AppTheme.deepBlack,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('لوحة موظف المكتب', style: TextStyle(color: AppTheme.textWhite, fontSize: 18)),
            Text('أهلاً، $name', style: const TextStyle(color: AppTheme.primaryGold, fontSize: 12)),
          ],
        ),
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
                const Text('مهام اليوم', style: TextStyle(color: AppTheme.primaryGold, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                if (loading)
                  const Center(child: CircularProgressIndicator(color: AppTheme.primaryGold))
                else ...[
                  Row(
                    children: [
                      Expanded(child: _statCard('📋', 'عروض مراجعة', _value(stats['reviewed_offers']), 'نشاط العروض')),
                      const SizedBox(width: 12),
                      Expanded(child: _statCard('📅', 'مواعيد معالجة', _value(stats['managed_appointments']), 'نشاط المواعيد')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _statCard('✅', 'طلبات إتمام', _value(stats['processed_completions']), 'طلبات معالجة')),
                      const SizedBox(width: 12),
                      Expanded(child: _statCard('👥', 'الدور', '4', 'موظف مكتب')),
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
                    if (PermissionService.has(user, PermissionKeys.reviewOffers))
                      _navCard(context, Icons.fact_check, 'مراجعة العروض', '/admin/review-offers'),
                    if (PermissionService.has(user, PermissionKeys.manageAppointments))
                      _navCard(context, Icons.calendar_month, 'المواعيد', '/admin/appointments'),
                    if (PermissionService.has(user, PermissionKeys.completionRequests))
                      _navCard(context, Icons.assignment_turned_in, 'طلبات الإتمام', '/admin/completion-requests'),
                    if (PermissionService.has(user, PermissionKeys.manageUsers))
                      _navCard(context, Icons.people, 'المستخدمون', '/admin/users'),
                    if (PermissionService.has(user, PermissionKeys.mediaReview))
                      _navCard(context, Icons.photo_library, 'إدارة الوسائط', '/admin/media-review'),
                    if (PermissionService.has(user, PermissionKeys.photographyManagement))
                      _navCard(context, Icons.add_a_photo, 'مهام التصوير', '/admin/photography-management'),
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
      onTap: () => context.go(route),
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
