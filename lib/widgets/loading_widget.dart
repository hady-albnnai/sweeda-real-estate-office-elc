import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

/// ويدجت التحميل — تظهر أثناء جلب البيانات (بثيم التطبيق الذهبي)
class LoadingWidget extends StatelessWidget {
  final String? message;

  const LoadingWidget({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: AppTheme.primaryGold),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(message!, style: const TextStyle(color: AppTheme.textGrey)),
          ],
        ],
      ),
    );
  }
}
