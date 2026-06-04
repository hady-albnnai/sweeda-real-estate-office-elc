import 'package:flutter/foundation.dart';
import '../models/offer_model.dart';
import '../core/network/supabase_service.dart';
import '../core/constants/db_constants.dart';

class AdminProvider with ChangeNotifier {
  Future<List<OfferModel>> getPendingOffers() async {
    try {
      final response = await SupabaseService().client
          .from(DbTables.offers).select()
          .eq('sts', 0).eq('i_del', 0).order('ts_crt', ascending: false);
      return (response as List).map((d) =>
          OfferModel.fromSupabase(Map<String, dynamic>.from(d), d['id'] as String)).toList();
    } catch (e) { debugPrint('❌ getPendingOffers error: $e'); return []; }
  }

  Future<bool> reviewOffer(String offerId, bool approve) async {
    try {
      final now = DateTime.now().toIso8601String();
      await SupabaseService().client.from(DbTables.offers).update({
        'sts': approve ? 1 : 3, 'i_pub': approve ? 1 : 0,
        'ts_pub': approve ? now : null, 'ts_upd': now,
      }).eq('id', offerId);
      notifyListeners(); return true;
    } catch (e) { debugPrint('❌ reviewOffer error: $e'); return false; }
  }

  Future<bool> updateUserRole(String uid, int newRole) async {
    try {
      await SupabaseService().client.from(DbTables.users).update({
        'role': newRole, 'ts_upd': DateTime.now().toIso8601String(),
      }).eq('id', uid);
      notifyListeners(); return true;
    } catch (e) { debugPrint('❌ updateUserRole error: $e'); return false; }
  }

  Future<bool> activatePackage(String paymentId, String uid, int packageType) async {
    try {
      final pkgDurations = {0: 30, 1: 45, 2: 60};
      await SupabaseService().client.from(DbTables.payments)
          .update({'sts': 1}).eq('id', paymentId);
      final pkgEnd = DateTime.now().add(Duration(days: pkgDurations[packageType] ?? 30));
      final user = await SupabaseService().client
          .from(DbTables.users).select('pt').eq('id', uid).single();
      final currentPts = (user['pt'] as int? ?? 0) + 100;
      await SupabaseService().client.from(DbTables.users).update({
        'b_pkg': packageType, 'pkg_end': pkgEnd.toIso8601String(),
        'pt': currentPts, 'ts_upd': DateTime.now().toIso8601String(),
      }).eq('id', uid);
      notifyListeners(); return true;
    } catch (e) { debugPrint('❌ activatePackage error: $e'); return false; }
  }

  Future<bool> banUser(String uid, String reason) async {
    try {
      await SupabaseService().client.from(DbTables.users).update({
        'sts': 2, 'ban_rsn': reason,
        'ts_upd': DateTime.now().toIso8601String(),
      }).eq('id', uid);
      notifyListeners(); return true;
    } catch (e) { debugPrint('❌ banUser error: $e'); return false; }
  }

  Future<Map<String, dynamic>> getStats() async {
    try {
      final offers = await SupabaseService().client.from(DbTables.offers).select('id').eq('i_del', 0);
      final users = await SupabaseService().client.from(DbTables.users).select('id').eq('i_del', 0);
      final pending = await SupabaseService().client.from(DbTables.offers).select('id').eq('sts', 0).eq('i_del', 0);
      return {'totalOffers': (offers as List).length, 'totalUsers': (users as List).length, 'pendingOffers': (pending as List).length};
    } catch (e) { debugPrint('❌ getStats error: $e'); return {}; }
  }
}
