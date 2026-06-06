import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/request_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/request_model.dart';
import '../../models/offer_model.dart';
import '../../core/services/business_service.dart';
import '../../core/network/supabase_service.dart';
import '../../core/constants/db_constants.dart';
import '../../core/theme/app_theme.dart';

/// شاشة تفاصيل طلب البحث + العروض المطابقة
class RequestDetailScreen extends StatefulWidget {
  final String requestId;
  const RequestDetailScreen({super.key, required this.requestId});

  @override
  State<RequestDetailScreen> createState() => _RequestDetailScreenState();
}

class _RequestDetailScreenState extends State<RequestDetailScreen> {
  RequestModel? _request;
  List<OfferModel> _matches = [];
  bool _loading = true;
  bool _deleting = false;
  final _biz = BusinessService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await SupabaseService()
          .client
          .from(DbTables.requests)
          .select()
          .eq('id', widget.requestId)
          .maybeSingle();

      if (res == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      final req = RequestModel.fromSupabase(
          Map<String, dynamic>.from(res), widget.requestId);

      // تأكد من ملكية الطلب
      final auth = context.read<AuthProvider>();
      if (auth.userModel?.uid != req.usrId) {
        _snack('ليس لديك صلاحية لعرض هذا الطلب');
        if (mounted) Navigator.pop(context);
        return;
      }

      // جلب العروض المطابقة
      final matches = await _biz.matchOffersForRequest(
        type: req.typ,
        targetPrice: req.prc,
      );

      if (!mounted) return;
      setState(() {
        _request = req;
        _matches = matches;
        _loading = false;
      });
    } catch (e) {
      debugPrint('❌ load request: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surfaceBlack,
        title: const Text('حذف الطلب',
            style: TextStyle(color: AppTheme.textWhite)),
        content: const Text(
            'هل أنت متأكد من حذف هذا الطلب؟ سيتوقف ظهوره للوسطاء.',
            style: TextStyle(color: AppTheme.textGrey)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء',
                  style: TextStyle(color: AppTheme.textGrey))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child:
                const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      await SupabaseService()
          .client
          .from(DbTables.requests)
          .update({'i_del': 1}).eq('id', widget.requestId);

      if (!mounted) return;
      _snack('تم حذف الطلب');

      // حدّث الـ provider
      final auth = context.read<AuthProvider>();
      final reqProv = context.read<RequestProvider>();
      if (auth.userModel != null) {
        await reqProv.fetchMyRequests(auth.userModel!.uid);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      debugPrint('❌ delete request: $e');
      if (mounted) {
        setState(() => _deleting = false);
        _snack('فشل الحذف');
      }
    }
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppTheme.deepBlack,
        body: Center(
            child: CircularProgressIndicator(color: AppTheme.primaryGold)),
      );
    }
    if (_request == null) {
      return const Scaffold(
        backgroundColor: AppTheme.deepBlack,
        body: Center(
          child: Text('الطلب غير موجود',
              style: TextStyle(color: AppTheme.textGrey)),
        ),
      );
    }

