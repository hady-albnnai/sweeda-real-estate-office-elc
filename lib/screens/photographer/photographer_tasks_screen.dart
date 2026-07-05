import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/photography_task_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/photography_provider.dart';
import '../../services/storage_service.dart';
import '../../widgets/app_back_button.dart';

class PhotographerTasksScreen extends StatefulWidget {
  const PhotographerTasksScreen({super.key});

  @override
  State<PhotographerTasksScreen> createState() => _PhotographerTasksScreenState();
}

class _PhotographerTasksScreenState extends State<PhotographerTasksScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  List<PhotographyTaskModel> _allTasks = [];
  bool _loading = true;

  // للتبويب المؤجلة — تقويم
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  // حالة رفع الصور لكل مهمة
  String? _expandedTaskId;
  final Map<String, List<XFile>> _tempMedia = {};
  final Map<String, TextEditingController> _notesControllers = {};
  final Map<String, bool> _isUploading = {};

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _tab.dispose();
    for (final c in _notesControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final userId = context.read<AuthProvider>().userModel?.uid ?? '';
    final tasks = await context.read<PhotographyProvider>().getPhotographerTasks(userId);
    if (!mounted) return;
    setState(() {
      _allTasks = tasks;
      _loading = false;
    });
  }

  // ─── فلترة حسب التبويب ───

  List<PhotographyTaskModel> get _todayTasks {
    final now = DateTime.now();
    return _allTasks.where((t) =>
        (t.sts == 0 || t.sts == 1) &&
        (t.tsScheduled == null ||
            (t.tsScheduled!.year == now.year &&
                t.tsScheduled!.month == now.month &&
                t.tsScheduled!.day == now.day))).toList();
  }

  List<PhotographyTaskModel> get _postponedTasks {
    final now = DateTime.now();
    return _allTasks.where((t) =>
        (t.sts == 0 || t.sts == 1) &&
        t.tsScheduled != null &&
        t.tsScheduled!.isAfter(DateTime(now.year, now.month, now.day).add(const Duration(days: 1)))).toList();
  }

  List<PhotographyTaskModel> get _completedTasks {
    return _allTasks.where((t) => t.sts == 2 || t.sts == 3 || t.sts == 4 || t.sts == 5).toList();
  }

  List<PhotographyTaskModel> get _selectedDayTasks {
    if (_selectedDay == null) return [];
    return _postponedTasks.where((t) {
      if (t.tsScheduled == null) return false;
      return t.tsScheduled!.year == _selectedDay!.year &&
          t.tsScheduled!.month == _selectedDay!.month &&
          t.tsScheduled!.day == _selectedDay!.day;
    }).toList();
  }

  // ─── إجراءات المصور ───

  Future<void> _startTask(PhotographyTaskModel task) async {
    if (!task.isInProgress) {
      final userId = context.read<AuthProvider>().userModel?.uid ?? '';
      final ok = await context.read<PhotographyProvider>().startTask(userId, task.id);
      if (!mounted) return;
      if (!ok) {
        _snack('تعذّر بدء المهمة');
        return;
      }
    }
    setState(() {
      _expandedTaskId = task.id;
      _tempMedia[task.id] = [];
      _notesControllers[task.id] = TextEditingController(text: task.photographerNote);
    });
  }

  Future<void> _pickMedia(String taskHash) async {
    final files = await StorageService().pickMultiImages(limit: 20);
    if (files.isNotEmpty) {
      setState(() {
        _tempMedia.putIfAbsent(taskHash, () => []).addAll(files);
      });
    }
  }

  void _removeMedia(String taskHash, int index) {
    setState(() {
      _tempMedia[taskHash]?.removeAt(index);
    });
  }

  Future<void> _submitToOffice(PhotographyTaskModel task) async {
    final taskHash = task.id;
    final media = _tempMedia[taskHash];
    if (media == null || media.isEmpty) {
      _snack('يرجى رفع صورة واحدة على الأقل');
      return;
    }

    setState(() => _isUploading[taskHash] = true);

    final userId = context.read<AuthProvider>().userModel?.uid ?? '';
    final urls = await StorageService().uploadOfferImages(
      files: media,
      userId: userId,
      offerId: 'photography_${task.id}',
    );
    final allMedia = <String>{...task.media, ...urls}.toList();
    final notes = _notesControllers[taskHash]?.text.trim() ?? '';

    final ok = await context.read<PhotographyProvider>().submitTask(
      photographerUid: userId,
      taskId: task.id,
      media: allMedia,
      photographerNote: notes,
    );

    if (!mounted) return;
    setState(() {
      _isUploading[taskHash] = false;
      if (ok) {
        _tempMedia.remove(taskHash);
        _notesControllers[taskHash]?.dispose();
        _notesControllers.remove(taskHash);
        _expandedTaskId = null;
      }
    });
    _snack(ok ? 'تم إرسال التصوير للمكتب ✓' : 'فشل إرسال التصوير');
    if (ok) _load();
  }

  // ─── البناء ───

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      appBar: AppBar(
        leading: const AppBackButton(),
        backgroundColor: AppTheme.scaffoldBackground,
        title: const Text('مهام التصوير',
            style: TextStyle(color: AppTheme.primaryGold, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: AppTheme.primaryGold), onPressed: _load),
        ],
        bottom: TabBar(
          controller: _tab,
          indicatorColor: AppTheme.primaryGold,
          labelColor: AppTheme.primaryGold,
          unselectedLabelColor: AppTheme.textGrey,
          tabs: [
            Tab(text: 'مهام اليوم (${_todayTasks.length})'),
            Tab(text: 'القادمة (${_postponedTasks.length})'),
            Tab(text: 'المنفذة (${_completedTasks.length})'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGold))
          : TabBarView(
              controller: _tab,
              children: [
                _buildTodayTab(),
                _buildPostponedTab(),
                _buildCompletedTab(),
              ],
            ),
    );
  }

  // ─── تبويب مهام اليوم ───

  Widget _buildTodayTab() {
    final tasks = _todayTasks;
    if (tasks.isEmpty) return _empty('لا توجد مهام تصوير اليوم');
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

  // ─── تبويب المؤجلة (مع تقويم) ───

  Widget _buildPostponedTab() {
    final tasks = _postponedTasks;
    if (tasks.isEmpty) return _empty('لا توجد مهام مؤجلة');

    // تجميع المهام حسب التاريخ للتقويم
    final tasksByDate = <DateTime, List<PhotographyTaskModel>>{};
    for (final t in tasks) {
      if (t.tsScheduled != null) {
        final key = DateTime(t.tsScheduled!.year, t.tsScheduled!.month, t.tsScheduled!.day);
        tasksByDate.putIfAbsent(key, () => []).add(t);
      }
    }

    return Column(children: [
      // تقويم بسيط — نعرض الأيام اللي فيها مهام
      Container(
        padding: const EdgeInsets.all(12),
        color: AppTheme.surfaceBlack,
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            IconButton(
              icon: const Icon(Icons.chevron_right, color: AppTheme.primaryGold),
              onPressed: () => setState(() => _focusedDay = DateTime(_focusedDay.year, _focusedDay.month - 1)),
            ),
            Text(
              '${_focusedDay.year} / ${_focusedDay.month}',
              style: const TextStyle(color: AppTheme.primaryGold, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_left, color: AppTheme.primaryGold),
              onPressed: () => setState(() => _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + 1)),
            ),
          ]),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: tasksByDate.keys.map((date) {
              final isSelected = _selectedDay != null &&
                  date.year == _selectedDay!.year &&
                  date.month == _selectedDay!.month &&
                  date.day == _selectedDay!.day;
              final count = tasksByDate[date]!.length;
              return GestureDetector(
                onTap: () => setState(() => _selectedDay = date),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.primaryGold : AppTheme.deepBlack,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.primaryGold.withOpacity(0.4)),
                  ),
                  child: Text(
                    '${date.day}/${date.month} ($count)',
                    style: TextStyle(
                      color: isSelected ? AppTheme.deepBlack : AppTheme.primaryGold,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ]),
      ),
      const SizedBox(height: 8),
      Expanded(
        child: _selectedDayTasks.isEmpty
            ? _empty('اختر يوماً من الأعلى لعرض المهام')
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _selectedDayTasks.length,
                itemBuilder: (_, i) => _taskCard(_selectedDayTasks[i]),
              ),
      ),
    ]);
  }

  // ─── تبويب المنفذة ───

  Widget _buildCompletedTab() {
    final tasks = _completedTasks;
    if (tasks.isEmpty) return _empty('لا توجد مهام منفذة');
    return RefreshIndicator(
      color: AppTheme.primaryGold,
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: tasks.length,
        itemBuilder: (_, i) => _completedCard(tasks[i]),
      ),
    );
  }

  // ─── بطاقة مهمة نشطة ───

  Widget _taskCard(PhotographyTaskModel task) {
    final taskHash = task.id;
    final isExpanded = _expandedTaskId == taskHash;
    final isUploading = _isUploading[taskHash] ?? false;
    final hasMedia = _tempMedia[taskHash]?.isNotEmpty ?? false;
    final color = _statusColor(task.sts);

    return Card(
      color: AppTheme.surfaceBlack,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // رأس البطاقة
          Row(children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.14),
              child: Icon(Icons.camera_alt, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(task.ttl.isEmpty ? 'مهمة تصوير' : task.ttl,
                  style: const TextStyle(color: AppTheme.textWhite, fontWeight: FontWeight.bold)),
              Text(task.statusLabel, style: TextStyle(color: color, fontSize: 12)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('${task.media.length} وسائط',
                  style: TextStyle(color: color, fontSize: 11)),
            ),
          ]),

          // معلومات
          if (task.notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryGold.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.primaryGold.withOpacity(0.2)),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.description, size: 14, color: AppTheme.primaryGold),
                const SizedBox(width: 6),
                Expanded(child: Text(task.notes,
                    style: const TextStyle(color: AppTheme.primaryGold, fontSize: 12))),
              ]),
            ),
          ],
          if ((task.loc['d'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(children: [
              const Icon(Icons.location_on_outlined, color: AppTheme.textGrey, size: 14),
              const SizedBox(width: 4),
              Expanded(child: Text(task.loc['d'].toString(),
                  style: const TextStyle(color: AppTheme.textGrey, fontSize: 12))),
            ]),
          ],
          if (task.tsScheduled != null) ...[
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.schedule, color: AppTheme.textGrey, size: 14),
              const SizedBox(width: 4),
              Text('الموعد: ${_fmtDate(task.tsScheduled!)}',
                  style: const TextStyle(color: AppTheme.textGrey, fontSize: 12)),
            ]),
          ],

          // زر بدء المهمة أو واجهة الرفع
          if (!isExpanded && (task.isPending || task.isInProgress)) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _startTask(task),
                icon: const Icon(Icons.play_arrow),
                label: const Text('بدء المهمة'),
              ),
            ),
          ],

          // واجهة رفع الصور (عند التوسيع)
          if (isExpanded) ...[
            const Divider(color: Colors.white12, height: 20),

            // عرض الصور المختارة
            if ((_tempMedia[taskHash]?.isNotEmpty ?? false))
              Wrap(
                spacing: 8, runSpacing: 8,
                children: _tempMedia[taskHash]!.asMap().entries.map((e) {
                  return Stack(clipBehavior: Clip.none, children: [
                    Container(
                      width: 70, height: 70,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.primaryGold.withOpacity(0.3)),
                        color: AppTheme.deepBlack,
                      ),
                      child: const Center(child: Icon(Icons.image, color: AppTheme.textGrey)),
                    ),
                    Positioned(
                      top: -6, right: -6,
                      child: GestureDetector(
                        onTap: () => _removeMedia(taskHash, e.key),
                        child: const CircleAvatar(
                          radius: 10,
                          backgroundColor: Colors.red,
                          child: Icon(Icons.close, size: 12, color: Colors.white),
                        ),
                      ),
                    ),
                  ]);
                }).toList(),
              ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: isUploading ? null : () => _pickMedia(taskHash),
              icon: const Icon(Icons.add_photo_alternate, color: AppTheme.primaryGold),
              label: Text('إضافة صور (${_tempMedia[taskHash]?.length ?? 0})',
                  style: const TextStyle(color: AppTheme.primaryGold)),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _notesControllers.putIfAbsent(taskHash, () => TextEditingController(text: task.photographerNote)),
              maxLines: 2,
              style: const TextStyle(color: AppTheme.textWhite),
              decoration: const InputDecoration(labelText: 'ملاحظات (اختياري)'),
            ),
            const SizedBox(height: 10),
            if (hasMedia && !isUploading)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _submitToOffice(task),
                  icon: const Icon(Icons.send),
                  label: const Text('إرسال إلى المكتب'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                ),
              ),
            if (isUploading)
              const Center(child: Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(color: AppTheme.primaryGold),
              )),
          ],

          // ملاحظة المكتب (للمرفوضة)
          if (task.officeNote.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('ملاحظة المكتب: ${task.officeNote}',
                style: const TextStyle(color: Colors.orange, fontSize: 12)),
          ],

          // إعادة الرفع (للمرفوضة)
          if (task.isRejected && !isExpanded) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _startTask(task),
                icon: const Icon(Icons.replay),
                label: const Text('إعادة رفع التصوير'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              ),
            ),
          ],
        ]),
      ),
    );
  }

  // ─── بطاقة مهمة منفذة ───

  Widget _completedCard(PhotographyTaskModel task) {
    final color = _statusColor(task.sts);
    return Card(
      color: AppTheme.surfaceBlack,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.14),
          child: Icon(
            task.isApproved ? Icons.check : (task.isRejected ? Icons.close : Icons.schedule),
            color: color,
          ),
        ),
        title: Text(task.ttl.isEmpty ? 'مهمة تصوير' : task.ttl,
            style: const TextStyle(color: AppTheme.textWhite)),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(task.statusLabel, style: TextStyle(color: color, fontSize: 12)),
          Text('${task.media.length} وسائط',
              style: const TextStyle(color: AppTheme.textGrey, fontSize: 11)),
          if (task.isSubmitted)
            const Text('بانتظار معالجة المكتب',
                style: TextStyle(color: Colors.purple, fontSize: 11)),
        ]),
      ),
    );
  }

  // ─── مساعدات ───

  Color _statusColor(int status) {
    switch (status) {
      case 0: return Colors.orange;
      case 1: return Colors.blue;
      case 2: return AppTheme.primaryGold;
      case 3: return Colors.green;
      case 4: return AppTheme.errorRed;
      default: return Colors.grey;
    }
  }

  Widget _empty(String msg) {
    return Center(child: Text(msg, style: const TextStyle(color: AppTheme.textGrey)));
  }

  String _fmtDate(DateTime d) {
    final l = d.toLocal();
    return '${l.year}/${l.month.toString().padLeft(2, '0')}/${l.day.toString().padLeft(2, '0')} '
        '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  }

  void _snack(String msg) {
    if (!mounted) return;
    AppTheme.showSnackBar(context, SnackBar(content: Text(msg)));
  }
}
