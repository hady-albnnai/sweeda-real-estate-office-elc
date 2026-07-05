import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../providers/theme_provider.dart';

class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final media = MediaQuery.of(context);

    // نستخدم Align/Padding بدل Positioned حتى يبقى الزر آمناً داخل أي Stack
    // ولا يسبب أخطاء ParentDataWidget أو قيود layout على بعض الأجهزة.
    return IgnorePointer(
      ignoring: false,
      child: SafeArea(
        child: Align(
          alignment: AlignmentDirectional.bottomStart,
          child: Padding(
            padding: EdgeInsetsDirectional.only(
              start: 12,
              bottom: media.padding.bottom + 88,
            ),
            child: Material(
              color: Colors.transparent,
              child: Tooltip(
                message: theme.isDarkMode ? 'تفعيل الوضع النهاري' : 'تفعيل الوضع الليلي',
                child: InkWell(
                  borderRadius: BorderRadius.circular(28),
                  onTap: theme.toggle,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: theme.isDarkMode ? AppTheme.surfaceBlack : AppTheme.primaryGold,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.primaryGold.withOpacity(0.65), width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(theme.isDarkMode ? 0.45 : 0.18),
                          blurRadius: 14,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Icon(
                      theme.isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                      color: theme.isDarkMode ? AppTheme.primaryGold : AppTheme.deepBlack,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
