import 'package:flutter/foundation.dart';
import '../models/appointment_model.dart';
import '../core/network/supabase_service.dart';
import '../core/constants/db_constants.dart';

class AppointmentProvider with ChangeNotifier {
  List<AppointmentModel> _myAppointments = [];
  bool _isLoading = false;

  List<AppointmentModel> get myAppointments => _myAppointments;
  bool get isLoading => _isLoading;

  Future<bool> bookAppointment({
    required String userId, required String offerId, required String ownerId,
    DateTime? dateTime,
  }) async {
    try {
      final appointment = AppointmentModel(
        id: '', offId: offerId, ownId: ownerId,
        dt: dateTime ?? DateTime.now().add(const Duration(days: 1)),
        sts: 0, fbkOwn: 0, fbkReq: 0, tsCrt: DateTime.now(),
      );
      await SupabaseService().client.from(DbTables.appointments).insert(appointment.toMap());
      await fetchMyAppointments(userId);
      notifyListeners(); return true;
    } catch (e) { debugPrint('❌ bookAppointment error: $e'); return false; }
  }

  Future<void> fetchMyAppointments(String userId) async {
    _isLoading = true; notifyListeners();
    try {
      final response = await SupabaseService().client
          .from(DbTables.appointments).select()
          .eq('own_id', userId).order('dt', ascending: true);
      _myAppointments = (response as List).map((d) =>
          AppointmentModel.fromSupabase(Map<String, dynamic>.from(d), d['id'] as String)).toList();
    } catch (e) { debugPrint('❌ fetchMyAppointments error: $e'); }
    _isLoading = false; notifyListeners();
  }

  Future<List<AppointmentModel>> fetchAppointmentsForMyOffers(String userId) async {
    try {
      final offersResponse = await SupabaseService().client
          .from(DbTables.offers).select('id')
          .eq('usr_id', userId).eq('i_del', 0);
      final offerIds = (offersResponse as List).map((o) => o['id'] as String).toList();
      if (offerIds.isEmpty) return [];
      final response = await SupabaseService().client
          .from(DbTables.appointments).select()
          .inFilter('off_id', offerIds).order('dt', ascending: true);
      return (response as List).map((d) =>
          AppointmentModel.fromSupabase(Map<String, dynamic>.from(d), d['id'] as String)).toList();
    } catch (e) { debugPrint('❌ fetchAppointmentsForMyOffers error: $e'); return []; }
  }

  Future<bool> cancelAppointment(String appointmentId, String userId, String reason) async {
    try {
      await SupabaseService().client.from(DbTables.appointments).update({
        'sts': 3,
        'cnl_by': userId,
        'cnl_rsn': reason,
      }).eq('id', appointmentId);
      await fetchMyAppointments(userId);
      notifyListeners(); return true;
    } catch (e) { debugPrint('❌ cancelAppointment error: $e'); return false; }
  }

  Future<bool> updateStatus(String appointmentId, int newStatus, {int? feedback}) async {
    try {
      final data = {'sts': newStatus, 'dt_end': DateTime.now().toIso8601String()};
      if (feedback != null) {
        data['fbk_own'] = feedback;
        data['fbk_own_dt'] = DateTime.now().toIso8601String();
      }
      await SupabaseService().client.from(DbTables.appointments).update(data).eq('id', appointmentId);
      notifyListeners(); return true;
    } catch (e) { debugPrint('❌ updateStatus error: $e'); return false; }
  }
}
