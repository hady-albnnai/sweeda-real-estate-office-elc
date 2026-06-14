import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';

class PasswordResultDialog extends StatelessWidget {
  final String title;
  final String password;

  const PasswordResultDialog({
    super.key,
    required this.title,
    required this.password,
  });

  static Future<void> show(
    BuildContext context, {
    required String title,
    required String password,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => PasswordResultDialog(
        title: title,
        password: password,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surfaceBlack,
      title: Text(title, style: const TextStyle(color: AppTheme.textWhite)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'انسخ كلمة السر وأرسلها للموظف. لن تظهر هذه الكلمة مرة أخرى.',
            style: TextStyle(color: AppTheme.textGrey),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.deepBlack,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primaryGold.withValues(alpha: 0.45)),
            ),
            child: SelectableText(
              password,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.primaryGold,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إغلاق', style: TextStyle(color: AppTheme.textGrey)),
        ),
        ElevatedButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: password));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم نسخ كلمة السر')),
              );
            }
          },
          icon: const Icon(Icons.copy),
          label: const Text('نسخ'),
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGold),
        ),
      ],
    );
  }
}
