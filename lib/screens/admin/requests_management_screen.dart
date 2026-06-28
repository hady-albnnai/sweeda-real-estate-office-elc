import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/admin_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/request_model.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_utils.dart';

/// شاشة إدارة طلبات البحث — تعرض بيانات العميل (clNm + clPh) للإدارة فقط
class RequestsManagementScreen extends StatefulWidget {
  const RequestsManagementScreen({super.key});

  @override
  State<RequestsManagementScreen> createState() =>
      _RequestsManagementScreenState();
}

class _RequestsManagementScreenState extends State<RequestsManagementScreen> {
  List<RequestModel> _all      = [];
  List<RequestModel> _filtered = [];
  bool _loading = true;
  int  _filterSts = -1; // -1 = الكل
  String _search  = '';

  static const _statusLabels = {
    0: 'نشط',
    1: 'قيد المعالجة',
    2: 'تمت تلبيته',
    3: 'ملغي',
    4: 'منتهي الصلاحية',
  };
  static const _statusColors = {
    0: Colors.green,
    1: Colors.orange,
    2: Colors.blue,
    3: Colors.grey,
    4: Colors.deepOrange,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final adminUid =
        context.read<AuthProvider>().userModel?.uid ?? '';
    final list =
        await context.read<AdminProvider>().getAllRequests(adminUid);
    if (mounted) {
      setState(() {
        _all     = list;
        _loading = false;
        _applyFilter();
      });
    }
  }

