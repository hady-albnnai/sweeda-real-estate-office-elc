import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../models/user_model.dart';
import '../../models/offer_model.dart';
import '../../providers/offer_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/config_provider.dart';
import '../../providers/notification_provider.dart';
import '../../widgets/offer_card.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../widgets/shimmer_loading.dart';
import '../../widgets/error_widget.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../core/services/permission_service.dart';

/// الشاشة الرئيسية للمستخدم بعد تسجيل الدخول
/// تحتوي على: بحث + فلتر + عروض + BottomNavigationBar
class UserHomeScreen extends StatefulWidget {
  const UserHomeScreen({super.key});

  @override
  State<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends State<UserHomeScreen> {
  final _searchCtrl = TextEditingController();
  int? _filterType; // null=الكل, 0=عقار, 1=سيارة
  int? _filterTrx;  // null=الكل, 0=بيع, 1=إيجار
  bool _isSearching = false;

  // 🎛️ الفلاتر المتقدمة — نفس معايير مطابقة الطلبات (2026-07-27)
  String? _fCity;
  double _fMinPrice = 0, _fMaxPrice = 1000000;
  int? _fCat, _fDocTp, _fFloor, _fMinRooms;
  String? _fFinishing, _fDirection;
  double? _fMinArea, _fMaxArea;
  String? _fBrand, _fModel, _fFuel, _fTransmission;
  int? _fYear, _fMaxKm;
  bool _fImagesOnly = false;
  String _fSort = 'none'; // none | price_low | price_high | newest

  int get _activeAdvCount {
    var n = 0;
    if (_fCity != null) n++;
    if (_fMinPrice > 0 || _fMaxPrice < 1000000) n++;
    for (final v in [_fCat, _fDocTp, _fFloor, _fMinRooms, _fYear, _fMaxKm]) {
      if (v != null) n++;
    }
    for (final v in [_fFinishing, _fDirection, _fBrand, _fModel, _fFuel, _fTransmission]) {
      if (v != null) n++;
    }
    if (_fMinArea != null || _fMaxArea != null) n++;
    if (_fImagesOnly) n++;
    if (_fSort != 'none') n++;
    return n;
  }

  void _resetAdvFilters() {
    _fCity = null;
    _fMinPrice = 0; _fMaxPrice = 1000000;
    _fCat = _fDocTp = _fFloor = _fMinRooms = _fYear = _fMaxKm = null;
    _fFinishing = _fDirection = _fBrand = _fModel = _fFuel = _fTransmission = null;
    _fMinArea = _fMaxArea = null;
    _fImagesOnly = false;
    _fSort = 'none';
  }

  // 🔒 Fix: نحتفظ بمرجع OfferProvider لاستخدامه في dispose بأمان
  OfferProvider? _offerProvRef;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final config = Provider.of<ConfigProvider>(context, listen: false);
      await config.loadConfig();
      if (!mounted) return;
      final offerProv = Provider.of<OfferProvider>(context, listen: false);
      _offerProvRef = offerProv; // حفظ المرجع
      offerProv.fetchOffers();
      offerProv.subscribeRealtime(); // تحديث فوري للعروض

      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.isLoggedIn) {
        final uid = auth.userModel?.uid ?? '';
        if (uid.isNotEmpty) {
          Provider.of<NotificationProvider>(context, listen: false)
              .fetchNotifications(uid);
        }
        final res = await auth.registerStreak(config.config);
        if (mounted && res['awarded'] == true) {
          AppUtils.showPointsAwarded(context, 50, label: 'نقطة دخول يومي');
        }
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _offerProvRef?.unsubscribeRealtime();
    super.dispose();
  }

  Future<void> _doSearch() async {
    final query = _searchCtrl.text.trim();
    if (query.isEmpty && _filterType == null && _filterTrx == null) {
      await context.read<OfferProvider>().fetchOffers();
      if (mounted) setState(() => _isSearching = false);
      return;
    }
    setState(() => _isSearching = true);
    await context.read<OfferProvider>().searchOffers(
          query: query.isEmpty ? null : query,
          type: _filterType,
          transaction: _filterTrx,
        );
    if (mounted) setState(() {});
  }

