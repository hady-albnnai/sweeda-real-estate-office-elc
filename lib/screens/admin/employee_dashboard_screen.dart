import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';

/// داشبورد موظف المكتب (محدود)
class EmployeeDashboardScreen extends StatelessWidget {
  const EmployeeDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.deepBlack,
      appBar: AppBar(
        backgroundColor: AppTheme.deepBlack,
        title: const Text('لوحة موظف المكتب', style: TextStyle(color: AppTheme.textWhite)),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.support_agent, size: 80, color: AppTheme.primaryGold),
            const SizedBox(height: 24),
            const Text(
              'لوحة موظف المكتب',
              style: TextStyle(color: AppTheme.textWhite, fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'هذه الشاشة قيد التطوير',
              style: TextStyle(color: AppTheme.textGrey),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => context.go('/employee/home'),
              child: const Text('العودة إلى الواجهة الرئيسية'),
            ),
          ],
        ),
      ),
    );
  }
}