import 'package:flutter/foundation.dart';
import '../models/appointment_model.dart';
import '../core/network/supabase_service.dart';
import '../core/constants/db_constants.dart';

class BrokerProvider with ChangeNotifier {
  Future<List<AppointmentModel>> getBrokerAppointments(String brokerId) async {
    try {
      final offersSnap = await SupabaseService().client
          .from(DbTables.offers).select('id')
          .eq('usr_id', brokerId).eq('i_del', 0);
      final offerIds = (offersSnap as List).map((o) => o['id'] as String).toList();
      if (offerIds.isEmpty) return [];
      final appSnap = await SupabaseService().client
          .from(DbTables.appointments).select()
          .inFilter('off_id', offerIds).order('dt', ascending: true);
      return (appSnap as List).map((d) =>
          AppointmentModel.fromSupabase(Map<String, dynamic>.from(d), d['id'] as String)).toList();
    } catch (e) { debugPrint('❌ getBrokerAppointments error: $e'); return []; }
  }

  Future<bool> handleAppointment(String apptId, int feedback) async {
    try {
      final now = DateTime.now().toIso8601String();
      final data = {'fbk_own': feedback, 'fbk_own_dt': now};
      if (feedback == 1) data['sts'] = 1;
      else if (feedback == 2) data['sts'] = 3;
      else data['sts'] = 0;
      await SupabaseService().client.from(DbTables.appointments).update(data).eq('id', apptId);
      notifyListeners(); return true;
    } catch (e) { debugPrint('❌ handleAppointment error: $e'); return false; }
  }
}
