import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../core/theme/app_theme.dart';

/// شريط التنقل السفلي الرئيسي للتطبيق
class CustomBottomNavBar extends StatelessWidget {
  final int currentIndex;
  const CustomBottomNavBar({super.key, required this.currentIndex});

  @override
  Widget build(BuildContext context) {
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
            final auth = context.read<AuthProvider>();
            if (auth.isLoggedIn) {
              if (auth.isLawyer) {
                context.go('/lawyer/dashboard');
              } else if (auth.isExpediter) {
                context.go('/expediter/tasks');
              } else if (auth.isSenior) {
                context.go('/admin/dashboard');
              } else if (auth.isEmployee) {
                context.go('/employee/home');
              } else if (auth.isSupervisor) {
                context.go('/executor/tasks');
              } else if (auth.isPhotographer) {
                context.go('/photographer/tasks');
              } else if (auth.isBroker) {
                context.go('/broker/dashboard');
              } else {
                context.go('/user/home');
              }
            } else {
              context.go('/home');
            }
            break;
          case 1: context.go('/user/my-requests'); break;
          case 2: context.go('/user/my-appointments'); break;
          case 3: context.go('/user/favorites'); break;
          case 4: context.go('/user/profile'); break;
        }
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'الرئيسية'),
        BottomNavigationBarItem(icon: Icon(Icons.assignment_outlined), activeIcon: Icon(Icons.assignment), label: 'طلباتي'),
        BottomNavigationBarItem(icon: Icon(Icons.calendar_today_outlined), activeIcon: Icon(Icons.calendar_today), label: 'مواعيدي'),
        BottomNavigationBarItem(icon: Icon(Icons.favorite_outline), activeIcon: Icon(Icons.favorite), label: 'المفضلة'),
        BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'حسابي'),
      ],
    );
  }
}
