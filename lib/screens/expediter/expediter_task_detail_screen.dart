import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.task.checklist);
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _updateItem(ChecklistItemModel item, int newSts, String inputVal, String attachUrl, String notes) async {
    final prov = context.read<LegalProvider>();
    final ok = await prov.updateChecklistItem(
      taskId: widget.task.id,
      itemKey: item.key,
      status: newSts,
      inputValue: inputVal,
      attachmentUrl: attachUrl,
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
            attachmentUrl: attachUrl,
            notes: notes,
          );
        }
      });
    } else {
      _snack('فشل تحديث البند');
    }
  }

  void _showEditDialog(ChecklistItemModel item) {
    final inputCtrl = TextEditingController(text: item.inputValue);
    final attachCtrl = TextEditingController(text: item.attachmentUrl);
    final notesCtrl = TextEditingController(text: item.notes);
    int selectedSts = item.status;

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
                TextField(
                  controller: attachCtrl,
                  style: const TextStyle(color: AppTheme.textWhite),
                  decoration: const InputDecoration(labelText: 'رابط صورة السند المستخرج'),
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
                Navigator.pop(ctx);
                _updateItem(item, selectedSts, inputCtrl.text.trim(), attachCtrl.text.trim(), notesCtrl.text.trim());
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
      backgroundColor: AppTheme.deepBlack,
      appBar: AppBar(
        title: Text(widget.task.itemType == 0 ? 'مهمة استخراج ثبوتيات عقار 🏠' : 'مهمة استخراج ثبوتيات مركبة 🚗'),
        backgroundColor: AppTheme.deepBlack,
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
                    if (item.inputValue.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text('البيانات المُدخلة: ${item.inputValue}', style: const TextStyle(color: AppTheme.primaryGold, fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                    if (item.notes.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text('ملاحظات: ${item.notes}', style: const TextStyle(color: AppTheme.textGrey, fontSize: 12)),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: isDone ? null : () => _updateItem(item, 2, item.inputValue, item.attachmentUrl, item.notes),
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
          ],
        ),
      ),
    );
  }
}
