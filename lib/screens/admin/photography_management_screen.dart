import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/services/permission_service.dart';
import '../../core/theme/app_theme.dart';
import '../../models/offer_model.dart';
import '../../models/photography_task_model.dart';
import '../../models/user_model.dart';
import '../../providers/admin_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/photography_provider.dart';

class PhotographyManagementScreen extends StatefulWidget {
  const PhotographyManagementScreen({super.key});

  @override
  State<PhotographyManagementScreen> createState() => _PhotographyManagementScreenState();
}

class _PhotographyManagementScreenState extends State<PhotographyManagementScreen> {
  List<PhotographyTaskModel> _tasks = [];
  List<OfferModel> _offers = [];
  List<UserModel> _photographers = [];
  bool _loading = true;
  int? _filter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final photo = context.read<PhotographyProvider>();
    final admin = context.read<AdminProvider>();
    final results = await Future.wait([
      photo.getAllTasks(status: _filter),
      admin.getOffersForMediaReview(context.read<AuthProvider>().userModel?.uid ?? ''),
      admin.getAllUsers(),
    ]);
    if (!mounted) return;
    final users = results[2] as List<UserModel>;
    setState(() {
      _tasks = results[0] as List<PhotographyTaskModel>;
      _offers = results[1] as List<OfferModel>;
      _photographers = users
          .where((user) => PermissionService.has(user, PermissionKeys.photographerTasks))
          .toList();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.deepBlack,
      appBar: AppBar(
        backgroundColor: AppTheme.deepBlack,
        title: const Text('إدارة مهام التصوير'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_a_photo, color: AppTheme.primaryGold),
            onPressed: _showCreateTaskSheet,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.primaryGold),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGold))
          : RefreshIndicator(
              color: AppTheme.primaryGold,
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _filters(),
                  const SizedBox(height: 12),
                  if (_tasks.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 100),
                      child: Center(child: Text('لا توجد مهام تصوير', style: TextStyle(color: AppTheme.textGrey))),
                    )
                  else
                    ..._tasks.map(_taskCard),
                ],
              ),
            ),
    );
  }

  Widget _filters() {
    final filters = <(String, int?)>[
      ('الكل', null),
      ('بانتظار', 0),
      ('قيد التنفيذ', 1),
      ('مرسلة', 2),
      ('معتمدة', 3),
      ('مرفوضة', 4),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((item) {
          final selected = _filter == item.$2;
          return Padding(
            padding: const EdgeInsets.only(left: 8),
            child: ChoiceChip(
              label: Text(item.$1),
              selected: selected,
              selectedColor: AppTheme.primaryGold,
              backgroundColor: AppTheme.surfaceBlack,
              labelStyle: TextStyle(color: selected ? AppTheme.deepBlack : AppTheme.textWhite),
              side: BorderSide(color: AppTheme.primaryGold.withOpacity(0.25)),
              onSelected: (_) {
                setState(() => _filter = item.$2);
                _load();
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _taskCard(PhotographyTaskModel task) {
    final color = _statusColor(task.sts);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBlack,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.30)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(backgroundColor: color.withOpacity(0.14), child: Icon(Icons.camera_alt, color: color)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(task.ttl.isEmpty ? 'مهمة تصوير' : task.ttl,
                          style: const TextStyle(color: AppTheme.textWhite, fontWeight: FontWeight.bold)),
                      Text(task.statusLabel, style: TextStyle(color: color, fontSize: 12)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.open_in_new, color: AppTheme.primaryGold),
                  onPressed: () => context.push('/offer/${task.offId}'),
                ),
              ],
            ),
            if (task.notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(task.notes, style: const TextStyle(color: AppTheme.textGrey, fontSize: 13)),
            ],
            if (task.photographerNote.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('ملاحظة المصور: ${task.photographerNote}', style: const TextStyle(color: AppTheme.textWhite, fontSize: 12)),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _badge('${task.media.length} وسائط', task.media.isEmpty ? Colors.orange : Colors.green),
                if (task.tsScheduled != null) _badge(_fmtDate(task.tsScheduled!), Colors.blue),
              ],
            ),
            if (task.media.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 76,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: task.media.length,
                  itemBuilder: (_, index) => Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(task.media[index], width: 76, height: 76, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(width: 76, height: 76, color: AppTheme.deepBlack, child: const Icon(Icons.broken_image, color: AppTheme.textGrey))),
                    ),
                  ),
                ),
              ),
            ],
            if (task.isSubmitted) ...[
              const Divider(color: Colors.white12, height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _approveAndAttach(task),
                      icon: const Icon(Icons.check),
                      label: const Text('اعتماد وربط بالعرض'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _rejectTask(task),
                      icon: const Icon(Icons.close, color: AppTheme.errorRed),
                      label: const Text('رفض', style: TextStyle(color: AppTheme.errorRed)),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showCreateTaskSheet() async {
    if (_photographers.isEmpty) {
      _snack('لا يوجد مستخدمون لديهم صلاحية photographer_tasks');
      return;
    }
    OfferModel? selectedOffer;
    UserModel? selectedPhotographer;
    final notesCtrl = TextEditingController();
    DateTime? scheduledAt;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceBlack,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('إنشاء مهمة تصوير', style: TextStyle(color: AppTheme.primaryGold, fontSize: 17, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              DropdownButtonFormField<OfferModel>(
                dropdownColor: AppTheme.surfaceBlack,
                style: const TextStyle(color: AppTheme.textWhite),
                decoration: const InputDecoration(labelText: 'العرض'),
                items: _offers.take(100).map((offer) => DropdownMenuItem(value: offer, child: Text(offer.ttl, overflow: TextOverflow.ellipsis))).toList(),
                onChanged: (value) => setSheet(() => selectedOffer = value),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<UserModel>(
                dropdownColor: AppTheme.surfaceBlack,
                style: const TextStyle(color: AppTheme.textWhite),
                decoration: const InputDecoration(labelText: 'المصور'),
                items: _photographers.map((user) => DropdownMenuItem(value: user, child: Text(user.nm.isEmpty ? user.ph : user.nm))).toList(),
                onChanged: (value) => setSheet(() => selectedPhotographer = value),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesCtrl,
                maxLines: 3,
                style: const TextStyle(color: AppTheme.textWhite),
                decoration: const InputDecoration(labelText: 'ملاحظات التصوير'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  final date = await showDatePicker(
                    context: ctx,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date == null) return;
                  final time = await showTimePicker(context: ctx, initialTime: TimeOfDay.now());
                  if (time == null) return;
                  setSheet(() => scheduledAt = DateTime(date.year, date.month, date.day, time.hour, time.minute));
                },
                icon: const Icon(Icons.schedule, color: AppTheme.primaryGold),
                label: Text(scheduledAt == null ? 'تحديد موعد اختياري' : _fmtDate(scheduledAt!), style: const TextStyle(color: AppTheme.primaryGold)),
              ),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: () async {
                  if (selectedOffer == null || selectedPhotographer == null) {
                    _snack('اختر العرض والمصور');
                    return;
                  }
                  final requestedBy = context.read<AuthProvider>().userModel?.uid ?? '';
                  final ok = await context.read<PhotographyProvider>().createTask(
                        offer: selectedOffer!,
                        photographerId: selectedPhotographer!.uid,
                        requestedBy: requestedBy,
                        notes: notesCtrl.text.trim(),
                        scheduledAt: scheduledAt,
                      );
                  if (!mounted) return;
                  Navigator.pop(ctx);
                  _snack(ok ? 'تم إنشاء مهمة التصوير' : 'فشل إنشاء المهمة');
                  _load();
                },
                icon: const Icon(Icons.save),
                label: const Text('إنشاء المهمة'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _approveAndAttach(PhotographyTaskModel task) async {
    final adminId = context.read<AuthProvider>().userModel?.uid ?? '';
    final ok = await context.read<PhotographyProvider>().attachMediaToOffer(adminId, task);
    _snack(ok ? 'تم اعتماد التصوير وربطه بالعرض' : 'فشل اعتماد التصوير');
    _load();
  }

  Future<void> _rejectTask(PhotographyTaskModel task) async {
    final ctrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceBlack,
        title: const Text('رفض التصوير', style: TextStyle(color: AppTheme.textWhite)),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(color: AppTheme.textWhite),
          decoration: const InputDecoration(labelText: 'سبب الرفض'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('رفض')),
        ],
      ),
    );
    if (reason == null) return;
    final adminId = context.read<AuthProvider>().userModel?.uid ?? '';
    final ok = await context.read<PhotographyProvider>().updateStatus(adminId, task.id, 4, officeNote: reason);
    _snack(ok ? 'تم رفض التصوير' : 'فشل الرفض');
    _load();
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.13),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.30)),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }

  Color _statusColor(int status) {
    switch (status) {
      case 0:
        return Colors.orange;
      case 1:
        return Colors.blue;
      case 2:
        return AppTheme.primaryGold;
      case 3:
        return Colors.green;
      case 4:
        return AppTheme.errorRed;
      default:
        return Colors.grey;
    }
  }

  String _fmtDate(DateTime date) =>
      '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')} '
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}
