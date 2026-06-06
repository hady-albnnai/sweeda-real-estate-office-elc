import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/offer_model.dart';
import '../core/network/supabase_service.dart';
import '../core/constants/db_constants.dart';
import '../core/services/local_cache_service.dart';
import '../core/services/business_service.dart';

class OfferProvider with ChangeNotifier {
  List<OfferModel> _offers = [];
  bool _isLoading = false;
  String? _error;
  bool _fromCache = false;
  StreamSubscription? _realtimeSub;
  
  // تتبع ما إذا كانت القائمة الحالية ناتجة عن بحث
  bool _isSearching = false;

  List<OfferModel> get offers => _offers;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get fromCache => _fromCache;

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
      // حفظ في الكاش
      await LocalCacheService()
          .saveOffers(_offers.map((o) => {'id': o.id, ...o.toMap()}).toList());
    } catch (e) {
      // عند الفشل: إن كان عندنا كاش نكمل به بدون خطأ صريح
      if (_offers.isEmpty) {
        _error = 'فشل في جلب العروض. تحقق من الاتصال.';
      } else {
        _fromCache = true;
        debugPrint('⚠️ offers: استخدام الكاش (تعذّر الاتصال): $e');
      }
      debugPrint('❌ fetchOffers error: $e');
    }
    _isLoading = false;
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
            LocalCacheService()
                .saveOffers(_offers.map((o) => {'id': o.id, ...o.toMap()}).toList());
            notifyListeners();
          } else {
            debugPrint('ℹ️ Realtime update ignored: Search is active');
          }
        }
      });
      debugPrint('✅ OfferProvider: Realtime active');
    } catch (e) {
      debugPrint('⚠️ subscribeRealtime error: $e');
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
      final response = await SupabaseService().client
          .from(DbTables.offers).select()
          .eq('usr_id', userId).eq('i_del', 0)
          .order('ts_crt', ascending: false);
      return (response as List).map((d) =>
          OfferModel.fromSupabase(Map<String, dynamic>.from(d), d['id'] as String)).toList();
    } catch (e) { debugPrint('❌ fetchUserOffers error: $e'); return []; }
  }

  Future<OfferModel?> fetchOfferById(String offerId) async {
    try {
      final response = await SupabaseService().client
          .from(DbTables.offers).select()
          .eq('id', offerId).eq('i_del', 0).single();
      return OfferModel.fromSupabase(
          Map<String, dynamic>.from(response), response['id'] as String);
    } catch (e) { debugPrint('❌ fetchOfferById error: $e'); return null; }
  }

  Future<OfferModel?> addOffer(OfferModel offer) async {
    try {
      final response = await SupabaseService().client
          .from(DbTables.offers).insert(offer.toMap()).select().single();
      final created = OfferModel.fromSupabase(
          Map<String, dynamic>.from(response), response['id'] as String);
      _offers.insert(0, created);
      notifyListeners();
      
      // تحديث إحصائيات المستخدم (عدد العروض)
      await BusinessService().updateUserStat(offer.usrId, 'off');
      
      return created;
    } catch (e) {
      debugPrint('❌ addOffer error: $e');
      return null;
    }
  }

  Future<bool> updateOffer(String offerId, Map<String, dynamic> data) async {
    try {
      await SupabaseService().client.from(DbTables.offers)
          .update({...data, 'ts_upd': DateTime.now().toIso8601String()}).eq('id', offerId);
      
      // منع تجديد العروض المرفوضة (sts == 3) إلا إذا تغيرت الحالة
      // يتم التحقق في السيرفر عادة، ولكن هنا نمنع التحديث إذا كان الغرض التجديد فقط والعرض مرفوض
      if (data.containsKey('ts_ren') && data['sts'] == null) {
         final offer = await fetchOfferById(offerId);
         if (offer != null && offer.sts == 3) {
            debugPrint('⚠️ Cannot renew a rejected offer');
            return false;
         }
      }

      final index = _offers.indexWhere((o) => o.id == offerId);
      if (index != -1) {
        final updated = await fetchOfferById(offerId);
        if (updated != null) _offers[index] = updated;
      }
      notifyListeners(); return true;
    } catch (e) { debugPrint('❌ updateOffer error: $e'); return false; }
  }

  Future<bool> softDeleteOffer(String offerId) => updateOffer(offerId, {'i_del': 1});

  Future<void> incrementViews(String offerId) async {
    try {
      final current = await SupabaseService().client
          .from(DbTables.offers).select('vws').eq('id', offerId).single();
      final v = (current['vws'] as int? ?? 0) + 1;
      await SupabaseService().client.from(DbTables.offers)
          .update({'vws': v}).eq('id', offerId);
    } catch (e) { debugPrint('⚠️ incrementViews error: $e'); }
  }

  Future<List<OfferModel>> searchOffers({
    String? query, int? type, int? transaction, int? category,
  }) async {
    _isSearching = true; // تفعيل حالة البحث
    try {
      var q = SupabaseService().client.from(DbTables.offers)
          .select().eq('i_del', 0).eq('i_pub', 1);
      if (query != null && query.isNotEmpty) q = q.ilike('ttl', '%$query%');
      if (type != null) q = q.eq('typ', type);
      if (transaction != null) q = q.eq('trx', transaction);
      if (category != null) q = q.eq('cat', category);
      final response = await q.order('ts_crt', ascending: false);
      final results = (response as List).map((d) =>
          OfferModel.fromSupabase(Map<String, dynamic>.from(d), d['id'] as String)).toList();
      
      _offers = results;
      notifyListeners();
      return results;
    } catch (e) { debugPrint('❌ searchOffers error: $e'); return []; }
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
