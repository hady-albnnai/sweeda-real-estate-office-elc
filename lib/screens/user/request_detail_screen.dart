import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/request_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/config_provider.dart';
import '../../models/request_model.dart';
import '../../models/offer_model.dart';
import '../../core/services/business_service.dart';
import '../../core/network/supabase_service.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/book_appointment_sheet.dart';

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
  // فلتر العروض المطابقة — أساسية
  double? _filterMinPrice;
  double? _filterMaxPrice;
  String? _filterLocation;
  // فلتر العروض المطابقة — عقارات
  int? _filterCat;
  int? _filterDocType;
  String? _filterFinishing;
  String? _filterDirection;
  double? _filterMinArea;
  double? _filterMaxArea;
  int? _filterFloor;
  // فلتر العروض المطابقة — سيارات
  String? _filterBrand;
  int? _filterYear;
  String? _filterFuel;
  String? _filterTransmission;
  bool _loading = true;
  bool _deleting = false;
  bool _renewing = false;
  final _biz = BusinessService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ConfigProvider>().loadConfig();
      _load();
    });
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final auth = context.read<AuthProvider>();
      final userId = auth.userModel?.uid;
      if (userId == null || userId.isEmpty) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      // استخدام Edge Function بدل RPC المباشر لأن الدالة مقفولة (service_role only)
      // Edge Function only: internal RPC is service_role.
      final response = await SupabaseService().invokeFunction(
        'user-requests',
        body: {
          'action': 'list',
          'user_uid': userId,
        },
      );
      final data = response.data;
      if (data == null || data['success'] != true || data['requests'] is! List) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      final rows = data['requests'] as List;

      Map<String, dynamic>? match;
      for (final row in rows) {
        final map = Map<String, dynamic>.from(row as Map);
        if (map['id'] == widget.requestId) {
          match = map;
          break;
        }
      }

      if (match == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      final req = RequestModel.fromSupabase(match, widget.requestId);

      // جلب العروض المطابقة
      final matches = await _biz.matchOffersForRequest(
        elementType: req.elm,
        transactionType: req.typ,
        targetPrice: req.prc,
        currency: req.cur,
      );

      if (!mounted) return;
      setState(() {
        _request = req;
        _matches = matches;
        _loading = false;
      });
    } catch (e) {if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _cancelRequest() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surfaceBlack,
        title: Text('إلغاء الطلب',
            style: TextStyle(color: AppTheme.textWhite)),
        content: Text(
            'هل أنت متأكد من إلغاء هذا الطلب؟ سيبقى محفوظاً لدى الإدارة لأغراض المسؤولية والمتابعة.',
            style: TextStyle(color: AppTheme.textGrey)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('إلغاء',
                  style: TextStyle(color: AppTheme.textGrey))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child:
                const Text('إلغاء الطلب', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      final auth = context.read<AuthProvider>();
      final reqProv = context.read<RequestProvider>();
      final userId = auth.userModel?.uid ?? '';
      final ok = await reqProv.cancelRequest(userId, widget.requestId);
      if (!ok) throw Exception('CANCEL_FAILED');

      if (!mounted) return;
      _snack('تم إلغاء الطلب');
      if (mounted) Navigator.pop(context, true);
    } catch (e) {if (mounted) {
        setState(() => _deleting = false);
        _snack('فشل إلغاء الطلب');
      }
    }
  }


  Future<void> _renewRequest() async {
    if (_renewing) return;
    setState(() => _renewing = true);
    try {
      final auth = context.read<AuthProvider>();
      final userId = auth.userModel?.uid ?? '';
      final ok = await context.read<RequestProvider>().renewRequest(userId, widget.requestId);
      if (!ok) throw Exception('RENEW_FAILED');
      await _load();
      if (mounted) _snack('تم تجديد الطلب بنجاح');
    } catch (_) {
      if (mounted) _snack('فشل تجديد الطلب');
    } finally {
      if (mounted) setState(() => _renewing = false);
    }
  }

  void _snack(String m) =>
      AppTheme.showSnackBar(context, SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: AppTheme.scaffoldBackground,
        body: Center(
            child: CircularProgressIndicator(color: AppTheme.primaryGold)),
      );
    }
    if (_request == null) {
      return Scaffold(
        backgroundColor: AppTheme.scaffoldBackground,
        body: Center(
          child: Text('الطلب غير موجود',
              style: TextStyle(color: AppTheme.textGrey)),
        ),
      );
    }

    final r = _request!;
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      appBar: AppBar(
        title: const Text('تفاصيل الطلب'),
        backgroundColor: AppTheme.scaffoldBackground,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.cancel_outlined, color: Colors.red),
            onPressed: (r.canCancel && !_deleting) ? _cancelRequest : null,
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
            if (r.canRenew) ...[
              const SizedBox(height: 12),
              _renewButton(),
            ],
            const SizedBox(height: 20),
            _matchesHeader(),
            if (_matches.isNotEmpty) _filterBar(),
            const SizedBox(height: 10),
            if (_filteredMatches.isEmpty && _matches.isNotEmpty)
              Padding(padding: EdgeInsets.all(20),
                child: Text('لا توجد عروض تطابق الفلتر', style: TextStyle(color: AppTheme.textGrey)))
            else if (_matches.isEmpty) _noMatches()
            else ..._filteredMatches.map(_matchTile),
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
        border: Border.all(color: status.$2.withOpacity(0.4)),
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
                style: TextStyle(
                    color: AppTheme.textWhite,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: status.$2.withOpacity(0.15),
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
          Row(
            children: [
              Text(
                'تاريخ الإنشاء: ${r.tsCrt.day}/${r.tsCrt.month}/${r.tsCrt.year}',
                style: TextStyle(color: AppTheme.textGrey, fontSize: 12),
              ),
              const Spacer(),
              if (r.isOpen) ...[
                const Icon(Icons.timer, size: 14, color: AppTheme.primaryGold),
                const SizedBox(width: 4),
                Text(
                  'متبقي ${r.daysUntilExpiration} يوم',
                  style: const TextStyle(
                      color: AppTheme.primaryGold,
                      fontSize: 12,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ],
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
          Divider(color: AppTheme.textGrey, height: 16),
          _row('اسم العميل', r.clNm.isEmpty ? '—' : r.clNm),
          _row('هاتف العميل', r.clPh.isEmpty ? '—' : r.clPh),
          if (r.notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text('ملاحظات:',
                style: TextStyle(
                    color: AppTheme.primaryGold, fontSize: 13)),
            const SizedBox(height: 4),
            Text(r.notes,
                style: TextStyle(
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

    List<OfferModel> get _filteredMatches {
    var list = _matches;
    // أساسية
    if (_filterMinPrice != null) list = list.where((o) => o.prc >= _filterMinPrice!).toList();
    if (_filterMaxPrice != null) list = list.where((o) => o.prc <= _filterMaxPrice!).toList();
    if (_filterLocation != null && _filterLocation!.isNotEmpty) {
      list = list.where((o) => (o.loc['city'] ?? o.loc['d'] ?? '').toString().contains(_filterLocation!)).toList();
    }
    // عقارات
    if (_filterCat != null) list = list.where((o) => o.cat == _filterCat!).toList();
    if (_filterDocType != null) list = list.where((o) => o.docTp == _filterDocType!).toList();
    if (_filterFinishing != null && _filterFinishing!.isNotEmpty) {
      list = list.where((o) => (o.specs['finishing']?.toString() ?? '') == _filterFinishing!).toList();
    }
    if (_filterDirection != null && _filterDirection!.isNotEmpty) {
      list = list.where((o) => (o.specs['direction']?.toString() ?? '') == _filterDirection!).toList();
    }
    if (_filterMinArea != null) {
      list = list.where((o) {
        final area = double.tryParse(o.specs['area']?.toString() ?? '');
        return area != null && area >= _filterMinArea!;
      }).toList();
    }
    if (_filterMaxArea != null) {
      list = list.where((o) {
        final area = double.tryParse(o.specs['area']?.toString() ?? '');
        return area != null && area <= _filterMaxArea!;
      }).toList();
    }
    if (_filterFloor != null) {
      list = list.where((o) => int.tryParse(o.specs['floor']?.toString() ?? '') == _filterFloor!).toList();
    }
    // سيارات
    if (_filterBrand != null && _filterBrand!.isNotEmpty) {
      list = list.where((o) => (o.specs['brand']?.toString() ?? '').toLowerCase().contains(_filterBrand!.toLowerCase())).toList();
    }
    if (_filterYear != null) {
      list = list.where((o) => int.tryParse(o.specs['year']?.toString() ?? '') == _filterYear!).toList();
    }
    if (_filterFuel != null && _filterFuel!.isNotEmpty) {
      list = list.where((o) => (o.specs['fuel']?.toString() ?? '') == _filterFuel!).toList();
    }
    if (_filterTransmission != null && _filterTransmission!.isNotEmpty) {
      list = list.where((o) => (o.specs['transmission']?.toString() ?? '') == _filterTransmission!).toList();
    }
    return list;
  }

    Widget _filterBar() {
    final config = context.watch<ConfigProvider>().config;
    final isProperty = _request?.elm == 0;
        final catsSource = isProperty
        ? ((config?.data['catProp'] ?? {}) as Map<String, dynamic>)
        : ((config?.data['catVeh'] ?? {}) as Map<String, dynamic>);
    final docTpSource = isProperty
        ? ((config?.data['docTp'] ?? {}) as Map<String, dynamic>)
        : ((config?.data['carDocTp'] ?? {}) as Map<String, dynamic>);

    // بناء خيارات التصنيف
    final catItems = catsSource.entries
        .where((e) => int.tryParse(e.key) != null)
        .map((e) => DropdownMenuItem<int>(
              value: int.parse(e.key),
              child: Text(e.value is Map ? (e.value['nm'] ?? e.value.toString()) : e.value.toString(), overflow: TextOverflow.ellipsis),
            ))
        .toList();
    final docItems = docTpSource.entries
        .where((e) => int.tryParse(e.key) != null)
        .map((e) => DropdownMenuItem<int>(
              value: int.parse(e.key),
              child: Text(e.value.toString(), overflow: TextOverflow.ellipsis),
            ))
        .toList();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(children: [
        // ── السعر + الموقع ──
        Row(children: [
          Expanded(child: TextField(
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'السعر من', border: OutlineInputBorder(), isDense: true),
            onChanged: (v) => setState(() => _filterMinPrice = double.tryParse(v)),
          )),
          const SizedBox(width: 8),
          Expanded(child: TextField(
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'السعر إلى', border: OutlineInputBorder(), isDense: true),
            onChanged: (v) => setState(() => _filterMaxPrice = double.tryParse(v)),
          )),
        ]),
        const SizedBox(height: 8),
        TextField(
          decoration: const InputDecoration(labelText: 'فلتر الموقع', hintText: 'اكتب اسم المنطقة...', border: OutlineInputBorder(), isDense: true, prefixIcon: Icon(Icons.location_on, size: 18)),
          onChanged: (v) => setState(() => _filterLocation = v.trim()),
        ),
        const SizedBox(height: 8),
        // ── التصنيف الرئيسي ──
        DropdownButtonFormField<int>(
          value: _filterCat,
          isExpanded: true,
          items: [const DropdownMenuItem(value: null, child: Text('كل التصنيفات', overflow: TextOverflow.ellipsis)), ...catItems],
          onChanged: (v) => setState(() => _filterCat = v),
          decoration: const InputDecoration(labelText: 'التصنيف', border: OutlineInputBorder(), isDense: true),
        ),
        const SizedBox(height: 8),
        // ── نوع السند ──
        if (docItems.isNotEmpty)
          DropdownButtonFormField<int>(
            value: _filterDocType,
            isExpanded: true,
            items: [const DropdownMenuItem(value: null, child: Text('كل أنواع السند', overflow: TextOverflow.ellipsis)), ...docItems],
            onChanged: (v) => setState(() => _filterDocType = v),
            decoration: const InputDecoration(labelText: 'نوع السند', border: OutlineInputBorder(), isDense: true),
          ),
        // ── فلاتر العقارات ──
        if (isProperty) ...[
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _filterFinishing,
            isExpanded: true,
            items: [
              const DropdownMenuItem(value: null, child: Text('كل الإكساءات', overflow: TextOverflow.ellipsis)),
              const DropdownMenuItem(value: 'ملكي', child: Text('ملكي')),
              const DropdownMenuItem(value: 'سوبر ديلوكس', child: Text('سوبر ديلوكس')),
              const DropdownMenuItem(value: 'ديلوكس', child: Text('ديلوكس')),
              const DropdownMenuItem(value: 'عادي', child: Text('عادي')),
              const DropdownMenuItem(value: 'هيكل', child: Text('هيكل')),
            ],
            onChanged: (v) => setState(() => _filterFinishing = v),
            decoration: const InputDecoration(labelText: 'الإكساء', border: OutlineInputBorder(), isDense: true),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _filterDirection,
            isExpanded: true,
            items: [
              const DropdownMenuItem(value: null, child: Text('كل الاتجاهات', overflow: TextOverflow.ellipsis)),
              const DropdownMenuItem(value: 'شمالي', child: Text('شمالي')),
              const DropdownMenuItem(value: 'جنوبي', child: Text('جنوبي')),
              const DropdownMenuItem(value: 'شرقي', child: Text('شرقي')),
              const DropdownMenuItem(value: 'غربي', child: Text('غربي')),
              const DropdownMenuItem(value: 'شمالي شرقي', child: Text('شمالي شرقي')),
              const DropdownMenuItem(value: 'شمالي غربي', child: Text('شمالي غربي')),
              const DropdownMenuItem(value: 'جنوبي شرقي', child: Text('جنوبي شرقي')),
              const DropdownMenuItem(value: 'جنوبي غربي', child: Text('جنوبي غربي')),
              const DropdownMenuItem(value: 'مفتوح - 4 اتجاهات', child: Text('مفتوح - 4 اتجاهات')),
            ],
            onChanged: (v) => setState(() => _filterDirection = v),
            decoration: const InputDecoration(labelText: 'اتجاه العقار', border: OutlineInputBorder(), isDense: true),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: TextField(
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'المساحة من', border: OutlineInputBorder(), isDense: true),
              onChanged: (v) => setState(() => _filterMinArea = double.tryParse(v)),
            )),
            const SizedBox(width: 8),
            Expanded(child: TextField(
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'المساحة إلى', border: OutlineInputBorder(), isDense: true),
              onChanged: (v) => setState(() => _filterMaxArea = double.tryParse(v)),
            )),
          ]),
          const SizedBox(height: 8),
          TextField(
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'الطابق', border: OutlineInputBorder(), isDense: true),
            onChanged: (v) => setState(() => _filterFloor = int.tryParse(v)),
          ),
        ],
        // ── فلاتر السيارات ──
        if (!isProperty) ...[
          const SizedBox(height: 8),
          TextField(
            decoration: const InputDecoration(labelText: 'الماركة', hintText: 'مثال: تويوتا، كيا...', border: OutlineInputBorder(), isDense: true),
            onChanged: (v) => setState(() => _filterBrand = v.trim()),
          ),
          const SizedBox(height: 8),
          TextField(
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'سنة الصنع', border: OutlineInputBorder(), isDense: true),
            onChanged: (v) => setState(() => _filterYear = int.tryParse(v)),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _filterFuel,
            isExpanded: true,
            items: [
              const DropdownMenuItem(value: null, child: Text('كل أنواع الوقود', overflow: TextOverflow.ellipsis)),
              const DropdownMenuItem(value: 'بنزين', child: Text('بنزين')),
              const DropdownMenuItem(value: 'ديزل', child: Text('ديزل')),
              const DropdownMenuItem(value: 'هجين', child: Text('هجين')),
              const DropdownMenuItem(value: 'كهرباء', child: Text('كهرباء')),
            ],
            onChanged: (v) => setState(() => _filterFuel = v),
            decoration: const InputDecoration(labelText: 'الوقود', border: OutlineInputBorder(), isDense: true),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _filterTransmission,
            isExpanded: true,
            items: [
              const DropdownMenuItem(value: null, child: Text('كل أنواع الحركة', overflow: TextOverflow.ellipsis)),
              const DropdownMenuItem(value: 'عادي', child: Text('عادي')),
              const DropdownMenuItem(value: 'أوتوماتيك', child: Text('أوتوماتيك')),
              const DropdownMenuItem(value: 'نصف أوتوماتيك', child: Text('نصف أوتوماتيك')),
            ],
            onChanged: (v) => setState(() => _filterTransmission = v),
            decoration: const InputDecoration(labelText: 'ناقل الحركة', border: OutlineInputBorder(), isDense: true),
          ),
        ],
      ]),
    );
  }

  Widget _renewButton() {
    final user = context.watch<AuthProvider>().userModel;
    final r = _request!;

    // تجديد الطلب: متاح للحسابات المدفوعة دائماً، وللمجانية قبل يومين فقط من الانتهاء
    final bool canRenewNow = (user?.bPkg != 0) || (r.daysUntilExpiration <= 2);

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: (!canRenewNow || _renewing) ? null : _renewRequest,
        icon: _renewing
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.refresh),
        label: Text(canRenewNow ? 'تجديد الطلب' : 'التجديد متاح قبل يومين من الانتهاء',
            style: TextStyle(color: canRenewNow ? AppTheme.primaryGold : AppTheme.textGrey)),
        style: OutlinedButton.styleFrom(
          foregroundColor: canRenewNow ? AppTheme.primaryGold : AppTheme.textGrey,
          side: BorderSide(color: canRenewNow ? AppTheme.primaryGold : AppTheme.textGrey),
        ),
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
            color: AppTheme.primaryGold.withOpacity(0.15),
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
          Icon(Icons.search_off,
              color: AppTheme.textGrey, size: 50),
          const SizedBox(height: 8),
          Text('لا توجد عروض مطابقة حالياً',
              style: TextStyle(color: AppTheme.textGrey, fontSize: 14)),
          const SizedBox(height: 4),
          Text('سنبلغك عند توفّر عرض مطابق',
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
                              child: Icon(Icons.image,
                                  color: AppTheme.textGrey)))
                      : Container(
                          color: AppTheme.deepBlack,
                          child: Icon(Icons.image,
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
                        style: TextStyle(
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
                        style: TextStyle(
                            color: AppTheme.textGrey, fontSize: 11)),
                  ],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.arrow_forward_ios, color: AppTheme.primaryGold, size: 14),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => _bookOnOffer(o),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGold.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.primaryGold.withOpacity(0.4)),
                      ),
                      child: const Text('📅 حجز', style: TextStyle(color: AppTheme.primaryGold, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _bookOnOffer(OfferModel offer) {
    if (offer.avl.isEmpty) {
      AppTheme.showSnackBar(context,
          const SnackBar(content: Text('هذا العرض لا يحتوي مواعيد متاحة حالياً')));
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BookAppointmentSheet(offer: offer, requestId: widget.requestId),
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
                style: TextStyle(
                    color: AppTheme.textGrey, fontSize: 12)),
          ),
          Expanded(
            child: Text(v,
                style: TextStyle(
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
        return ('قيد المعالجة', Colors.orange, Icons.search);
      case 2:
        return ('تمت تلبيته', Colors.blue, Icons.done_all);
      case 3:
        return ('ملغي', Colors.grey, Icons.lock);
      case 4:
        return ('منتهي الصلاحية', Colors.deepOrange, Icons.hourglass_disabled);
      default:
        return ('غير معروف', Colors.grey, Icons.help);
    }
  }
}

