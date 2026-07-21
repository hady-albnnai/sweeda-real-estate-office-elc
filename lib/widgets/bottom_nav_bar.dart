import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../core/theme/app_theme.dart';
import 'e2e.dart';

/// شريط التنقل السفلي الرئيسي للتطبيق
/// للمستخدمين العاديين والوسطاء: الرئيسية، طلباتي، مواعيدي، المفضلة، حسابي
/// للإدارة والموظفين: مهامي، حسابي فقط
class CustomBottomNavBar extends StatelessWidget {
  final int currentIndex;
  const CustomBottomNavBar({super.key, required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isInternal = auth.userModel?.isInternal ?? false;

    // الإدارة والموظفين: شريط مختصر (مهامي + حسابي)
    if (isInternal) {
      return BottomNavigationBar(
        currentIndex: currentIndex > 0 ? 1 : 0,
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppTheme.scaffoldBackground,
        selectedItemColor: AppTheme.primaryGold,
        unselectedItemColor: AppTheme.textGrey,
        selectedFontSize: 12,
        unselectedFontSize: 11,
        onTap: (index) {
          if (index == 0) {
            // مهامي — حسب الدور
            if (auth.isLawyer) {
              context.go('/lawyer/dashboard');
            } else if (auth.isExpediter) {
              context.go('/expediter/tasks');
            } else if (auth.isSenior) {
              context.go('/admin/dashboard');
            } else if (auth.isPhotographer) {
              context.go('/photographer/tasks');
            } else if (auth.isSupervisor) {
              context.go('/executor/tasks');
            } else {
              context.go('/employee/home');
            }
          } else {
            context.go('/user/profile');
          }
        },
        items: [
          BottomNavigationBarItem(
            icon: E2E(id: 'e2e_nav_home', button: true, child: Icon(Icons.task_alt_outlined)),
            activeIcon: Icon(Icons.task_alt),
            label: 'مهامي',
          ),
          BottomNavigationBarItem(
            icon: E2E(id: 'e2e_nav_profile', button: true, child: Icon(Icons.person_outline)),
            activeIcon: Icon(Icons.person),
            label: 'حسابي',
          ),
        ],
      );
    }

    // المستخدمون العاديون والوسطاء: شريط كامل
    return BottomNavigationBar(
      currentIndex: currentIndex,
      type: BottomNavigationBarType.fixed,
      backgroundColor: AppTheme.scaffoldBackground,
      selectedItemColor: AppTheme.primaryGold,
      unselectedItemColor: AppTheme.textGrey,
      selectedFontSize: 12,
      unselectedFontSize: 11,
      onTap: (index) {
        switch (index) {
          case 0:
            if (auth.isBroker) {
              context.go('/broker/dashboard');
            } else {
              context.go('/user/home');
            }
            break;
          case 1: context.go('/user/my-requests'); break;
          case 2: context.go('/user/my-appointments'); break;
          case 3: context.go('/user/favorites'); break;
          case 4: context.go('/user/profile'); break;
        }
      },
      items: const [
        BottomNavigationBarItem(icon: E2E(id: 'e2e_nav_home', button: true, child: Icon(Icons.home_outlined)), activeIcon: Icon(Icons.home), label: 'الرئيسية'),
        BottomNavigationBarItem(icon: E2E(id: 'e2e_nav_requests', button: true, child: Icon(Icons.assignment_outlined)), activeIcon: Icon(Icons.assignment), label: 'طلباتي'),
        BottomNavigationBarItem(icon: E2E(id: 'e2e_nav_appointments', button: true, child: Icon(Icons.calendar_today_outlined)), activeIcon: Icon(Icons.calendar_today), label: 'مواعيدي'),
        BottomNavigationBarItem(icon: E2E(id: 'e2e_nav_favorites', button: true, child: Icon(Icons.favorite_outline)), activeIcon: Icon(Icons.favorite), label: 'المفضلة'),
        BottomNavigationBarItem(icon: E2E(id: 'e2e_nav_profile', button: true, child: Icon(Icons.person_outline)), activeIcon: Icon(Icons.person), label: 'حسابي'),
      ],
    );
  }
}
