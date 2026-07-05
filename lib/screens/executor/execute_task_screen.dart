import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/executor_provider.dart';
import '../../widgets/app_back_button.dart';

class ExecuteTaskScreen extends StatefulWidget {
  final String appointmentId;
  const ExecuteTaskScreen({super.key, required this.appointmentId});

  @override
  State<ExecuteTaskScreen> createState() => _ExecuteTaskScreenState();
}

class _ExecuteTaskScreenState extends State<ExecuteTaskScreen> {
  final _notesCtrl = TextEditingController();
  final _rejectCtrl = TextEditingController();
  bool _loading = false;
  Map<String, dynamic>? _task;

  String get _uid => context.read<AuthProvider>().userModel?.uid ?? '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadTask());
  }

  Future<void> _loadTask() async {
    setState(() => _loading = true);
    final prov = context.read<ExecutorProvider>();
    final t = await prov.getTaskByAppointment(_uid, widget.appointmentId);
    if (t != null) {
      setState(() {
        _task = {
          'appointment_id': t.appointmentId,
          'display_title': t.displayTitle,
          'task_type': t.taskTypeLabel,
          'price': t.price > 0 ? '${t.price}' : '',
          'location': t.locationText,
          'description': t.description,
          'appointment_date': _fmtDate(t.appointmentDate),
        };
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    _rejectCtrl.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════
  // تأجيل
  // ═══════════════════════════════════════

  Future<void> _reschedule() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (time == null || !mounted) return;

    final newDt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    if (newDt.isBefore(DateTime.now())) {
      _snack('لا يمكن اختيار وقت ماضي');
      return;
    }

    setState(() => _loading = true);
    final ok = await context.read<ExecutorProvider>().postponeTask(
      _uid, widget.appointmentId, newDt, _notesCtrl.text.trim(),
    );
    setState(() => _loading = false);
    if (!mounted) return;
    if (ok) {
      _snack('تم تأجيل المهمة ✓');
      context.pop(true);
    } else {
      _snack('فشل التأجيل');
    }
  }

  // ═══════════════════════════════════════
  // رفض
  // ═══════════════════════════════════════

  Future<void> _reject() async {
    _rejectCtrl.clear();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceBlack,
        title: const Text('سبب الرفض', style: TextStyle(color: AppTheme.textWhite)),
        content: TextField(
          controller: _rejectCtrl,
          maxLines: 3,
          style: const TextStyle(color: AppTheme.textWhite),
          decoration: const InputDecoration(hintText: 'اكتب سبب الرفض...'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, _rejectCtrl.text.trim()),
            child: const Text('تأكيد الرفض'),
          ),
        ],
      ),
    );
    if (reason == null || reason.isEmpty) return;

    setState(() => _loading = true);
    final ok = await context.read<ExecutorProvider>().rejectTask(
      _uid, widget.appointmentId, reason, _notesCtrl.text.trim(),
    );
    setState(() => _loading = false);
    if (!mounted) return;
    if (ok) {
      _snack('تم تسجيل الرفض');
      context.pop(true);
    } else {
      _snack('فشل الرفض');
    }
  }

  // ═══════════════════════════════════════
  // طلب إتمام
  // ═══════════════════════════════════════

  Future<void> _requestCompletion() async {
    setState(() => _loading = true);
    final ok = await context.read<ExecutorProvider>().requestCompletion(
      _uid, widget.appointmentId, _notesCtrl.text.trim(),
    );
    setState(() => _loading = false);
    if (!mounted) return;
    if (ok) {
      _snack('تم إرسال طلب الإتمام — سيراجعه المكتب ✓');
      context.pop(true);
    } else {
      _snack('فشل الإرسال — قد يكون هناك طلب معلق مسبقاً');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      appBar: AppBar(
        leading: const AppBackButton(),
        backgroundColor: AppTheme.scaffoldBackground,
        title: const Text('تنفيذ المهمة', style: TextStyle(color: AppTheme.primaryGold)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGold))
          : _task == null
              ? const Center(child: Text('لم يتم العثور على المهمة', style: TextStyle(color: AppTheme.textGrey)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(children: [
                    // معلومات العرض
                    _card('معلومات المهمة', [
                      _row('العنوان', _task!['display_title'] ?? ''),
                      _row('النوع', _task!['task_type'] ?? ''),
                      if ((_task!['price'] ?? '').isNotEmpty) _row('السعر', _task!['price']),
                      if ((_task!['location'] ?? '').isNotEmpty) _row('الموقع', _task!['location']),
                      _row('الموعد', _task!['appointment_date'] ?? ''),
                    ]),

                    if ((_task!['description'] ?? '').isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _card('تفاصيل العرض', [
                        Text(_task!['description'], style: const TextStyle(color: AppTheme.textGrey, fontSize: 13)),
                      ]),
                    ],

                    const SizedBox(height: 16),

                    // ملاحظات المنفذ
                    _card('ملاحظاتي', [
                      TextField(
                        controller: _notesCtrl,
                        maxLines: 3,
                        style: const TextStyle(color: AppTheme.textWhite),
                        decoration: const InputDecoration(
                          hintText: 'أدخل ملاحظات...',
                          hintStyle: TextStyle(color: AppTheme.textGrey),
                        ),
                      ),
                    ]),

                    const SizedBox(height: 24),

                    // أزرار الإجراءات
                    Row(children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _loading ? null : _reschedule,
                          icon: const Icon(Icons.schedule),
                          label: const Text('تأجيل'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _loading ? null : _reject,
                          icon: const Icon(Icons.cancel),
                          label: const Text('رفض'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ]),

                    const SizedBox(height: 14),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _loading ? null : _requestCompletion,
                        icon: const Icon(Icons.send),
                        label: const Text('طلب إتمام المعاملة'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ]),
                ),
    );
  }

  Widget _card(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBlack,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(color: AppTheme.primaryGold, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...children,
      ]),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 90, child: Text(label, style: const TextStyle(color: AppTheme.textGrey, fontSize: 13))),
        Expanded(child: Text(value, style: const TextStyle(color: AppTheme.textWhite, fontSize: 13))),
      ]),
    );
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
