import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';

/// داشبورد نائب المدير (محدود)
class DeputyDashboardScreen extends StatelessWidget {
  const DeputyDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.deepBlack,
      appBar: AppBar(
        backgroundColor: AppTheme.deepBlack,
        title: const Text('لوحة نائب المدير', style: TextStyle(color: AppTheme.textWhite)),
        actions: [
          IconButton(
            icon: const Icon(Icons.people, color: AppTheme.primaryGold),
            onPressed: () => context.go('/admin/dashboard'),
            tooltip: 'إدارة الموظفين',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'مرحباً بك في لوحة نائب المدير',
              style: TextStyle(color: AppTheme.textWhite, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            
            // بطاقات الوصول السريع
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: [
                _quickAccessCard(
                  context,
                  icon: Icons.people,
                  title: 'إدارة الموظفين',
                  route: '/admin/dashboard',
                ),
                _quickAccessCard(
                  context,
                  icon: Icons.fact_check,
                  title: 'مراجعة العروض',
                  route: '/admin/review-offers',
                ),
                _quickAccessCard(
                  context,
                  icon: Icons.calendar_month,
                  title: 'المواعيد',
                  route: '/admin/appointments',
                ),
                _quickAccessCard(
                  context,
                  icon: Icons.payments,
                  title: 'المدفوعات',
                  route: '/admin/payments',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickAccessCard(BuildContext context, {
    required IconData icon,
    required String title,
    required String route,
  }) {
    return InkWell(
      onTap: () => context.go(route),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceBlack,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.primaryGold.withValues(alpha: 0.2)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppTheme.primaryGold, size: 32),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textWhite, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}