import 'package:flutter/material.dart';

/// App Bar مخصص للتطبيق
class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final bool showBack;

  const CustomAppBar({
    super.key,
    required this.title,
    this.actions,
    this.showBack = true,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title),
      actions: actions,
      automaticallyImplyLeading: showBack,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}