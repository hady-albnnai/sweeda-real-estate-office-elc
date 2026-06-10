import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/photography_task_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/photography_provider.dart';
import '../../services/storage_service.dart';

class PhotographerTasksScreen extends StatefulWidget {
  const PhotographerTasksScreen({super.key});

  @override
  State<PhotographerTasksScreen> createState() => _PhotographerTasksScreenState();
}

class _PhotographerTasksScreenState extends State<PhotographerTasksScreen> {
  List<PhotographyTaskModel> _tasks = [];
  bool _loading = true;
  String _filter = 'active';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final userId = context.read<AuthProvider>().userModel?.uid ?? '';
    final tasks = await context.read<PhotographyProvider>().getPhotographerTasks(userId);
    if (!mounted) return;
    setState(() {
      _tasks = tasks;
      _loading = false;
    });
  }

  List<PhotographyTaskModel> get _filtered {
    switch (_filter) {
      case 'submitted':
        return _tasks.where((task) => task.sts == 2).toList();
      case 'done':
        return _tasks.where((task) => task.sts == 3 || task.sts == 4 || task.sts == 5).toList();
      default:
        return _tasks.where((task) => task.sts == 0 || task.sts == 1).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.deepBlack,
      appBar: AppBar(
        backgroundColor: AppTheme.deepBlack,
        title: const Text('مهام التصوير'),
        actions: [
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
                  if (_filtered.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 100),
                      child: Center(
                        child: Text('لا توجد مهام في هذه الفئة', style: TextStyle(color: AppTheme.textGrey)),
                      ),
                    )
                  else
                    ..._filtered.map(_taskCard),
                ],
              ),
            ),
    );
  }

  Widget _filters() {
    final items = <(String, String)>[
      ('النشطة', 'active'),
      ('مرسلة للمكتب', 'submitted'),
      ('منتهية', 'done'),
    ];
    return Row(
      children: items.map((item) {
        final selected = _filter == item.$2;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: ChoiceChip(
              label: Center(child: Text(item.$1)),
              selected: selected,
              selectedColor: AppTheme.primaryGold,
              backgroundColor: AppTheme.surfaceBlack,
              labelStyle: TextStyle(color: selected ? AppTheme.deepBlack : AppTheme.textWhite),
              side: BorderSide(color: AppTheme.primaryGold.withValues(alpha: 0.25)),
              onSelected: (_) => setState(() => _filter = item.$2),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _taskCard(PhotographyTaskModel task) {
    final color = _statusColor(task.sts);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBlack,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.14),
                  child: Icon(Icons.camera_alt, color: color),
                ),
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
                Text('${task.media.length} وسائط', style: const TextStyle(color: AppTheme.textGrey, fontSize: 11)),
              ],
            ),
            if (task.notes.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(task.notes, style: const TextStyle(color: AppTheme.textGrey, fontSize: 13)),
            ],
            if ((task.loc['d'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, color: AppTheme.primaryGold, size: 16),
                  const SizedBox(width: 4),
                  Expanded(child: Text(task.loc['d'].toString(), style: const TextStyle(color: AppTheme.textGrey, fontSize: 12))),
                ],
              ),
            ],
            if (task.officeNote.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('ملاحظة المكتب: ${task.officeNote}', style: const TextStyle(color: Colors.orange, fontSize: 12)),
            ],
            if (task.isPending || task.isInProgress || task.isRejected) ...[
              const Divider(color: Colors.white12, height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _openSubmitSheet(task),
                  icon: const Icon(Icons.upload),
                  label: Text(task.isRejected ? 'إعادة رفع التصوير' : 'رفع وإرسال التصوير'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openSubmitSheet(PhotographyTaskModel task) async {
    final noteCtrl = TextEditingController(text: task.photographerNote);
    final picked = <XFile>[];
    var uploading = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceBlack,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          return Padding(
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
                const Text('إرسال التصوير للمكتب',
                    style: TextStyle(color: AppTheme.primaryGold, fontSize: 17, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                TextField(
                  controller: noteCtrl,
                  maxLines: 3,
                  style: const TextStyle(color: AppTheme.textWhite),
                  decoration: const InputDecoration(labelText: 'ملاحظات المصور'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: uploading
                      ? null
                      : () async {
                          final files = await StorageService().pickMultiImages(limit: 12);
                          if (files.isNotEmpty) {
                            setSheet(() => picked.addAll(files));
                          }
                        },
                  icon: const Icon(Icons.add_photo_alternate, color: AppTheme.primaryGold),
                  label: Text('اختيار صور (${picked.length})', style: const TextStyle(color: AppTheme.primaryGold)),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: uploading
                      ? null
                      : () async {
                          if (picked.isEmpty && task.media.isEmpty) {
                            _snack('اختر صورة واحدة على الأقل');
                            return;
                          }
                          setSheet(() => uploading = true);
                          final userId = context.read<AuthProvider>().userModel?.uid ?? '';
                          final urls = await StorageService().uploadOfferImages(
                            files: picked,
                            userId: userId,
                            offerId: 'photography_${task.id}',
                          );
                          final media = <String>{...task.media, ...urls}.toList();
                          final ok = await context.read<PhotographyProvider>().submitTask(
                                taskId: task.id,
                                media: media,
                                photographerNote: noteCtrl.text.trim(),
                              );
                          if (!mounted) return;
                          Navigator.pop(ctx);
                          _snack(ok ? 'تم إرسال التصوير للمكتب' : 'فشل إرسال التصوير');
                          _load();
                        },
                  icon: uploading
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.send),
                  label: Text(uploading ? 'جار الرفع...' : 'إرسال للمكتب'),
                ),
              ],
            ),
          );
        },
      ),
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

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}
