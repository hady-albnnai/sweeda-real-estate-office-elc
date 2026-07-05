import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/executor_provider.dart';

/// شاشة مراجعة طلبات الإتمام — للمدير/النائب/الموظف
class CompletionRequestsScreen extends StatefulWidget {
  const CompletionRequestsScreen({super.key});

  @override
  State<CompletionRequestsScreen> createState() =>
      _CompletionRequestsScreenState();
}

class _CompletionRequestsScreenState extends State<CompletionRequestsScreen> {
  List<Map<String, dynamic>> _requests = [];
  bool _loading = true;

  String get _uid => context.read<AuthProvider>().userModel?.uid ?? '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final prov = context.read<ExecutorProvider>();
    final data = await prov.getPendingRequests(_uid);
    if (!mounted) return;
    setState(() {
      _requests = data;
      _loading = false;
    });
  }

  Future<void> _approve(Map<String, dynamic> req) async {
    final requestId = req['request_id']?.toString() ?? '';
    if (requestId.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceBlack,
        title: const Text('تأكيد الموافقة',
            style: TextStyle(color: AppTheme.primaryGold)),
        content: Text(
          'الموافقة على إتمام المعاملة للعرض:\n${req['display_title'] ?? ''}',
          style: TextStyle(color: AppTheme.textWhite),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('موافقة')),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _loading = true);
    final ok = await context
        .read<ExecutorProvider>()
        .processCompletionRequest(_uid, requestId, 'approved', '');
    _snack(ok ? 'تمت الموافقة ✓' : 'فشلت العملية');
    _load();
  }

  Future<void> _reject(Map<String, dynamic> req) async {
    final requestId = req['request_id']?.toString() ?? '';
    if (requestId.isEmpty) return;

    final ctrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceBlack,
        title:
            Text('رفض الطلب', style: TextStyle(color: AppTheme.textWhite)),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          style: TextStyle(color: AppTheme.textWhite),
          decoration: const InputDecoration(hintText: 'سبب الرفض (اختياري)...'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('رفض'),
          ),
        ],
      ),
    );
    if (reason == null) return;

    setState(() => _loading = true);
    final ok = await context
        .read<ExecutorProvider>()
        .processCompletionRequest(_uid, requestId, 'rejected', reason);
    _snack(ok ? 'تم الرفض' : 'فشلت العملية');
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.scaffoldBackground,
        title: const Text('طلبات إتمام المعاملات',
            style: TextStyle(color: AppTheme.primaryGold)),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh, color: AppTheme.primaryGold),
              onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryGold))
          : _requests.isEmpty
              ? Center(
                  child: Text('لا توجد طلبات إتمام معلقة',
                      style: TextStyle(color: AppTheme.textGrey)))
              : RefreshIndicator(
                  color: AppTheme.primaryGold,
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _requests.length,
                    itemBuilder: (_, i) => _requestCard(_requests[i]),
                  ),
                ),
    );
  }

  Widget _requestCard(Map<String, dynamic> req) {
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
                backgroundColor: Colors.blue.withOpacity(0.15),
                child: const Icon(Icons.assignment_turned_in, color: Colors.blue),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(req['display_title'] ?? 'طلب إتمام',
                          style: TextStyle(
                              color: AppTheme.textWhite,
                              fontWeight: FontWeight.bold)),
                      Text(
                          req['task_type'] == 'property' ? 'عقار' : 'سيارة',
                          style: TextStyle(
                              color: AppTheme.textGrey, fontSize: 12)),
                    ]),
              ),
            ]),
            const SizedBox(height: 10),
            if ((req['executor_name'] ?? '').isNotEmpty)
              _info('المنفذ', req['executor_name']),
            if ((req['executor_notes'] ?? '').isNotEmpty)
              _info('ملاحظات المنفذ', req['executor_notes']),
            if (req['appointment_date'] != null)
              _info('تاريخ الموعد', _fmtDate(DateTime.parse(req['appointment_date']))),
            if (req['request_date'] != null)
              _info('تاريخ الطلب', _fmtDate(DateTime.parse(req['request_date']))),
            const Divider(color: Colors.white12, height: 20),
            Row(children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _approve(req),
                  icon: const Icon(Icons.check),
                  label: const Text('موافقة'),
                  style:
                      ElevatedButton.styleFrom(backgroundColor: Colors.green),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _reject(req),
                  icon: const Icon(Icons.close, color: AppTheme.errorRed),
                  label: const Text('رفض',
                      style: TextStyle(color: AppTheme.errorRed)),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _info(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
            width: 100,
            child: Text(label,
                style:
                    TextStyle(color: AppTheme.textGrey, fontSize: 12))),
        Expanded(
            child: Text(value,
                style:
                    TextStyle(color: AppTheme.textWhite, fontSize: 12))),
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
