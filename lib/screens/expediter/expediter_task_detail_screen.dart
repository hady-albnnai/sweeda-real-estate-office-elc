import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/app_theme.dart';
import '../../models/expediting_task_model.dart';
import '../../providers/legal_provider.dart';

class ExpediterTaskDetailScreen extends StatefulWidget {
  final ExpeditingTaskModel task;
  const ExpediterTaskDetailScreen({super.key, required this.task});

  @override
  State<ExpediterTaskDetailScreen> createState() => _ExpediterTaskDetailScreenState();
}

class _ExpediterTaskDetailScreenState extends State<ExpediterTaskDetailScreen> {
  late List<ChecklistItemModel> _items;
  late int _taskStatus;
  bool _completingTask = false;

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.task.checklist);
    _taskStatus = widget.task.status;
  }

  void _snack(String m) {
    if (!mounted) return;
    AppTheme.showSnackBar(context, SnackBar(content: Text(m)));
  }

  Future<void> _updateItem(
    ChecklistItemModel item,
    int newSts,
    String inputVal,
    String attachUrl,
    String notes, {
    String attachmentBase64 = '',
    String attachmentContentType = 'image/jpeg',
  }) async {
    final prov = context.read<LegalProvider>();
    final ok = await prov.updateChecklistItem(
      taskId: widget.task.id,
      itemKey: item.key,
      status: newSts,
      inputValue: inputVal,
      attachmentUrl: attachUrl,
      attachmentBase64: attachmentBase64,
      attachmentContentType: attachmentContentType,
      notes: notes,
    );
    if (ok && mounted) {
      _snack('✅ تم تحديث بند "${item.title}" بنجاح');
      setState(() {
        final idx = _items.indexWhere((e) => e.key == item.key);
        if (idx != -1) {
          _items[idx] = ChecklistItemModel(
            key: item.key,
            title: item.title,
            status: newSts,
            inputValue: inputVal,
            attachmentUrl: attachmentBase64.isNotEmpty ? attachUrl : (attachUrl.isNotEmpty ? attachUrl : item.attachmentUrl),
            attachmentSignedUrl: attachmentBase64.isNotEmpty ? '' : item.attachmentSignedUrl,
            notes: notes,
            revisionNotes: item.revisionNotes,
            requiredCopies: item.requiredCopies,
            lawyerInstructions: item.lawyerInstructions,
          );
        }
      });
    } else {
      _snack('فشل تحديث البند');
    }
  }

  bool get _allItemsDone => _items.isNotEmpty && _items.every((item) => item.status == 2);

  Future<void> _completeTask() async {
    if (!_allItemsDone) {
      _snack('يجب تعليم كل البنود كـ تم الاستخراج قبل إتمام المهمة');
      return;
    }

    final notesCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceBlack,
        title: const Text('إتمام مهمة التعقيب', style: TextStyle(color: AppTheme.primaryGold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'سيتم إرسال إشعار للمحامي بأن المهمة اكتملت وبانتظار اعتماده.',
              style: TextStyle(color: AppTheme.textGrey, height: 1.4),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesCtrl,
              maxLines: 3,
              style: const TextStyle(color: AppTheme.textWhite),
              decoration: const InputDecoration(labelText: 'ملاحظات ختامية اختيارية'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء', style: TextStyle(color: AppTheme.textGrey))),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('إتمام وإشعار المحامي')),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    setState(() => _completingTask = true);
    final ok = await context.read<LegalProvider>().completeExpeditingTask(
      taskId: widget.task.id,
      notes: notesCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() => _completingTask = false);
    if (ok) {
      setState(() => _taskStatus = 2);
      _snack('✅ تم إتمام المهمة وإشعار المحامي');
    } else {
      _snack(context.read<LegalProvider>().error ?? 'فشل إتمام المهمة');
    }
  }

  void _showEditDialog(ChecklistItemModel item, {bool forceDone = false}) {
    final inputCtrl = TextEditingController(text: item.inputValue);
    final notesCtrl = TextEditingController(text: item.notes);
    int selectedSts = forceDone ? 2 : item.status;
    String attachmentBase64 = '';
    String attachmentName = '';
    final existingImage = item.attachmentSignedUrl.isNotEmpty
        ? item.attachmentSignedUrl
        : (item.attachmentUrl.startsWith('http') ? item.attachmentUrl : '');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          backgroundColor: AppTheme.surfaceBlack,
          title: Text(item.title, style: const TextStyle(color: AppTheme.primaryGold, fontSize: 16)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGold.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.primaryGold.withOpacity(0.22)),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('عدد النسخ المطلوبة: ${item.requiredCopies}', style: const TextStyle(color: AppTheme.primaryGold, fontWeight: FontWeight.bold, fontSize: 13)),
                    if (item.lawyerInstructions.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text('تعليمات المحامي: ${item.lawyerInstructions}', style: const TextStyle(color: AppTheme.textGrey, fontSize: 12, height: 1.35)),
                    ],
                    if (item.revisionNotes.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text('طلب إعادة من المحامي: ${item.revisionNotes}', style: const TextStyle(color: AppTheme.errorRed, fontSize: 12, height: 1.35)),
                    ],
                  ]),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: selectedSts,
                  dropdownColor: AppTheme.surfaceBlack,
                  style: const TextStyle(color: AppTheme.textWhite),
                  decoration: const InputDecoration(labelText: 'حالة الاستخراج'),
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('مطلوب')),
                    DropdownMenuItem(value: 1, child: Text('قيد الاستخراج ميدانياً')),
                    DropdownMenuItem(value: 2, child: Text('تم الاستخراج والرفع ✅')),
                    DropdownMenuItem(value: 3, child: Text('عائق إداري / نقص أوراق ⚠️')),
                  ],
                  onChanged: (v) => setDlg(() => selectedSts = v ?? 0),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: inputCtrl,
                  style: const TextStyle(color: AppTheme.textWhite),
                  decoration: const InputDecoration(labelText: 'رقم العقار / رقم السيارة / الصحيفة'),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.scaffoldBackground,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.primaryGold.withOpacity(0.22)),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('صورة السند / الوثيقة المستخرجة', style: TextStyle(color: AppTheme.primaryGold, fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 8),
                    if (attachmentBase64.isNotEmpty)
                      Text('تم اختيار صورة: $attachmentName', style: const TextStyle(color: Colors.green, fontSize: 12))
                    else if (existingImage.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(existingImage, height: 130, width: double.infinity, fit: BoxFit.cover),
                      )
                    else
                      const Text('لم يتم إرفاق صورة بعد', style: TextStyle(color: AppTheme.textGrey, fontSize: 12)),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final file = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 82, maxWidth: 1600);
                        if (file == null) return;
                        final bytes = await file.readAsBytes();
                        setDlg(() {
                          attachmentBase64 = base64Encode(bytes);
                          attachmentName = file.name;
                        });
                      },
                      icon: const Icon(Icons.image_search, color: AppTheme.primaryGold),
                      label: Text(existingImage.isNotEmpty || attachmentBase64.isNotEmpty ? 'استبدال الصورة' : 'إرفاق صورة من المعرض', style: const TextStyle(color: AppTheme.primaryGold)),
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: AppTheme.primaryGold)),
                    ),
                  ]),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  maxLines: 2,
                  style: const TextStyle(color: AppTheme.textWhite),
                  decoration: const InputDecoration(labelText: 'ملاحظات المعقب الميدانية'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء', style: TextStyle(color: AppTheme.textGrey))),
            ElevatedButton(
              onPressed: () {
                if (selectedSts == 2 && existingImage.isEmpty && attachmentBase64.isEmpty) {
                  AppTheme.showSnackBar(context, const SnackBar(content: Text('يجب إرفاق صورة السند قبل تعليمه كمكتمل')));
                  return;
                }
                Navigator.pop(ctx);
                _updateItem(
                  item,
                  selectedSts,
                  inputCtrl.text.trim(),
                  item.attachmentUrl,
                  notesCtrl.text.trim(),
                  attachmentBase64: attachmentBase64,
                );
              },
              child: const Text('حفظ الإنجاز'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      appBar: AppBar(
        title: Text(widget.task.itemType == 0 ? 'مهمة استخراج ثبوتيات عقار 🏠' : 'مهمة استخراج ثبوتيات مركبة 🚗'),
        backgroundColor: AppTheme.scaffoldBackground,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.task.itemType == 0)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: AppTheme.surfaceBlack, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.primaryGold)),
                child: Row(
                  children: [
                    const Icon(Icons.home, color: AppTheme.primaryGold),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text('رقم العقار: ${widget.task.targetPropertyNum.isEmpty ? "غير محدد" : widget.task.targetPropertyNum} | المنطقة العقارية: ${widget.task.targetZone.isEmpty ? "غير محددة" : widget.task.targetZone}', style: const TextStyle(color: AppTheme.textWhite, fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            const Text('📋 قائمة الوثائق الرسمية المطلوب استخراجها ميدانياً:', style: TextStyle(color: AppTheme.primaryGold, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ..._items.map((item) {
              final isDone = item.status == 2;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDone ? Colors.green.withOpacity(0.1) : AppTheme.surfaceBlack,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: isDone ? Colors.green : Colors.white12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(isDone ? Icons.check_circle : Icons.radio_button_unchecked, color: isDone ? Colors.green : AppTheme.primaryGold),
                        const SizedBox(width: 10),
                        Expanded(child: Text(item.title, style: const TextStyle(color: AppTheme.textWhite, fontWeight: FontWeight.bold, fontSize: 15))),
                        IconButton(icon: const Icon(Icons.edit, color: AppTheme.primaryGold), onPressed: () => _showEditDialog(item)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text('المطلوب من المحامي: ${item.requiredCopies} نسخة', style: const TextStyle(color: AppTheme.primaryGold, fontSize: 12, fontWeight: FontWeight.w600)),
                    if (item.lawyerInstructions.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text('تعليمات المحامي: ${item.lawyerInstructions}', style: const TextStyle(color: AppTheme.textGrey, fontSize: 12, height: 1.35)),
                    ],
                    if (item.inputValue.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text('البيانات المُدخلة: ${item.inputValue}', style: const TextStyle(color: AppTheme.primaryGold, fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                    if (item.revisionNotes.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text('طلب إعادة من المحامي: ${item.revisionNotes}', style: const TextStyle(color: AppTheme.errorRed, fontSize: 12, height: 1.35)),
                    ],
                    if (item.notes.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text('ملاحظات: ${item.notes}', style: const TextStyle(color: AppTheme.textGrey, fontSize: 12)),
                    ],
                    if (item.attachmentSignedUrl.isNotEmpty || item.attachmentUrl.startsWith('http')) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          item.attachmentSignedUrl.isNotEmpty ? item.attachmentSignedUrl : item.attachmentUrl,
                          height: 120,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: isDone ? null : () => _showEditDialog(item, forceDone: true),
                            icon: const Icon(Icons.check_circle_outline, size: 16),
                            label: const Text('تم الاستخراج ✔️', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _showEditDialog(item),
                            icon: const Icon(Icons.edit_note, size: 16, color: AppTheme.primaryGold),
                            label: const Text('البيانات والمرفق ✏️', style: TextStyle(color: AppTheme.primaryGold, fontSize: 12)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppTheme.primaryGold),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _taskStatus >= 2 ? Colors.green.withOpacity(0.1) : AppTheme.surfaceBlack,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _taskStatus >= 2 ? Colors.green : AppTheme.primaryGold.withOpacity(0.35)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _taskStatus >= 3
                        ? 'تم اعتماد المهمة من المحامي ✅'
                        : _taskStatus == 2
                            ? 'تم إرسال الإنجاز للمحامي — بانتظار الاعتماد ✅'
                            : _allItemsDone
                                ? 'كل البنود مكتملة — يمكنك الآن إتمام المهمة وإشعار المحامي'
                                : 'أكمل كل البنود أولاً حتى يظهر زر إتمام المهمة',
                    style: TextStyle(
                      color: _taskStatus >= 2 || _allItemsDone ? Colors.green : AppTheme.textGrey,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  if (_taskStatus < 2) ...[
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: (!_allItemsDone || _completingTask) ? null : _completeTask,
                      icon: _completingTask
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.deepBlack))
                          : const Icon(Icons.done_all, color: AppTheme.deepBlack),
                      label: Text(
                        _completingTask ? 'جاري الإرسال...' : 'إتمام المهمة وإشعار المحامي',
                        style: const TextStyle(color: AppTheme.deepBlack, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
