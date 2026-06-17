import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../models/executor_task_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/executor_provider.dart';
import '../../widgets/app_back_button.dart';

class MyTasksScreen extends StatefulWidget {
  const MyTasksScreen({super.key});

  @override
  State<MyTasksScreen> createState() => _MyTasksScreenState();
}

class _MyTasksScreenState extends State<MyTasksScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  Timer? _poll;
  bool _loading = true;

  List<ExecutorTaskModel> _today = [];
  List<ExecutorTaskModel> _postponed = [];
  List<ExecutorTaskModel> _completed = [];
  List<Map<String, dynamic>> _pending = [];

  String get _uid => context.read<AuthProvider>().userModel?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    _poll = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_uid.isEmpty) return;
    setState(() => _loading = true);
    final prov = context.read<ExecutorProvider>();
    final results = await Future.wait([
      prov.getMyTasks(_uid),
      prov.getPostponedTasks(_uid),
      prov.getCompletedTasks(_uid),
      prov.getPendingRequests(_uid),
    ]);
    if (!mounted) return;
    setState(() {
      _today = results[0] as List<ExecutorTaskModel>;
      _postponed = results[1] as List<ExecutorTaskModel>;
      _completed = results[2] as List<ExecutorTaskModel>;
      _pending = results[3] as List<Map<String, dynamic>>;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.deepBlack,
      appBar: AppBar(
        leading: const AppBackButton(),
        backgroundColor: AppTheme.deepBlack,
        title: const Text('مهامي', style: TextStyle(color: AppTheme.primaryGold, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: AppTheme.primaryGold), onPressed: _load),
        ],
        bottom: TabBar(
          controller: _tab,
          indicatorColor: AppTheme.primaryGold,
          labelColor: AppTheme.primaryGold,
          unselectedLabelColor: AppTheme.textGrey,
          isScrollable: true,
          tabs: [
            Tab(text: 'اليوم (${_today.length})'),
            Tab(text: 'المؤجلة (${_postponed.length})'),
            Tab(text: 'المنفذة (${_completed.length})'),
            Tab(text: 'بانتظار المراجعة (${_pending.length})'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGold))
          : TabBarView(
              controller: _tab,
              children: [
                _buildTaskList(_today, empty: 'لا توجد مهام اليوم'),
                _buildTaskList(_postponed, empty: 'لا توجد مهام مؤجلة'),
                _buildCompletedList(),
                _buildPendingList(),
              ],
            ),
    );
  }

  // ═══════════════════════════════════════
  // قوائم المهام
  // ═══════════════════════════════════════

  Widget _buildTaskList(List<ExecutorTaskModel> tasks, {required String empty}) {
    if (tasks.isEmpty) return _empty(empty);
    return RefreshIndicator(
      color: AppTheme.primaryGold,
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: tasks.length,
        itemBuilder: (_, i) => _taskCard(tasks[i]),
      ),
    );
  }

  Widget _buildCompletedList() {
    if (_completed.isEmpty) return _empty('لا توجد مهام منفذة');
    return RefreshIndicator(
      color: AppTheme.primaryGold,
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _completed.length,
        itemBuilder: (_, i) => _completedCard(_completed[i]),
      ),
    );
  }

  Widget _buildPendingList() {
    if (_pending.isEmpty) return _empty('لا توجد طلبات إتمام معلقة');
    return RefreshIndicator(
      color: AppTheme.primaryGold,
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _pending.length,
        itemBuilder: (_, i) {
          final r = _pending[i];
          return Card(
            color: AppTheme.surfaceBlack,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.orange,
                child: Icon(Icons.pending_actions, color: Colors.white),
              ),
              title: Text(r['display_title'] ?? '', style: const TextStyle(color: AppTheme.textWhite)),
              subtitle: Text(
                'الحالة: قيد المراجعة من قبل المكتب',
                style: TextStyle(color: Colors.orange.shade300, fontSize: 12),
              ),
            ),
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════
  // بطاقات المهام
  // ═══════════════════════════════════════

  Widget _taskCard(ExecutorTaskModel task) {
    return Card(
      color: AppTheme.surfaceBlack,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              CircleAvatar(
                backgroundColor: AppTheme.primaryGold.withValues(alpha: 0.15),
                child: Icon(
                  task.taskType == 'property' ? Icons.home_work : Icons.directions_car,
                  color: AppTheme.primaryGold,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(task.displayTitle.isEmpty ? 'مهمة' : task.displayTitle,
                      style: const TextStyle(color: AppTheme.textWhite, fontWeight: FontWeight.bold)),
                  Text(task.taskTypeLabel, style: const TextStyle(color: AppTheme.textGrey, fontSize: 12)),
                ]),
              ),
            ]),
            const SizedBox(height: 10),
            _infoRow(Icons.calendar_today, _fmtDate(task.appointmentDate)),
            if (task.locationText.isNotEmpty)
              _infoRow(Icons.location_on_outlined, task.locationText),
            if (task.description.isNotEmpty)
              _infoRow(Icons.notes, task.description),
            if (task.price > 0)
              _infoRow(Icons.monetization_on_outlined, '${task.price} ${task.currency == 0 ? '\$' : 'ل.س'}'),
            const Divider(color: Colors.white12, height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _openExecuteScreen(task),
                icon: const Icon(Icons.play_arrow),
                label: const Text('تنفيذ المهمة'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _completedCard(ExecutorTaskModel task) {
    final color = task.isAccepted ? Colors.green : (task.isRejected ? Colors.red : Colors.orange);
    return Card(
      color: AppTheme.surfaceBlack,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(
            task.isAccepted ? Icons.check : (task.isRejected ? Icons.close : Icons.schedule),
            color: color,
          ),
        ),
        title: Text(task.displayTitle, style: const TextStyle(color: AppTheme.textWhite)),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('النتيجة: ${task.outcomeLabel}', style: TextStyle(color: color, fontSize: 12)),
          if (task.rejectionReason != null && task.rejectionReason!.isNotEmpty)
            Text('السبب: ${task.rejectionReason}', style: const TextStyle(color: Colors.red, fontSize: 11)),
          if (task.completionDate != null)
            Text('تاريخ التنفيذ: ${_fmtDate(task.completionDate!)}', style: const TextStyle(color: AppTheme.textGrey, fontSize: 11)),
        ]),
      ),
    );
  }

  // ═══════════════════════════════════════
  // شاشة التنفيذ
  // ═══════════════════════════════════════

  Future<void> _openExecuteScreen(ExecutorTaskModel task) async {
    final result = await context.push<bool>('/executor/execute/${task.appointmentId}');
    if (result == true && mounted) _load();
  }

  // ═══════════════════════════════════════
  // مساعدات
  // ═══════════════════════════════════════

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        Icon(icon, size: 15, color: AppTheme.textGrey),
        const SizedBox(width: 6),
        Expanded(child: Text(text, style: const TextStyle(color: AppTheme.textGrey, fontSize: 12))),
      ]),
    );
  }

  Widget _empty(String msg) {
    return Center(child: Text(msg, style: const TextStyle(color: AppTheme.textGrey)));
  }

  String _fmtDate(DateTime d) {
    final local = d.toLocal();
    return '${local.year}/${local.month.toString().padLeft(2, '0')}/${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}
