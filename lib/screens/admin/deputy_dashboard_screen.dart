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
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.admin_panel_settings, size: 80, color: AppTheme.primaryGold),
            const SizedBox(height: 24),
            const Text(
              'لوحة نائب المدير',
              style: TextStyle(color: AppTheme.textWhite, fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'هذه الشاشة قيد التطوير',
              style: TextStyle(color: AppTheme.textGrey),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => context.go('/admin/dashboard'),
              child: const Text('العودة إلى إدارة الموظفين'),
            ),
          ],
        ),
      ),
    );
  }
}