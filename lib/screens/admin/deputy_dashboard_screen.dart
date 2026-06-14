import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';

/// داشبورد نائب المدير (محدود - role = 5)
class DeputyDashboardScreen extends StatelessWidget {
  const DeputyDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final name = auth.userModel?.nm ?? 'نائب المدير';

    return Scaffold(
      backgroundColor: AppTheme.deepBlack,
      appBar: AppBar(
        backgroundColor: AppTheme.deepBlack,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('لوحة نائب المدير', style: TextStyle(color: AppTheme.textWhite, fontSize: 18)),
            Text('أهلاً، $name', style: const TextStyle(color: AppTheme.primaryGold, fontSize: 12)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.people, color: AppTheme.primaryGold),
            onPressed: () => context.go('/admin/dashboard'),
            tooltip: 'إدارة الموظفين',
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.primaryGold),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // إحصائيات سريعة
            const Text('نظرة عامة', style: TextStyle(color: AppTheme.primaryGold, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _statCard('👥', 'الموظفون', '12', 'نشط: 10')),
                const SizedBox(width: 12),
                Expanded(child: _statCard('📋', 'العروض', '45', 'قيد المراجعة: 8')),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _statCard('📅', 'المواعيد', '23', 'اليوم: 5')),
                const SizedBox(width: 12),
                Expanded(child: _statCard('💰', 'المدفوعات', '7', 'بانتظار الموافقة')),
              ],
            ),

            const SizedBox(height: 32),

            // الوصول السريع
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
                _navCard(context, Icons.people, 'إدارة الموظفين', '/admin/dashboard'),
                _navCard(context, Icons.fact_check, 'مراجعة العروض', '/admin/review-offers'),
                _navCard(context, Icons.calendar_month, 'المواعيد', '/admin/appointments'),
                _navCard(context, Icons.payments, 'المدفوعات', '/admin/payments'),
                _navCard(context, Icons.assignment_turned_in, 'طلبات الإتمام', '/admin/completion-requests'),
                _navCard(context, Icons.verified_user, 'طلبات التوثيق', '/admin/review-verifications'),
              ],
            ),
          ],
        ),
      ),
    );
  }

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