    final r = _request!;
    return Scaffold(
      backgroundColor: AppTheme.deepBlack,
      appBar: AppBar(
        title: const Text('تفاصيل الطلب'),
        backgroundColor: AppTheme.deepBlack,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: _deleting ? null : _delete,
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.primaryGold,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _summaryCard(r),
            const SizedBox(height: 20),
            _detailsCard(r),
            const SizedBox(height: 20),
            _matchesHeader(),
            const SizedBox(height: 10),
            if (_matches.isEmpty) _noMatches() else ..._matches.map(_matchTile),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _summaryCard(RequestModel r) {
    final status = _statusInfo(r.sts);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBlack,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: status.$2.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(r.typ == 0 ? Icons.home : Icons.directions_car,
                  color: AppTheme.primaryGold, size: 28),
              const SizedBox(width: 8),
              Text(
                r.typ == 0 ? 'بحث عن عقار' : 'بحث عن سيارة',
                style: const TextStyle(
                    color: AppTheme.textWhite,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: status.$2.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(status.$3, color: status.$2, size: 14),
                    const SizedBox(width: 4),
                    Text(status.$1,
                        style: TextStyle(
                            color: status.$2,
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (r.prc > 0)
            Text(
              'السعر المستهدف: ${r.prc.toStringAsFixed(0)} ${r.cur == 0 ? '\$' : 'ل.س'}',
              style: const TextStyle(
                  color: AppTheme.primaryGold,
                  fontSize: 15,
                  fontWeight: FontWeight.bold),
            ),
          const SizedBox(height: 4),
          Text(
            'تاريخ الإنشاء: ${r.tsCrt.day}/${r.tsCrt.month}/${r.tsCrt.year}',
            style: const TextStyle(color: AppTheme.textGrey, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _detailsCard(RequestModel r) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBlack,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('📋 تفاصيل الطلب',
              style: TextStyle(
                  color: AppTheme.primaryGold,
                  fontWeight: FontWeight.bold,
                  fontSize: 15)),
          const Divider(color: AppTheme.textGrey, height: 16),
          _row('اسم العميل', r.clNm.isEmpty ? '—' : r.clNm),
          _row('هاتف العميل', r.clPh.isEmpty ? '—' : r.clPh),
          if (r.notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text('ملاحظات:',
                style: TextStyle(
                    color: AppTheme.primaryGold, fontSize: 13)),
            const SizedBox(height: 4),
            Text(r.notes,
                style: const TextStyle(
                    color: AppTheme.textWhite, fontSize: 13)),
          ],
          if (r.specs.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('المواصفات المطلوبة:',
                style: TextStyle(
                    color: AppTheme.primaryGold, fontSize: 13)),
            const SizedBox(height: 6),
            ...r.specs.entries.map((e) => _row(e.key, e.value.toString())),
          ],
        ],
      ),
    );
  }

  Widget _matchesHeader() {
    return Row(
      children: [
        const Text('🎯 عروض مطابقة',
            style: TextStyle(
                color: AppTheme.primaryGold,
                fontWeight: FontWeight.bold,
                fontSize: 16)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppTheme.primaryGold.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text('${_matches.length}',
              style: const TextStyle(
                  color: AppTheme.primaryGold,
                  fontWeight: FontWeight.bold)),
        ),
        const Spacer(),
        TextButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh,
              color: AppTheme.primaryGold, size: 16),
          label: const Text('تحديث',
              style: TextStyle(color: AppTheme.primaryGold, fontSize: 12)),
        ),
      ],
    );
  }

  Widget _noMatches() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBlack,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const Icon(Icons.search_off,
              color: AppTheme.textGrey, size: 50),
          const SizedBox(height: 8),
          const Text('لا توجد عروض مطابقة حالياً',
              style: TextStyle(color: AppTheme.textGrey, fontSize: 14)),
          const SizedBox(height: 4),
          const Text('سنبلغك عند توفّر عرض مطابق',
              style: TextStyle(color: AppTheme.textGrey, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _matchTile(OfferModel o) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBlack,
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/offer/${o.id}'),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 70,
                  height: 70,
                  child: o.imgs.isNotEmpty
                      ? Image.network(o.imgs.first.toString(),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                              color: AppTheme.deepBlack,
                              child: const Icon(Icons.image,
                                  color: AppTheme.textGrey)))
                      : Container(
                          color: AppTheme.deepBlack,
                          child: const Icon(Icons.image,
                              color: AppTheme.textGrey)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(o.ttl,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppTheme.textWhite,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 3),
                    Text(
                      '${o.prc.toStringAsFixed(0)} ${o.cur == 0 ? '\$' : 'ل.س'}',
                      style: const TextStyle(
                          color: AppTheme.primaryGold,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text((o.loc['d'] ?? '').toString(),
                        style: const TextStyle(
                            color: AppTheme.textGrey, fontSize: 11)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios,
                  color: AppTheme.primaryGold, size: 14),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(k,
                style: const TextStyle(
                    color: AppTheme.textGrey, fontSize: 12)),
          ),
          Expanded(
            child: Text(v,
                style: const TextStyle(
                    color: AppTheme.textWhite,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  (String, Color, IconData) _statusInfo(int s) {
    switch (s) {
      case 0:
        return ('نشط', Colors.green, Icons.check_circle);
      case 1:
        return ('قيد البحث', Colors.orange, Icons.search);
      case 2:
        return ('تم العثور', Colors.blue, Icons.done_all);
      case 3:
        return ('مغلق', Colors.grey, Icons.lock);
      default:
        return ('غير معروف', Colors.grey, Icons.help);
    }
  }
}
