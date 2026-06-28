import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/admin_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/deal_model.dart';
import '../../core/theme/app_theme.dart';

/// 🤝 إدارة الصفقات — عرض + إتمام + تسجيل العمولة
class DealsManagementScreen extends StatefulWidget {
  const DealsManagementScreen({super.key});

  @override
  State<DealsManagementScreen> createState() => _DealsManagementScreenState();
}

class _DealsManagementScreenState extends State<DealsManagementScreen> {
  List<DealModel> _all = [];
  bool _loading = true;
  int _filter = -1; // -1=الكل, 0=نشطة, 1=مكتملة

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final adminUid = context.read<AuthProvider>().userModel?.uid ?? '';
    final list = await context.read<AdminProvider>().getAllDeals(adminUid);
    if (mounted) {
      setState(() {
        _all = list;
        _loading = false;
      });
    }
  }

  List<DealModel> get _filtered =>
      _filter == -1 ? _all : _all.where((d) => d.sts == _filter).toList();

  double get _totalCommission =>
      _all.where((d) => d.sts == 1).fold<double>(0, (s, d) => s + d.comVal);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.deepBlack,
      appBar: AppBar(
        title: const Text('إدارة الصفقات'),
        backgroundColor: AppTheme.deepBlack,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.primaryGold),
            onPressed: _load,
          ),
        ],
      ),
      body: Column(
        children: [
          // ملخّص العمولات
          Container(
            margin: const EdgeInsets.all(14),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryGold.withOpacity(0.25),
                  AppTheme.surfaceBlack
                ],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.primaryGold.withOpacity(0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.account_balance,
                    color: AppTheme.primaryGold, size: 34),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('إجمالي عمولات المكتب',
                        style: TextStyle(color: AppTheme.textGrey, fontSize: 12)),
                    Text('${_totalCommission.toStringAsFixed(0)} \$',
                        style: const TextStyle(
                            color: AppTheme.primaryGold,
                            fontSize: 24,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _chip('الكل', -1),
                _chip('نشطة', 0),
                _chip('مكتملة', 1),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppTheme.primaryGold))
                : _filtered.isEmpty
                    ? const Center(
                        child: Text('لا توجد صفقات',
                            style: TextStyle(color: AppTheme.textGrey)))
                    : RefreshIndicator(
                        color: AppTheme.primaryGold,
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _filtered.length,
                          itemBuilder: (_, i) => _dealTile(_filtered[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, int value) {
    final selected = _filter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label,
            style: TextStyle(
              color: selected ? AppTheme.deepBlack : AppTheme.textWhite,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            )),
        selected: selected,
        selectedColor: AppTheme.primaryGold,
        backgroundColor: AppTheme.surfaceBlack,
        checkmarkColor: AppTheme.deepBlack,
        side: BorderSide(color: AppTheme.primaryGold.withOpacity(0.3)),
        onSelected: (_) => setState(() => _filter = value),
      ),
    );
  }

  Widget _dealTile(DealModel d) {
    final done = d.sts == 1;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBlack,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primaryGold.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('صفقة #${_short(d.id)}',
                  style: const TextStyle(
                      color: AppTheme.textWhite, fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: (done ? Colors.green : Colors.orange).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: (done ? Colors.green : Colors.orange).withOpacity(0.5)),
                ),
                child: Text(done ? 'مكتملة' : 'نشطة',
                    style: TextStyle(
                        color: done ? Colors.green : Colors.orange, fontSize: 11)),
              ),
            ],
          ),
          const Divider(color: Colors.white12, height: 18),
          _row('السعر النهائي',
              '${d.finPrc.toStringAsFixed(0)} ${d.cur == 0 ? '\$' : 'ل.س'}'),
          _row('نسبة العمولة', '${d.comPct.toStringAsFixed(1)}%'),
          _row('قيمة العمولة', '${d.comVal.toStringAsFixed(0)} \$', highlight: true),
          if (d.comNote != null && d.comNote!.isNotEmpty)
            _row('ملاحظة', d.comNote!),
          if (!done)
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: ElevatedButton.icon(
                  onPressed: () => _completeDialog(d),
                  icon: const Icon(Icons.check_circle, size: 18),
                  label: const Text('إتمام الصفقة'),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _completeDialog(DealModel d) async {
    final comCtrl = TextEditingController(text: d.comVal.toStringAsFixed(0));
    final noteCtrl = TextEditingController(text: d.comNote ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceBlack,
        title: const Text('إتمام الصفقة',
            style: TextStyle(color: AppTheme.primaryGold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: comCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: AppTheme.textWhite),
              decoration: const InputDecoration(labelText: 'قيمة العمولة (\$)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              style: const TextStyle(color: AppTheme.textWhite),
              decoration: const InputDecoration(labelText: 'ملاحظة (اختياري)'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء', style: TextStyle(color: AppTheme.textGrey))),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('تأكيد')),
        ],
      ),
    );

    if (ok == true && mounted) {
      final adminId = context.read<AuthProvider>().userModel?.uid ?? '';
      final com = double.tryParse(comCtrl.text.trim()) ?? d.comVal;
      if (await context.read<AdminProvider>().completeDeal(d.id, adminId,
          commission: com, note: noteCtrl.text.trim())) {
        _snack('تم إتمام الصفقة');
        _load();
      }
    }
  }

  Widget _row(String label, String value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(color: AppTheme.textGrey, fontSize: 13)),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.left,
                style: TextStyle(
                    color: highlight ? AppTheme.primaryGold : AppTheme.textWhite,
                    fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13)),
          ),
        ],
      ),
    );
  }

  String _short(String s) => s.length >= 8 ? s.substring(0, 8) : s;

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