  void _applyFilter() {
    setState(() {
      _filtered = _all.where((r) {
        final matchSts = _filterSts == -1 || r.sts == _filterSts;
        final q = _search.toLowerCase();
        final matchSearch = q.isEmpty ||
            r.clNm.toLowerCase().contains(q) ||
            r.clPh.contains(q) ||
            r.notes.toLowerCase().contains(q);
        return matchSts && matchSearch;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.deepBlack,
      appBar: AppBar(
        title: const Text('إدارة الطلبات'),
        backgroundColor: AppTheme.deepBlack,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.primaryGold),
            onPressed: _load,
          ),
        ],
      ),
      body: Column(children: [
        // شريط البحث
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: TextField(
            onChanged: (v) {
              _search = v;
              _applyFilter();
            },
            style: const TextStyle(color: AppTheme.textWhite),
            decoration: InputDecoration(
              hintText: 'بحث باسم العميل أو هاتفه...',
              hintStyle: const TextStyle(color: AppTheme.textGrey),
              prefixIcon:
                  const Icon(Icons.search, color: AppTheme.textGrey),
              filled: true,
              fillColor: AppTheme.surfaceBlack,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
            ),
          ),
        ),
        // فلتر الحالة
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            children: [
              _chip('الكل', -1),
              ..._statusLabels.entries.map((e) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _chip(e.value, e.key),
                  )),
            ],
          ),
        ),
        // القائمة
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(
                      color: AppTheme.primaryGold))
              : _filtered.isEmpty
                  ? const Center(
                      child: Text('لا توجد طلبات',
                          style: TextStyle(color: AppTheme.textGrey)))
                  : RefreshIndicator(
                      color: AppTheme.primaryGold,
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _filtered.length,
                        itemBuilder: (_, i) => _card(_filtered[i]),
                      ),
                    ),
        ),
      ]),
    );
  }

  Widget _chip(String label, int value) {
    final selected = _filterSts == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label,
            style: TextStyle(
              color: selected ? AppTheme.deepBlack : AppTheme.textWhite,
              fontWeight:
                  selected ? FontWeight.bold : FontWeight.normal,
            )),
        selected: selected,
        selectedColor: AppTheme.primaryGold,
        backgroundColor: AppTheme.surfaceBlack,
        checkmarkColor: AppTheme.deepBlack,
        side: BorderSide(
            color: AppTheme.primaryGold.withOpacity(0.3)),
        onSelected: (_) {
          _filterSts = value;
          _applyFilter();
        },
      ),
    );
  }

  Widget _card(RequestModel r) {
    final stsColor = _statusColors[r.sts] ?? Colors.grey;
    final stsLabel = _statusLabels[r.sts] ?? '—';
    final typeLabel = r.typ == 0 ? 'شراء' : 'استئجار';
    final elmLabel  = r.elm == 0 ? 'عقار' : 'سيارة';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBlack,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: AppTheme.primaryGold.withOpacity(0.15)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // الرأس
        Row(children: [
          Icon(
            r.elm == 0 ? Icons.home_outlined : Icons.directions_car,
            color: AppTheme.primaryGold,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$typeLabel $elmLabel',
              style: const TextStyle(
                  color: AppTheme.textWhite,
                  fontWeight: FontWeight.bold,
                  fontSize: 14),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: stsColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
              border:
                  Border.all(color: stsColor.withOpacity(0.5)),
            ),
            child: Text(stsLabel,
                style: TextStyle(
                    color: stsColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold)),
          ),
        ]),
        const Divider(color: Colors.white12, height: 14),

        // بيانات العميل — تظهر للإدارة فقط
        _infoRow(Icons.person_outline, 'العميل', r.clNm.isEmpty ? '—' : r.clNm),
        _infoRow(Icons.phone_outlined, 'الهاتف', r.clPh.isEmpty ? '—' : r.clPh,
            color: AppTheme.primaryGold),

        if (r.prc > 0)
          _infoRow(
            Icons.attach_money,
            'الميزانية',
            '${r.prc.toStringAsFixed(0)} ${r.cur == 0 ? '\$' : 'ل.س'}',
          ),

        if (r.notes.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text('ملاحظات: ${r.notes}',
              style: const TextStyle(
                  color: AppTheme.textGrey, fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
        ],

        if (r.specs.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            'المواصفات: ${(r.specs['details'] ?? r.specs.toString())}',
            style: const TextStyle(color: AppTheme.textGrey, fontSize: 11),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],

        const SizedBox(height: 6),
        Text(
          'تاريخ الطلب: ${AppUtils.formatTimestamp(r.tsCrt)}',
          style: const TextStyle(color: AppTheme.textGrey, fontSize: 11),
        ),
        if (r.tsEnd != null)
          _infoRow(Icons.hourglass_bottom, 'ينتهي في',
              AppUtils.formatTimestamp(r.tsEnd!)),
        if (r.closedAt != null) ...[
          const Divider(color: Colors.white12, height: 14),
          _infoRow(Icons.lock_clock, 'أُغلق في',
              AppUtils.formatTimestamp(r.closedAt!)),
          _infoRow(Icons.verified_user_outlined, 'أغلقه',
              r.closedByName.isEmpty ? (r.closedBy.isEmpty ? 'النظام' : r.closedBy) : r.closedByName),
          if (r.closedReason.isNotEmpty)
            _infoRow(Icons.info_outline, 'سبب الإغلاق', r.closedReason),
          if (r.closedNote.isNotEmpty)
            _infoRow(Icons.notes, 'ملاحظة الإغلاق', r.closedNote),
        ],
        if (r.isOpen || r.isExpired) ...[
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _closeRequest(r, 3),
                icon: const Icon(Icons.cancel_outlined, color: AppTheme.errorRed, size: 18),
                label: const Text('إغلاق/إلغاء', style: TextStyle(color: AppTheme.errorRed)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _closeRequest(r, 2),
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: const Text('تمت تلبيته'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              ),
            ),
          ]),
        ],
      ]),
    );
  }

  Future<void> _closeRequest(RequestModel r, int status) async {
    final ctrl = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceBlack,
        title: Text(
          status == 2 ? 'تمييز الطلب كتمت تلبيته' : 'إغلاق الطلب',
          style: const TextStyle(color: AppTheme.primaryGold),
        ),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          style: const TextStyle(color: AppTheme.textWhite),
          decoration: const InputDecoration(hintText: 'سبب/ملاحظة الإغلاق...'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (note == null) return;

    final adminUid = context.read<AuthProvider>().userModel?.uid ?? '';
    final ok = await context.read<AdminProvider>().closeRequest(
          adminUid,
          r.id,
          status,
          reason: status == 2 ? 'fulfilled_by_admin' : 'closed_by_admin',
          note: note,
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'تم تحديث حالة الطلب' : 'فشل تحديث حالة الطلب')),
    );
    if (ok) _load();
  }

  Widget _infoRow(IconData icon, String label, String value,
      {Color color = AppTheme.textWhite}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        Icon(icon, color: AppTheme.textGrey, size: 14),
        const SizedBox(width: 6),
        Text('$label: ',
            style: const TextStyle(
                color: AppTheme.textGrey, fontSize: 12)),
        Expanded(
          child: Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
        ),
      ]),
    );
  }
}
