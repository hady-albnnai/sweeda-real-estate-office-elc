import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/offer_model.dart';
import '../models/user_model.dart';
import '../core/network/supabase_service.dart';
import '../core/constants/db_constants.dart';
import '../core/services/local_cache_service.dart';
import '../core/services/business_service.dart';
import '../core/utils/error_utils.dart';

class OfferProvider with ChangeNotifier {
  List<OfferModel> _offers = [];
  bool _isLoading = false;
  String? _error;
  bool _fromCache = false;
  StreamSubscription? _realtimeSub;

  // تتبع ما إذا كانت القائمة الحالية ناتجة عن بحث
  bool _isSearching = false;

  // 📄 Pagination — مرجع: docs/LOGIC_SPEC.md §4.2
  static const int pageSize = 20;
  int _currentPage = 0;
  bool _hasMore = true;
  bool _loadingMore = false;

  bool get hasMore => _hasMore;
  bool get loadingMore => _loadingMore;

  List<OfferModel> get offers => _offers;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get fromCache => _fromCache;

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void _setError(Object? error) {
    _error = ErrorUtils.arabicMessage(error);
  }

  /// 🏢 إثراء قائمة العروض بتسميات الملاك المهنية (هوية المكتب).
  /// يجلب الملاك في استعلام واحد batch، ثم يحقن ownerLabel في كل عرض.
  /// مرجع: docs/LOGIC_SPEC.md §1
  Future<void> _enrichOwnerLabels(List<OfferModel> offers) async {
    if (offers.isEmpty) return;
    try {
      final ownerIds = offers
          .map((o) => o.usrId)
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();
      if (ownerIds.isEmpty) return;

      final res = await SupabaseService()
          .client
          .from(DbTables.usersPublic)
          .select('id, nm, role, brk, bg, vrf, ts_crt')
          .inFilter('id', ownerIds);

      final Map<String, UserModel> ownersMap = {};
      for (final row in (res as List)) {
        final m = Map<String, dynamic>.from(row);
        ownersMap[m['id'] as String] = UserModel.fromSupabase(m, m['id'] as String);
      }

      final bs = BusinessService();
      for (final o in offers) {
        final owner = ownersMap[o.usrId];
        if (owner != null) {
          o.ownerLabel = bs.getUserPublicLabel(owner);
        }
      }
    } catch (e) {
      _setError(e);
    }
  }

  Future<void> fetchOffers() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    // 1) عرض الكاش فوراً (دعم العمل دون اتصال)
    if (_offers.isEmpty) {
      final cached = LocalCacheService().getOffers();
      if (cached.isNotEmpty) {
        _offers = cached
            .map((d) => OfferModel.fromSupabase(d, d['id'] as String))
            .toList();
        _fromCache = true;
        notifyListeners();
      }
    }