  void _clearSearch() {
    _searchCtrl.clear();
    setState(() {
      _filterType = null;
      _filterTrx  = null;
      _isSearching = false;
    });
    context.read<OfferProvider>().fetchOffers();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final offerProv = Provider.of<OfferProvider>(context);
    final userName = auth.userModel?.nm ?? 'مستخدم';

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.scaffoldBackground,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'مرحباً، $userName 👋',
              style: const TextStyle(
                color: AppTheme.textWhite,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'اكتشف عقارك المثالي 🏠',
              style: TextStyle(
                color: AppTheme.primaryGold.withOpacity(0.7),
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          if (_roleShortcutRoute(auth) != null)
            IconButton(
              icon: Icon(_roleShortcutIcon(auth), color: AppTheme.primaryGold),
              tooltip: _roleShortcutTooltip(auth),
              onPressed: () => context.push(_roleShortcutRoute(auth)!),
            ),
          // أيقونة الإشعارات مع badge لعدد غير المقروء
          Consumer<NotificationProvider>(
            builder: (context, notif, _) {
              final count = notif.unreadCount;
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_none,
                        color: AppTheme.primaryGold),
                    onPressed: () => context.push('/user/notifications'),
                  ),
                  if (count > 0)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        constraints:
                            const BoxConstraints(minWidth: 18, minHeight: 18),
                        decoration: const BoxDecoration(
                          color: AppTheme.errorRed,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          count > 9 ? '9+' : '$count',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          // المفضلة — نقلت من الشريط السفلي لأيقونة هنا (إضافة عرض صارت بتبويب عروضي)
          IconButton(
            icon: const Icon(Icons.favorite_outline, color: AppTheme.primaryGold),
            tooltip: 'المفضلة',
            onPressed: () => context.push('/user/favorites'),
          ),
        ],
      ),
      body: Column(
        children: [
          // شريط البحث
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(color: AppTheme.textWhite),
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _doSearch(),
              decoration: InputDecoration(
                hintText: 'ابحث عن عقار أو سيارة...',
                prefixIcon: const Icon(Icons.search, color: AppTheme.primaryGold),
                suffixIcon: _searchCtrl.text.isNotEmpty || _isSearching
                    ? IconButton(
                        icon: const Icon(Icons.close, color: AppTheme.textGrey),
                        onPressed: _clearSearch,
                      )
                    : IconButton(
                        icon: const Icon(Icons.tune, color: AppTheme.primaryGold),
                        onPressed: () => context.push('/search'),
                      ),
                filled: true,
                fillColor: AppTheme.surfaceBlack,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),

          // فئات العروض (فلاتر متزامنة مع الجميع)
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 15),
              children: [
                _buildChip('الكل', _filterType == null && _filterTrx == null, () {
                  setState(() { _filterType = null; _filterTrx = null; });
                  _doSearch();
                }),
                const SizedBox(width: 8),
                _buildChip('🏠 عقار', _filterType == 0, () {
                  setState(() => _filterType = _filterType == 0 ? null : 0);
                  _doSearch();
                }),
                const SizedBox(width: 8),
                _buildChip('🚗 سيارة', _filterType == 1, () {
                  setState(() => _filterType = _filterType == 1 ? null : 1);
                  _doSearch();
                }),
                const SizedBox(width: 8),
                _buildChip('بيع', _filterTrx == 0, () {
                  setState(() => _filterTrx = _filterTrx == 0 ? null : 0);
                  _doSearch();
                }),
                const SizedBox(width: 8),
                _buildChip('إيجار', _filterTrx == 1, () {
                  setState(() => _filterTrx = _filterTrx == 1 ? null : 1);
                  _doSearch();
                }),
                const SizedBox(width: 8),
                // 🎛️ الفلاتر الكاملة (معايير مطابقة الطلبات) مع عدّاد الفلاتر الفعّالة
                _buildChip(
                  _activeAdvCount > 0 ? '⚙️ فلاتر (${_activeAdvCount})' : '⚙️ فلاتر كاملة',
                  _activeAdvCount > 0,
                  _showAdvancedFilters,
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // قائمة العروض
          // مؤشّر العمل دون اتصال
          if (offerProv.fromCache && offerProv.offers.isNotEmpty)
            Container(
              width: double.infinity,
              color: Colors.orange.withOpacity(0.15),
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: const Text('📡 وضع دون اتصال — عرض بيانات محفوظة',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.orange, fontSize: 11)),
            ),
          Expanded(
            child: offerProv.isLoading && offerProv.offers.isEmpty
                ? ShimmerLoading.offerList()
                : (offerProv.error != null && offerProv.offers.isEmpty)
                    ? AppErrorWidget(
                        message: offerProv.error!,
                        onRetry: () => offerProv.fetchOffers(),
                      )
                    : offerProv.offers.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.home_work,
                                    size: 80,
                                    color: AppTheme.textGrey.withOpacity(0.3)),
                                const SizedBox(height: 20),
                                const Text(
                                  'لا توجد عروض متاحة حالياً',
                                  style: TextStyle(
                                      color: AppTheme.textGrey, fontSize: 16),
                                ),
                                const SizedBox(height: 20),
                                ElevatedButton.icon(
                                  onPressed: () =>
                                      context.push('/user/add-offer'),
                                  icon: const Icon(Icons.add),
                                  label: const Text('أضف عرضك الأول'),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: () => offerProv.fetchOffers(),
                            color: AppTheme.primaryGold,
                            child: ListView.builder(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 15),
                              itemCount:
                                  _filteredOffers(offerProv.offers).length,
                              itemBuilder: (context, index) {
                                final offer =
                                    _filteredOffers(offerProv.offers)[index];
                                return OfferCard(offer: offer);
                              },
                            ),
                          ),
          ),
        ],
      ),
      bottomNavigationBar: const CustomBottomNavBar(currentIndex: 0),
    );
  }


  String? _roleShortcutRoute(AuthProvider auth) {
    final user = auth.userModel;
    if (user == null) return null;
    if (user.isSenior) return '/admin/dashboard';
    if (user.isEmployee) return '/employee/home';
    if (user.isSupervisor) return '/executor/tasks';
    if (PermissionService.has(user, PermissionKeys.photographerTasks)) {
      return '/photographer/tasks';
    }
    if (user.isPhotographer) return '/photographer/tasks';
    if (user.isBroker || user.role == UserRole.broker) return '/broker/dashboard';
    return null;
  }

  IconData _roleShortcutIcon(AuthProvider auth) {
    final route = _roleShortcutRoute(auth);
    if (route == '/admin/dashboard') return Icons.admin_panel_settings_outlined;
    if (route == '/photographer/tasks') return Icons.camera_alt_outlined;
    if (route == '/broker/dashboard') return Icons.handshake_outlined;
    return Icons.dashboard_outlined;
  }

  String _roleShortcutTooltip(AuthProvider auth) {
    final route = _roleShortcutRoute(auth);
    if (route == '/admin/dashboard') return 'لوحة الإدارة';
    if (route == '/photographer/tasks') return 'مهام المصور';
    if (route == '/broker/dashboard') return 'لوحة الوسيط';
    return 'لوحتي';
  }

  // 🎛️ التصفية المحلية — نفس منطق شاشة «العروض المطابقة» للطلبات حرفياً
  List<OfferModel> _filteredOffers(List<OfferModel> offers) {
    if (_activeAdvCount == 0) return offers;

    List<OfferModel> filtered = List.from(offers);

    // الموقع (city أو d)
    if (_fCity != null) {
      filtered = filtered.where((o) {
        final city = (o.loc['city'] ?? o.loc['d'] ?? '').toString().toLowerCase();
        return city.contains(_fCity!.toLowerCase());
      }).toList();
    }

    // السعر
    filtered = filtered
        .where((o) => o.prc >= _fMinPrice && o.prc <= _fMaxPrice)
        .toList();

    // عقارات
    if (_fCat != null) {
      filtered = filtered.where((o) => o.cat == _fCat).toList();
    }
    if (_fDocTp != null) {
      filtered = filtered.where((o) => o.docTp == _fDocTp).toList();
    }
    if (_fFinishing != null) {
      filtered = filtered.where((o) =>
          (o.specs['finishing']?.toString() ?? '') == _fFinishing).toList();
    }
    if (_fDirection != null) {
      filtered = filtered.where((o) =>
          (o.specs['direction']?.toString() ?? '') == _fDirection).toList();
    }
    if (_fMinArea != null) {
      filtered = filtered.where((o) {
        final area = double.tryParse(o.specs['area']?.toString() ?? '');
        return area != null && area >= _fMinArea!;
      }).toList();
    }
    if (_fMaxArea != null) {
      filtered = filtered.where((o) {
        final area = double.tryParse(o.specs['area']?.toString() ?? '');
        return area != null && area <= _fMaxArea!;
      }).toList();
    }
    if (_fFloor != null) {
      filtered = filtered.where((o) =>
          int.tryParse(o.specs['floor']?.toString() ?? '') == _fFloor).toList();
    }
    if (_fMinRooms != null) {
      filtered = filtered.where((o) {
        final rooms = (o.specs['rooms'] as num?)?.toInt() ?? 0;
        return rooms >= _fMinRooms!;
      }).toList();
    }

    // سيارات
    if (_fBrand != null) {
      filtered = filtered.where((o) =>
          (o.specs['brand']?.toString() ?? '').toLowerCase().contains(_fBrand!.toLowerCase())).toList();
    }
    if (_fModel != null) {
      filtered = filtered.where((o) =>
          (o.specs['model']?.toString() ?? '').toLowerCase().contains(_fModel!.toLowerCase())).toList();
    }
    if (_fYear != null) {
      filtered = filtered.where((o) =>
          int.tryParse(o.specs['year']?.toString() ?? '') == _fYear).toList();
    }
    if (_fFuel != null) {
      filtered = filtered.where((o) =>
          (o.specs['fuel']?.toString() ?? '') == _fFuel).toList();
    }
    if (_fTransmission != null) {
      filtered = filtered.where((o) =>
          (o.specs['transmission']?.toString() ?? '') == _fTransmission).toList();
    }
    if (_fMaxKm != null) {
      filtered = filtered.where((o) {
        final km = (o.specs['km'] as num?)?.toInt() ?? 999999;
        return km <= _fMaxKm!;
      }).toList();
    }

    // الصور فقط
    if (_fImagesOnly) {
      filtered = filtered.where((o) => o.imgs.isNotEmpty).toList();
    }

    // الترتيب
    if (_fSort == 'price_low') {
      filtered.sort((a, b) => a.prc.compareTo(b.prc));
    } else if (_fSort == 'price_high') {
      filtered.sort((a, b) => b.prc.compareTo(a.prc));
    } else if (_fSort == 'newest') {
      filtered.sort((a, b) => b.tsCrt.compareTo(a.tsCrt));
    }

    return filtered;
  }

  // 🎛️ نافذة الفلاتر الكاملة — نفس حقول معايير مطابقة الطلبات (2026-07-27)
  void _showAdvancedFilters() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceBlack,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, sheetSet) => Padding(
          padding: EdgeInsets.only(
            left: 16, right: 16, top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: _buildAdvancedSheet(sheetSet),
        ),
      ),
    ).then((_) => setState(() {})); // تحديث العدّاد والنتائج بعد الإغلاق
  }

  Widget _buildAdvancedSheet(StateSetter sheetSet) {
    final config = context.watch<ConfigProvider>().config;
    final showProp = _filterType != 1; // عقارات: كل الأنواع أو عقار
    final showCar = _filterType != 0;  // سيارات: كل الأنواع أو سيارة

    List<DropdownMenuItem<int>> catItems(Map<String, dynamic> src) => src.entries
        .where((e) => int.tryParse(e.key) != null)
        .map((e) => DropdownMenuItem<int>(
              value: int.parse(e.key),
              child: Text(
                e.value is Map ? (e.value['nm'] ?? e.value.toString()) : e.value.toString(),
                overflow: TextOverflow.ellipsis,
              ),
            ))
        .toList();

    final catPropSrc = (config?.data['catProp'] ?? <String, dynamic>{}) as Map<String, dynamic>;
    final docTpSrc = (config?.data['docTp'] ?? <String, dynamic>{}) as Map<String, dynamic>;
    final carDocTpSrc = (config?.data['carDocTp'] ?? <String, dynamic>{}) as Map<String, dynamic>;

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            const Icon(Icons.tune, color: AppTheme.primaryGold),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('الفلاتر الكاملة',
                  style: TextStyle(
                      color: AppTheme.primaryGold,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
            ),
            TextButton(
              onPressed: () => sheetSet(_resetAdvFilters),
              child: const Text('تصفير', style: TextStyle(color: AppTheme.errorRed)),
            ),
          ]),
          const SizedBox(height: 14),

          // الموقع
          DropdownButtonFormField<String>(
            value: _fCity,
            decoration: _fDeco('الموقع'),
            items: ['السويداء', 'صلخد', 'شهبا', 'المزرعة', 'الكفر', 'قنوات']
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (v) => sheetSet(() => _fCity = v),
          ),
          const SizedBox(height: 14),

          // السعر
          RangeSlider(
            values: RangeValues(_fMinPrice, _fMaxPrice),
            min: 0, max: 1000000, divisions: 20,
            activeColor: AppTheme.primaryGold,
            labels: RangeLabels(
              '${_fMinPrice.toInt()}', '${_fMaxPrice.toInt()}'),
            onChanged: (v) => sheetSet(() {
              _fMinPrice = v.start; _fMaxPrice = v.end;
            }),
          ),
          Text('السعر: ${_fMinPrice.toInt()} — ${_fMaxPrice.toInt()}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textGrey, fontSize: 12)),
          const SizedBox(height: 8),

          if (showProp) ...[
            const _FSectionTitle('🏠 فلاتر العقارات'),
            DropdownButtonFormField<int>(
              value: _fCat,
              decoration: _fDeco('التصنيف'),
              items: [const DropdownMenuItem(value: null, child: Text('الكل')),
                  ...catItems(catPropSrc)],
              onChanged: (v) => sheetSet(() => _fCat = v),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<int>(
              value: _fDocTp,
              decoration: _fDeco('نوع السند'),
              items: [const DropdownMenuItem(value: null, child: Text('الكل')),
                  ...catItems(docTpSrc)],
              onChanged: (v) => sheetSet(() => _fDocTp = v),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _fFinishing,
              decoration: _fDeco('التشطيب'),
              items: ['ملكي', 'سوبر ديلوكس', 'ديلوكس', 'عادي', 'هيكل']
                  .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                  .toList(),
              onChanged: (v) => sheetSet(() => _fFinishing = v),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _fDirection,
              decoration: _fDeco('الاتجاه'),
              items: ['شمالي', 'جنوبي', 'شرقي', 'غربي', 'شمالي شرقي', 'شمالي غربي',
                      'جنوبي شرقي', 'جنوبي غربي', 'مفتوح']
                  .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                  .toList(),
              onChanged: (v) => sheetSet(() => _fDirection = v),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: TextFormField(
                initialValue: _fMinArea?.toInt().toString() ?? '',
                keyboardType: TextInputType.number,
                decoration: _fDeco('مساحة من'),
                onChanged: (v) => _fMinArea = double.tryParse(v),
              )),
              const SizedBox(width: 10),
              Expanded(child: TextFormField(
                initialValue: _fMaxArea?.toInt().toString() ?? '',
                keyboardType: TextInputType.number,
                decoration: _fDeco('مساحة إلى'),
                onChanged: (v) => _fMaxArea = double.tryParse(v),
              )),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: TextFormField(
                initialValue: _fFloor?.toString() ?? '',
                keyboardType: TextInputType.number,
                decoration: _fDeco('الطابق'),
                onChanged: (v) => _fFloor = int.tryParse(v),
              )),
              const SizedBox(width: 10),
              Expanded(child: DropdownButtonFormField<int>(
                value: _fMinRooms,
                decoration: _fDeco('غرف (أدنى)'),
                items: [1, 2, 3, 4]
                    .map((r) => DropdownMenuItem(value: r, child: Text('$r+')))
                    .toList(),
                onChanged: (v) => sheetSet(() => _fMinRooms = v),
              )),
            ]),
            const SizedBox(height: 10),
          ],

          if (showCar) ...[
            const _FSectionTitle('🚗 فلاتر السيارات'),
            Row(children: [
              Expanded(child: TextFormField(
                initialValue: _fBrand ?? '',
                decoration: _fDeco('الماركة'),
                onChanged: (v) => _fBrand = v.trim().isEmpty ? null : v.trim(),
              )),
              const SizedBox(width: 10),
              Expanded(child: TextFormField(
                initialValue: _fModel ?? '',
                decoration: _fDeco('الموديل'),
                onChanged: (v) => _fModel = v.trim().isEmpty ? null : v.trim(),
              )),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: TextFormField(
                initialValue: _fYear?.toString() ?? '',
                keyboardType: TextInputType.number,
                decoration: _fDeco('سنة الصنع'),
                onChanged: (v) => _fYear = int.tryParse(v),
              )),
              const SizedBox(width: 10),
              Expanded(child: DropdownButtonFormField<int>(
                value: _fMaxKm,
                decoration: _fDeco('كم (أقصى)'),
                items: [50000, 100000, 150000]
                    .map((k) => DropdownMenuItem(
                        value: k, child: Text('< ${k ~/ 1000} ألف')))
                    .toList(),
                onChanged: (v) => sheetSet(() => _fMaxKm = v),
              )),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: DropdownButtonFormField<String>(
                value: _fFuel,
                decoration: _fDeco('الوقود'),
                items: ['بنزين', 'ديزل', 'هجين', 'كهرباء']
                    .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                    .toList(),
                onChanged: (v) => sheetSet(() => _fFuel = v),
              )),
              const SizedBox(width: 10),
              Expanded(child: DropdownButtonFormField<String>(
                value: _fTransmission,
                decoration: _fDeco('القير'),
                items: ['عادي', 'أوتوماتيك', 'نصف أوتوماتيك']
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) => sheetSet(() => _fTransmission = v),
              )),
            ]),
            const SizedBox(height: 10),
          ],

          // خيارات عامة
          SwitchListTile(
            value: _fImagesOnly,
            title: const Text('عروض لها صور فقط',
                style: TextStyle(color: AppTheme.textWhite, fontSize: 13)),
            activeColor: AppTheme.primaryGold,
            contentPadding: EdgeInsets.zero,
            onChanged: (v) => sheetSet(() => _fImagesOnly = v),
          ),
          DropdownButtonFormField<String>(
            value: _fSort,
            decoration: _fDeco('الترتيب'),
            items: const [
              DropdownMenuItem(value: 'none', child: Text('الافتراضي (الأولوية)')),
              DropdownMenuItem(value: 'newest', child: Text('الأحدث')),
              DropdownMenuItem(value: 'price_low', child: Text('السعر: الأقل أولاً')),
              DropdownMenuItem(value: 'price_high', child: Text('السعر: الأعلى أولاً')),
            ],
            onChanged: (v) => sheetSet(() => _fSort = v ?? 'none'),
          ),
          const SizedBox(height: 16),

          ElevatedButton.icon(
            onPressed: () {
              setState(() {});
              Navigator.pop(context);
            },
            icon: const Icon(Icons.check, color: AppTheme.deepBlack),
            label: Text(
              'تطبيق${_activeAdvCount > 0 ? ' (${_activeAdvCount})' : ''}',
              style: const TextStyle(
                  color: AppTheme.deepBlack, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGold,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _fDeco(String label) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppTheme.textGrey, fontSize: 13),
        filled: true,
        fillColor: AppTheme.scaffoldBackground,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppTheme.primaryGold.withOpacity(0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppTheme.primaryGold.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppTheme.primaryGold),
        ),
      );

  Widget _buildChip(String label, bool isSelected, VoidCallback onTap) {
    return FilterChip(
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      labelPadding: const EdgeInsets.symmetric(horizontal: 6),
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? AppTheme.deepBlack : AppTheme.textWhite,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
          fontSize: 12,
        ),
      ),
      selected: isSelected,
      selectedColor: AppTheme.primaryGold,
      backgroundColor: AppTheme.surfaceBlack,
      checkmarkColor: AppTheme.deepBlack,
      side: BorderSide(color: AppTheme.primaryGold.withOpacity(0.45)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      onSelected: (_) => onTap(),
    );
  }
}

/// عنوان مقطع داخل نافذة الفلاتر
class _FSectionTitle extends StatelessWidget {
  final String text;
  const _FSectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
          color: AppTheme.primaryGold,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }
}
