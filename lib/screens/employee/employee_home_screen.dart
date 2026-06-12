import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/permission_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/executor_provider.dart';

/// الشاشة الرئيسية لموظف المكتب — تجمع عمليات المكتب اليومية
class EmployeeHomeScreen extends StatefulWidget {
  const EmployeeHomeScreen({super.key});

  @override
  State<EmployeeHomeScreen> createState() => _EmployeeHomeScreenState();
}

class _EmployeeHomeScreenState extends State<EmployeeHomeScreen> {
  int _pendingCompletions = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCounts());
  }

  Future<void> _loadCounts() async {
    setState(() => _loading = true);
    final uid = context.read<AuthProvider>().userModel?.uid ?? '';
    if (uid.isNotEmpty) {
      final pending = await context.read<ExecutorProvider>().getPendingRequests(uid);
      if (mounted) {
        setState(() {
          _pendingCompletions = pending.length;
          _loading = false;
        });
      }
    } else {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.userModel;

    return Scaffold(
      backgroundColor: AppTheme.deepBlack,
      appBar: AppBar(
        backgroundColor: AppTheme.deepBlack,
        elevation: 0,
        title: Column(
          children: [
            const Text('المكتب العقاري',
                style: TextStyle(color: AppTheme.primaryGold, fontSize: 18, fontWeight: FontWeight.bold)),
            Text(user?.nm ?? 'موظف المكتب',
                style: const TextStyle(color: AppTheme.textGrey, fontSize: 12)),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none, color: AppTheme.primaryGold),
            onPressed: () => context.push('/user/notifications'),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.primaryGold),
            onPressed: _loadCounts,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGold))
          : RefreshIndicator(
              color: AppTheme.primaryGold,
              onRefresh: _loadCounts,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ─── العمليات الأساسية ───
                  _sectionTitle('العمليات اليومية'),
                  const SizedBox(height: 10),
                  _buildGrid([
                    if (PermissionService.has(user, PermissionKeys.reviewOffers))
                      _item(Icons.fact_check_outlined, 'مراجعة العروض', '/admin/review-offers', Colors.blue),
                    if (PermissionService.has(user, PermissionKeys.manageAppointments))
                      _item(Icons.calendar_month_outlined, 'المواعيد', '/admin/appointments', Colors.teal),
                    if (PermissionService.has(user, PermissionKeys.manageRequests))
                      _item(Icons.assignment_outlined, 'طلبات الزبائن', '/admin/requests', Colors.orange),
                    if (PermissionService.has(user, PermissionKeys.completionRequests))
                      _item(Icons.assignment_turned_in_outlined, 'طلبات الإتمام', '/admin/completion-requests', Colors.green,
                          badge: _pendingCompletions),
                  ]),

                  const SizedBox(height: 20),

                  // ─── التصوير والوسائط ───
                  _sectionTitle('التصوير والوسائط'),
                  const SizedBox(height: 10),
                  _buildGrid([
                    if (PermissionService.has(user, PermissionKeys.photographyManagement))
                      _item(Icons.add_a_photo_outlined, 'مهام التصوير', '/admin/photography-management', Colors.cyan),
                    if (PermissionService.has(user, PermissionKeys.mediaReview))
                      _item(Icons.photo_library_outlined, 'إدارة الوسائط', '/admin/media-review', Colors.brown),
                  ]),

                  const SizedBox(height: 20),

                  // ─── المستخدمين والتوثيق ───
                  _sectionTitle('المستخدمين'),
                  const SizedBox(height: 10),
                  _buildGrid([
                    if (PermissionService.has(user, PermissionKeys.manageUsers))
                      _item(Icons.people_outline, 'المستخدمون', '/admin/users', Colors.blueGrey),
                    if (PermissionService.has(user, PermissionKeys.reviewVerifications))
                      _item(Icons.verified_user_outlined, 'طلبات التوثيق', '/admin/review-verifications', Colors.amber),
                    if (PermissionService.has(user, PermissionKeys.fraudSuspects))
                      _item(Icons.security_outlined, 'كشف الاحتيال', '/admin/fraud-suspects', Colors.red),
                  ]),

                  const SizedBox(height: 20),

                  // ─── إضافة عرض ───
                  if (PermissionService.has(user, PermissionKeys.addOfferAdmin))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: () => context.push('/admin/add-offer'),
                          icon: const Icon(Icons.add_home_work),
                          label: const Text('إضافة عرض جديد', style: TextStyle(fontSize: 16)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryGold,
                            foregroundColor: AppTheme.deepBlack,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 10),

                  // ─── رابط للوحة الإدارة الكاملة ───
                  if (user != null && user.isSenior)
                    TextButton.icon(
                      onPressed: () => context.push('/admin/dashboard'),
                      icon: const Icon(Icons.admin_panel_settings, color: AppTheme.textGrey),
                      label: const Text('لوحة الإدارة الكاملة',
                          style: TextStyle(color: AppTheme.textGrey)),
                    ),

                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(title,
        style: const TextStyle(color: AppTheme.primaryGold, fontSize: 16, fontWeight: FontWeight.bold));
  }

  Widget _buildGrid(List<_MenuItem> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.6,
      children: items.map((item) => _card(item)).toList(),
    );
  }

  Widget _card(_MenuItem item) {
    return GestureDetector(
      onTap: () => context.push(item.route),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceBlack,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: item.color.withValues(alpha: 0.25)),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(children: [
              Icon(item.icon, color: item.color, size: 24),
              if (item.badge > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('${item.badge}',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ]),
            const SizedBox(height: 8),
            Text(item.title,
                style: const TextStyle(color: AppTheme.textWhite, fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  _MenuItem _item(IconData icon, String title, String route, Color color, {int badge = 0}) {
    return _MenuItem(icon: icon, title: title, route: route, color: color, badge: badge);
  }
}

class _MenuItem {
  final IconData icon;
  final String title;
  final String route;
  final Color color;
  final int badge;

  _MenuItem({required this.icon, required this.title, required this.route, required this.color, this.badge = 0});
}
