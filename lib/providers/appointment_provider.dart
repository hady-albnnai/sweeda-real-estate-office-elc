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
    required String userId,
    required String offerId,
    required String ownerId,
    required String selectedDayKey,
    required String selectedTime,
    String? brokerId,
    String? requestId,
  }) async {
    try {
      if (userId.isEmpty || offerId.isEmpty || ownerId.isEmpty) return false;
      if (userId == ownerId) return false;

      final dateTime = _resolveNextAppointmentDate(
        selectedDayKey,
        selectedTime,
      );
      if (dateTime == null) return false;

      await SupabaseService().client.rpc(
        'book_appointment_internal',
        params: {
          'p_user_uid': userId,
          'p_offer_id': offerId,
          'p_dt': dateTime.toIso8601String(),
          'p_broker_id': brokerId,
          'p_request_id': requestId,
        },
      );
      await fetchMyAppointments(userId);
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> fetchMyAppointments(String userId) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await SupabaseService().client.rpc(
        'get_user_appointments_internal',
        params: {'p_user_uid': userId},
      );
      _myAppointments = (response as List)
          .map((d) => AppointmentModel.fromSupabase(
              Map<String, dynamic>.from(d), d['id'] as String))
          .toList();
    } catch (e) {}
    _isLoading = false;
    notifyListeners();
  }

  Future<List<AppointmentModel>> fetchAppointmentsForMyOffers(String userId) async {
    try {
      final response = await SupabaseService().client.rpc(
        'get_owner_appointments_internal',
        params: {'p_owner_uid': userId},
      );
      return (response as List)
          .map((d) => AppointmentModel.fromSupabase(
              Map<String, dynamic>.from(d), d['id'] as String))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<bool> cancelAppointment(
      String appointmentId, String userId, String reason) async {
    try {
      await SupabaseService().client.rpc(
        'cancel_appointment_internal',
        params: {
          'p_requester_uid': userId,
          'p_appointment_id': appointmentId,
          'p_reason': reason,
        },
      );
      await fetchMyAppointments(userId);
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateStatus(String appointmentId, int newStatus,
      {int? feedback}) async {
    try {
      final data = <String, dynamic>{'sts': newStatus};
      if (newStatus >= 2) {
        data['dt_end'] = DateTime.now().toIso8601String();
      }
      if (feedback != null) {
        data['fbk_own'] = feedback;
        data['fbk_own_dt'] = DateTime.now().toIso8601String();
      }
      await SupabaseService()
          .client
          .from(DbTables.appointments)
          .update(data)
          .eq('id', appointmentId);
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// رد صاحب العرض على طلب الحجز
  /// p_rejectReason: 0=الوقت لا يناسب، 1=غير مهتم، 2=آخر
  Future<bool> ownerRespondAppointment({
    required String ownerUid,
    required String appointmentId,
    required bool accept,
    int rejectReason = 0,
    String rejectText = '',
    DateTime? proposedDt,
  }) async {
    try {
      await SupabaseService().client.rpc(
        DbFunctions.ownerRespondAppointment,
        params: {
          'p_owner_uid':       ownerUid,
          'p_appointment_id':  appointmentId,
          'p_accept':          accept,
          'p_reject_reason':   rejectReason,
          'p_reject_text':     rejectText,
          'p_proposed_dt':     proposedDt?.toIso8601String(),
        },
      );
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// رد طالب الحجز على الوقت البديل المقترح
  Future<bool> requesterCounterAppointment({
    required String userUid,
    required String appointmentId,
    required bool accept,
    DateTime? proposedDt,
  }) async {
    try {
      await SupabaseService().client.rpc(
        DbFunctions.requesterCounterAppointment,
        params: {
          'p_user_uid':        userUid,
          'p_appointment_id':  appointmentId,
          'p_accept':          accept,
          'p_proposed_dt':     proposedDt?.toIso8601String(),
        },
      );
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  DateTime? _resolveNextAppointmentDate(String dayKey, String timeText) {
    final weekday = _weekdayFromKey(dayKey);
    final parsedTime = _parseTime(timeText);
    if (weekday == null || parsedTime == null) return null;

    final now = DateTime.now();
    final todayWeekday = now.weekday;
    var daysAhead = (weekday - todayWeekday) % 7;
    if (daysAhead < 0) daysAhead += 7;

    var scheduled = DateTime(
      now.year,
      now.month,
      now.day,
      parsedTime.$1,
      parsedTime.$2,
    ).add(Duration(days: daysAhead));

    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 7));
    }
    return scheduled;
  }

  int? _weekdayFromKey(String key) {
    switch (key.toLowerCase().trim()) {
      case 'mon':
        return DateTime.monday;
      case 'tue':
        return DateTime.tuesday;
      case 'wed':
        return DateTime.wednesday;
      case 'thu':
        return DateTime.thursday;
      case 'fri':
        return DateTime.friday;
      case 'sat':
        return DateTime.saturday;
      case 'sun':
        return DateTime.sunday;
      default:
        return null;
    }
  }

  (int, int)? _parseTime(String raw) {
    final normalized = raw
        .trim()
        .replaceAll('٠', '0')
        .replaceAll('١', '1')
        .replaceAll('٢', '2')
        .replaceAll('٣', '3')
        .replaceAll('٤', '4')
        .replaceAll('٥', '5')
        .replaceAll('٦', '6')
        .replaceAll('٧', '7')
        .replaceAll('٨', '8')
        .replaceAll('٩', '9')
        .replaceAll('ص', 'AM')
        .replaceAll('م', 'PM')
        .toUpperCase();

    final match = RegExp(r'^(\d{1,2}):(\d{2})(?:\s*(AM|PM))?$')
        .firstMatch(normalized);
    if (match == null) return null;

    var hour = int.tryParse(match.group(1) ?? '');
    final minute = int.tryParse(match.group(2) ?? '');
    final suffix = match.group(3);
    if (hour == null || minute == null || hour > 23 || minute > 59) {
      return null;
    }

    if (suffix == 'AM' && hour == 12) hour = 0;
    if (suffix == 'PM' && hour < 12) hour += 12;
    return (hour, minute);
  }
}
