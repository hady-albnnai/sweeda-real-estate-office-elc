import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
      backgroundColor: AppTheme.deepBlack,
      selectedItemColor: AppTheme.primaryGold,
      unselectedItemColor: AppTheme.textGrey,
      selectedFontSize: 12,
      unselectedFontSize: 11,
      onTap: (index) {
        switch (index) {
          case 0: context.go('/user/home');
          case 1: context.go('/user/my-requests');
          case 2: context.go('/user/my-appointments');
          case 3: context.go('/user/favorites');
          case 4: context.go('/user/profile');
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
