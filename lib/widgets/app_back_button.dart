import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/theme/app_theme.dart';

/// زر رجوع موحّد للشاشات التي قد تُفتح عبر context.go ولا تملك back stack.
/// إذا يوجد مسار سابق: pop. وإلا ينتقل لمسار fallback آمن.
class AppBackButton extends StatelessWidget {
  final String fallbackRoute;
  final Color color;
  final String tooltip;

  const AppBackButton({
    super.key,
    this.fallbackRoute = '/user/profile',
    this.color = AppTheme.primaryGold,
    this.tooltip = 'رجوع',
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      icon: Icon(Icons.arrow_back_ios_new, color: color),
      onPressed: () {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        } else {
          context.go(fallbackRoute);
        }
      },
    );
  }
}
