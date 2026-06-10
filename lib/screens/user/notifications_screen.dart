import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/notification_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/notification_model.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../widgets/shimmer_loading.dart';
import '../../widgets/empty_state.dart';

/// 🔔 شاشة الإشعارات — قائمة + تعليم كمقروء + تنقّل حسب نوع الإشعار
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _load() {
    final uid = context.read<AuthProvider>().userModel?.uid ?? '';
    if (uid.isNotEmpty) {
      context.read<NotificationProvider>().fetchNotifications(uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<NotificationProvider>();
    final uid = context.read<AuthProvider>().userModel?.uid ?? '';

    return Scaffold(
      backgroundColor: AppTheme.deepBlack,
      appBar: AppBar(
        backgroundColor: AppTheme.deepBlack,
        title: const Text('الإشعارات'),
        actions: [
          if (prov.notifications.any((n) => !n.isRead))
            TextButton(
              onPressed: () => prov.markAllAsRead(uid).then((_) => _load()),
              child: const Text('تعليم الكل',
                  style: TextStyle(color: AppTheme.primaryGold)),
            ),
        ],
      ),
      body: prov.isLoading && prov.notifications.isEmpty
          ? ShimmerLoading.tileList()
          : prov.notifications.isEmpty
              ? const EmptyState(
                  message: 'لا توجد إشعارات حالياً',
                  icon: Icons.notifications_off_outlined,
                )
              : RefreshIndicator(
                  color: AppTheme.primaryGold,
                  onRefresh: () async => _load(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: prov.notifications.length,
                    itemBuilder: (_, i) => _tile(prov.notifications[i], prov),
                  ),
                ),
    );
  }

  Widget _tile(NotificationModel n, NotificationProvider prov) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: n.isRead
            ? AppTheme.surfaceBlack
            : AppTheme.primaryGold.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: n.isRead
                ? Colors.white12
                : AppTheme.primaryGold.withValues(alpha: 0.4)),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.primaryGold.withValues(alpha: 0.15),
          child: Icon(_iconForType(n.tp), color: AppTheme.primaryGold),
        ),
        title: Text(n.ttl,
            style: TextStyle(
                color: AppTheme.textWhite,
                fontWeight: n.isRead ? FontWeight.normal : FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(n.bdy,
                style: const TextStyle(color: AppTheme.textGrey, fontSize: 13)),
            const SizedBox(height: 4),
            Text(AppUtils.formatTimestamp(n.tsCrt),
                style: TextStyle(
                    color: AppTheme.textGrey.withValues(alpha: 0.7), fontSize: 11)),
          ],
        ),
        trailing: n.isRead
            ? null
            : Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                    color: AppTheme.primaryGold, shape: BoxShape.circle),
              ),
        onTap: () {
          final uid = context.read<AuthProvider>().userModel?.uid ?? '';
          if (!n.isRead && uid.isNotEmpty) {
            prov.markAsRead(uid, n.id).then((_) => _load());
          }
          _navigateForNotification(n);
        },
      ),
    );
  }

  IconData _iconForType(int tp) {
    switch (tp) {
      case 0:
        return Icons.home_work; // عروض
      case 1:
        return Icons.assignment; // طلبات
      case 2:
        return Icons.calendar_today; // مواعيد
      case 3:
        return Icons.payments; // مالية
      case 4:
        return Icons.account_circle; // حساب
      case 5:
        return Icons.star; // تقييم
      default:
        return Icons.notifications;
    }
  }

  void _navigateForNotification(NotificationModel n) {
    if (n.refId.isEmpty) return;
    switch (n.tp) {
      case 0: // عرض
        context.push('/offer/${n.refId}');
        break;
      case 2: // موعد
        context.push('/user/my-appointments');
        break;
      default:
        break;
    }
  }
}
