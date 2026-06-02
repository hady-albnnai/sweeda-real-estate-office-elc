import 'package:flutter/material.dart';

/// ويدجت الحالة الفارغة — تظهر عندما لا يوجد بيانات
class EmptyState extends StatelessWidget {
  final String message;
  final String? actionText;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    this.message = 'لا توجد بيانات',
    this.actionText,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          if (actionText != null && onAction != null) ...[
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onAction,
              child: Text(actionText!),
            ),
          ],
        ],
      ),
    );
  }
}