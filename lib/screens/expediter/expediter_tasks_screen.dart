import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/expediting_task_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/legal_provider.dart';
import 'expediter_task_detail_screen.dart';

class ExpediterTasksScreen extends StatefulWidget {
  const ExpediterTasksScreen({super.key});

  @override
  State<ExpediterTasksScreen> createState() => _ExpediterTasksScreenState();
}

class _ExpediterTasksScreenState extends State<ExpediterTasksScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final user = context.read<AuthProvider>().userModel;
    if (user != null) {
      await context.read<LegalProvider>().getExpeditingTasks(userUid: user.uid);
    }
  }

  Future<void> _openAccountDetails() async {
    if (!mounted) return;
    context.push('/user/account-info');
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceBlack,
        title: Text('تسجيل الخروج', style: TextStyle(color: AppTheme.textWhite)),
        content: Text('هل تريد تسجيل الخروج من حساب المعقب؟', style: TextStyle(color: AppTheme.textGrey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('إلغاء', style: TextStyle(color: AppTheme.textGrey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تسجيل خروج', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    await context.read<AuthProvider>().logout();
    if (!mounted) return;
    context.go('/user/profile');
  }

  @override
  Widget build(BuildContext context) {
    final tasks = context.watch<LegalProvider>().expeditingTasks;

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      appBar: AppBar(
        title: const Text('مهام تعقيب المعاملات 🏃'),
        backgroundColor: AppTheme.scaffoldBackground,
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle_outlined, color: AppTheme.primaryGold),
            tooltip: 'تفاصيل حسابي',
            onPressed: _openAccountDetails,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.primaryGold),
            tooltip: 'تحديث المهام',
            onPressed: _load,
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            tooltip: 'تسجيل خروج',
            onPressed: _logout,
          ),
        ],
      ),
      body: tasks.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.assignment_late, size: 64, color: AppTheme.textGrey.withOpacity(0.4)),
                  const SizedBox(height: 16),
                  Text(
                    'لا توجد مهام تعقيب حالياً',
                    style: TextStyle(color: AppTheme.textGrey, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'عند إحالة المحامي مهمة لك، ستظهر هنا',
                    style: TextStyle(color: AppTheme.textGrey, fontSize: 13),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: tasks.length,
                itemBuilder: (_, i) {
                  final task = tasks[i];
                  return _TaskCard(
                    task: task,
                    onTap: () => context.push('/expediter/task-detail', extra: task),
                  );
                },
              ),
            ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final ExpeditingTaskModel task;
  final VoidCallback onTap;

  const _TaskCard({required this.task, required this.onTap});

  Color _statusColor(int sts) {
    switch (sts) {
      case 0: return Colors.orange;
      case 1: return Colors.blue;
      case 2: return Colors.green;
      case 3: return Colors.green;
      default: return Colors.grey;
    }
  }

  String _statusText(int sts) {
    switch (sts) {
      case 0: return 'قيد الانتظار';
      case 1: return 'قيد الاستخراج';
      case 2: return 'مكتملة';
      case 3: return 'معتمدة';
      default: return 'غير معروف';
    }
  }

  int _doneCount() {
    return task.checklist.where((c) => c.status == 2).length;
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(task.status);
    final done = _doneCount();
    final total = task.checklist.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.surfaceBlack,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.assignment, color: color, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _statusText(task.status),
                      style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                  Text(
                    task.itemType == 0 ? '🏠 عقار' : '🚗 سيارة',
                    style: const TextStyle(color: AppTheme.primaryGold, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (task.targetPropertyNum.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    'رقم العقار: ${task.targetPropertyNum} | المنطقة: ${task.targetZone}',
                    style: TextStyle(color: AppTheme.textGrey, fontSize: 13),
                  ),
                ),
              Row(
                children: [
                  Icon(Icons.checklist, color: AppTheme.primaryGold, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    '$done / $total وثائق مستخرجة',
                    style: TextStyle(
                      color: done == total ? Colors.green : AppTheme.textGrey,
                      fontSize: 13,
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.chevron_left, color: AppTheme.textGrey),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