    // 2) جلب من السيرفر
    try {
      final response = await SupabaseService().client
          .from(DbTables.offers)
          .select()
          .eq('i_del', 0)
          .eq('i_pub', 1)
          .order('i_pin', ascending: false) // المثبّتة أولاً
          .order('i_fms', ascending: false) // ثم المميّزة
          .order('i_bst', ascending: false) // ثم Boost
          .order('ts_crt', ascending: false);
      _offers = (response as List)
          .map((d) =>
              OfferModel.fromSupabase(Map<String, dynamic>.from(d), d['id'] as String))
          .toList();
      _fromCache = false;
      // 🏢 إثراء بهوية المكتب
      await _enrichOwnerLabels(_offers);
      // حفظ في الكاش
      await LocalCacheService()
          .saveOffers(_offers.map((o) => {'id': o.id, ...o.toMap()}).toList());
    } catch (e) {
      // عند الفشل: إن كان عندنا كاش نكمل به بدون خطأ صريح
      if (_offers.isEmpty) {
        _error = 'فشل في جلب العروض. تحقق من الاتصال.';
      } else {
        _fromCache = true;
        _setError(e);
      }
    }
    // 📄 إعادة ضبط حالة pagination بعد fetch جديد
    _currentPage = (_offers.length / pageSize).ceil();
    _hasMore = _offers.length >= pageSize;
    _isLoading = false;
    notifyListeners();
  }

  /// 📄 تحميل صفحة تالية من العروض (Pagination).
  /// تُستدعى عند وصول المستخدم لأسفل القائمة (Infinite scroll).
  /// مرجع: docs/LOGIC_SPEC.md §4.2
  Future<void> loadMoreOffers() async {
    if (_loadingMore || !_hasMore || _isSearching) return;
    _loadingMore = true;
    notifyListeners();

    try {
      final from = _currentPage * pageSize;
      final to = from + pageSize - 1;
      final response = await SupabaseService().client
          .from(DbTables.offers)
          .select()
          .eq('i_del', 0)
          .eq('i_pub', 1)
          .order('i_pin', ascending: false)
          .order('i_fms', ascending: false)
          .order('i_bst', ascending: false)
          .order('ts_crt', ascending: false)
          .range(from, to);

      final newOffers = (response as List)
          .map((d) => OfferModel.fromSupabase(
              Map<String, dynamic>.from(d), d['id'] as String))
          .toList();

      if (newOffers.isEmpty || newOffers.length < pageSize) {
        _hasMore = false;
      }
      if (newOffers.isNotEmpty) {
        // تجنب التكرار: استبعاد العروض الموجودة مسبقاً
        final existingIds = _offers.map((o) => o.id).toSet();
        final unique =
            newOffers.where((o) => !existingIds.contains(o.id)).toList();
        await _enrichOwnerLabels(unique);
        _offers.addAll(unique);
        _currentPage++;
      }
    } catch (e) {
      _setError(e);
    }
    _loadingMore = false;
    notifyListeners();
  }

  /// تفعيل التحديث الفوري (Realtime) لقائمة العروض المنشورة
  void subscribeRealtime() {
    _realtimeSub?.cancel();
    try {
      _realtimeSub = SupabaseService()
          .client
          .from(DbTables.offers)
          .stream(primaryKey: ['id'])
          .order('ts_crt', ascending: false)
          .listen((data) {
        final published = data
            .where((row) =>
                (row['i_pub'] ?? 0) == 1 && (row['i_del'] ?? 0) == 0)
            .map((row) =>
                OfferModel.fromSupabase(Map<String, dynamic>.from(row), row['id'] as String))
            .toList();
        
        if (published.isNotEmpty) {
          // تحديث القائمة فقط إذا لم يكن المستخدم في وضع البحث
          if (!_isSearching) {
            _offers = published;
            _fromCache = false;
            // 🏢 إثراء بهوية المكتب (fire-and-forget لا يعطل التدفق)
            _enrichOwnerLabels(_offers).then((_) => notifyListeners());
            LocalCacheService()
                .saveOffers(_offers.map((o) => {'id': o.id, ...o.toMap()}).toList());
            notifyListeners();
          } else {}
        }
      });} catch (e) {
      _setError(e);
    }
  }

  void unsubscribeRealtime() {
    _realtimeSub?.cancel();
    _realtimeSub = null;
  }

  @override
  void dispose() {
    _realtimeSub?.cancel();
    super.dispose();
  }

  Future<List<OfferModel>> fetchUserOffers(String userId) async {
    try {
      final response = await SupabaseService().client.functions.invoke(
        'user-offers',
        body: {
          'action': 'list',
          'user_uid': userId,
        },
      );
      final data = response.data;
      if (data == null || data['success'] != true) throw Exception(data?['error'] ?? 'Unknown error');
      final rawList = data['offers'] as List;
      final list = rawList
          .map((d) => OfferModel.fromSupabase(
              Map<String, dynamic>.from(d), d['id'] as String))
          .toList();
      await _enrichOwnerLabels(list);
      return list;
    } catch (e) {
      _setError(e);
      return [];
    }
  }

  Future<OfferModel?> fetchOfferById(String offerId, {String? userId}) async {
    try {
      final response = await SupabaseService().client.functions.invoke(
        'user-offers',
        body: {
          'action': 'get_by_id',
          'offer_id': offerId,
          'user_uid': userId,
        },
      );
      final data = response.data;
      if (data == null || data['success'] != true) return null;
      final offerData = data['offer'];
      if (offerData == null) return null;
      final row = Map<String, dynamic>.from(offerData as Map);
      final offer = OfferModel.fromSupabase(row, row['id'] as String);
      await _enrichOwnerLabels([offer]);
      return offer;
    } catch (e) {
      _setError(e);
      return null;
    }
  }

  Future<OfferModel?> addOffer(OfferModel offer) async {
    try {
      final res = await SupabaseService().client.functions.invoke('user-offers', body: {'action': 'create', 'offer': offer.toMap()}); final data = res.data as Map; final response = data['offer_id'];
      if (response == null || (response is! List) || response.isEmpty) return null;
      final row = Map<String, dynamic>.from(response.first as Map);
      final created = OfferModel.fromSupabase(row, row['id'] as String);
      _offers.insert(0, created);
      notifyListeners();
      return created;
    } catch (e) {
      _setError(e);
      return null;
    }
  }

  Future<bool> updateOffer(String offerId, Map<String, dynamic> data) async {
    try {
      // offers لا يحتوي ts_upd — نرسل البيانات بدونه
      await SupabaseService().client.from(DbTables.offers)
          .update(data).eq('id', offerId);

      // منع تجديد العروض المرفوضة (sts == 3) إلا إذا تغيرت الحالة
      if (data.containsKey('ts_ren') && data['sts'] == null) {
        final offer = await fetchOfferById(offerId);
        if (offer != null && offer.sts == 3) return false;
      }

      final index = _offers.indexWhere((o) => o.id == offerId);
      if (index != -1) {
        final updated = await fetchOfferById(offerId);
        if (updated != null) _offers[index] = updated;
      }
      notifyListeners();
      return true;
    } catch (e) {
      _setError(e);
      return false;
    }
  }

  Future<bool> softDeleteOffer(String offerId) => updateOffer(offerId, {'i_del': 1});

  Future<void> incrementViews(String offerId) async {
    try {
      await SupabaseService().client.functions.invoke(
        'user-offers',
        body: {
          'action': 'increment_views',
          'offer_id': offerId,
        },
      );
    } catch (e) {
      _setError(e);
    }
  }

  Future<List<OfferModel>> searchOffers({
    String? query, int? type, int? transaction, int? category,
    double? minPrice, double? maxPrice, int? currency,
  }) async {
    _isSearching = true; // تفعيل حالة البحث
    try {
      var q = SupabaseService().client.from(DbTables.offers)
          .select().eq('i_del', 0).eq('i_pub', 1);
      if (query != null && query.isNotEmpty) q = q.ilike('ttl', '%$query%');
      if (type != null) q = q.eq('typ', type);
      if (transaction != null) q = q.eq('trx', transaction);
      if (category != null) q = q.eq('cat', category);
      if (currency != null) q = q.eq('cur', currency);
      if (minPrice != null) q = q.gte('prc', minPrice);
      if (maxPrice != null) q = q.lte('prc', maxPrice);
      final response = await q.order('ts_crt', ascending: false);
      final results = (response as List).map((d) =>
          OfferModel.fromSupabase(Map<String, dynamic>.from(d), d['id'] as String)).toList();

      await _enrichOwnerLabels(results);
      _offers = results;
      notifyListeners();
      return results;
    } catch (e) {
      _setError(e);
      return [];
    }
  }

  void listenToNewOffers(Function(OfferModel) onNewOffer) {
    SupabaseService().client.from(DbTables.offers)
        .stream(primaryKey: ['id'])
        .order('ts_crt', ascending: false)
        .listen((data) {
      for (var row in data) {
        if ((row['i_pub'] ?? 0) == 1 && (row['i_del'] ?? 0) == 0) {
          onNewOffer(OfferModel.fromSupabase(
              Map<String, dynamic>.from(row), row['id'] as String));
        }
      }
    });
  }

  OfferModel? getOfferById(String id) {
    try { return _offers.firstWhere((o) => o.id == id); } catch (_) { return null; }
  }
}
