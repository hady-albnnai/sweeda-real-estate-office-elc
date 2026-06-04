import 'package:flutter/foundation.dart';
import '../models/offer_model.dart';
import '../core/network/supabase_service.dart';
import '../core/constants/db_constants.dart';

class OfferProvider with ChangeNotifier {
  List<OfferModel> _offers = [];
  bool _isLoading = false;
  String? _error;

  List<OfferModel> get offers => _offers;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchOffers() async {
    _isLoading = true; _error = null; notifyListeners();
    try {
      final response = await SupabaseService().client
          .from(DbTables.offers).select()
          .eq('i_del', 0).eq('i_pub', 1)
          .order('ts_crt', ascending: false);
      _offers = (response as List).map((d) =>
          OfferModel.fromSupabase(Map<String, dynamic>.from(d), d['id'] as String)).toList();
    } catch (e) {
      _error = 'فشل في جلب العروض: $e';
      debugPrint('❌ fetchOffers error: $e');
    }
    _isLoading = false; notifyListeners();
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

  Future<bool> addOffer(OfferModel offer) async {
    try {
      final response = await SupabaseService().client
          .from(DbTables.offers).insert(offer.toMap()).select().single();
      _offers.insert(0, OfferModel.fromSupabase(
          Map<String, dynamic>.from(response), response['id'] as String));
      notifyListeners(); return true;
    } catch (e) { debugPrint('❌ addOffer error: $e'); return false; }
  }

  Future<bool> updateOffer(String offerId, Map<String, dynamic> data) async {
    try {
      await SupabaseService().client.from(DbTables.offers)
          .update({...data, 'ts_upd': DateTime.now().toIso8601String()}).eq('id', offerId);
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
    try {
      var q = SupabaseService().client.from(DbTables.offers)
          .select().eq('i_del', 0).eq('i_pub', 1);
      if (query != null && query.isNotEmpty) q = q.ilike('ttl', '%$query%');
      if (type != null) q = q.eq('typ', type);
      if (transaction != null) q = q.eq('trx', transaction);
      if (category != null) q = q.eq('cat', category);
      final response = await q.order('ts_crt', ascending: false);
      return (response as List).map((d) =>
          OfferModel.fromSupabase(Map<String, dynamic>.from(d), d['id'] as String)).toList();
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
