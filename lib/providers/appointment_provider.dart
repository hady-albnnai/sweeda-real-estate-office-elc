import 'package:flutter/foundation.dart';
import '../models/appointment_model.dart';
import '../core/network/supabase_service.dart';
import '../core/constants/db_constants.dart';

class AppointmentProvider with ChangeNotifier {
  List<AppointmentModel> _myAppointments = [];
  bool _isLoading = false;
  List<String> _bookedSlots = [];

  List<AppointmentModel> get myAppointments => _myAppointments;
  bool get isLoading => _isLoading;
  List<String> get bookedSlots => _bookedSlots;

  /// نتيجة آخر حجز — تتضمن عدد المواعيد النشطة
  int lastBookingActiveCount = 0;

  Future<List<String>> fetchBookedSlots(String offerId, DateTime date) async {
    try {
      final response = await SupabaseService().invokeFunction(
        'user-appointments',
        body: {
          'action': 'get_booked_slots',
          'offer_id': offerId,
          'date': date.toIso8601String().split('T')[0],
        },
      );
      final data = response.data;
      if (data is Map && data['success'] == true) {
        _bookedSlots = List<String>.from(data['booked_slots'] ?? []);
        notifyListeners();
        return _bookedSlots;
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<bool> bookAppointment({
    required String userId,
    required String offerId,
    required String selectedDayKey,
    required String selectedTime,
    String? brokerId,
    String? requestId,
  }) async {
    try {
      if (userId.isEmpty || offerId.isEmpty) return false;

      final dateTime = _resolveNextAppointmentDate(
        selectedDayKey,
        selectedTime,
      );
      if (dateTime == null) return false;

      final resultRes = await SupabaseService().invokeFunction(
        'user-appointments',
        body: {
          'action': 'book',
          'user_uid': userId,
          'offerId': offerId,
          'dt': dateTime.toIso8601String(),
          'brokerId': brokerId,
          'requestId': requestId,
        },
      );
      final result = resultRes.data;

      // السيرفر يرجع JSONB: {success, active_appointments, supervisor_uid}
      if (result is Map) {
        lastBookingActiveCount = (result['active_appointments'] ?? 0) as int;
      }

      await fetchMyAppointments(userId);
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<List<AppointmentModel>> fetchMyAppointments(String userId) async {
    _isLoading = true;
    notifyListeners();
    try {
      final res = await SupabaseService().invokeFunction(
        'user-appointments',
        body: {'action': 'list_user_appointments', 'user_uid': userId},
      );
      final data = res.data as Map;
      final response = data['appointments'];
      _myAppointments = (response as List)
          .map((d) => AppointmentModel.fromSupabase(
              Map<String, dynamic>.from(d), d['id'] as String))
          .toList();
    } catch (e) {
      // تم تجاهل الخطأ عمداً للحفاظ على التدفق الحالي.
    }
    _isLoading = false;
    notifyListeners();
    return _myAppointments;
  }

  Future<List<AppointmentModel>> fetchAppointmentsForMyOffers(String userId) async {
    try {
      final res = await SupabaseService().invokeFunction(
        'user-appointments',
        body: {'action': 'list_owner_appointments', 'user_uid': userId},
      );
      final data = res.data as Map;
      final response = data['appointments'];
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
      await SupabaseService().invokeFunction(
        'user-appointments',
        body: {
          'action': 'cancel',
          'user_uid': userId,
          'appointmentId': appointmentId,
          'reason': reason,
        },
      );
      await fetchMyAppointments(userId);
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// تحديث حالة موعد — يستخدم admin_update_appointment_status_internal
  /// لتجنب direct update على appointments مع RLS
  Future<bool> updateStatus(String appointmentId, int newStatus,
      {int? feedback, String adminUid = ''}) async {
    try {
      // نستخدم RPC الإدارية إذا توفر adminUid، وإلا نستخدم broker_handle
      if (adminUid.isNotEmpty) {
        await SupabaseService().invokeFunction('admin-appointments', body: {'action': 'update_status', 'appointmentId': appointmentId, 'status': newStatus, 'adminNote': ''});
      } else {
        // fallback: direct update محدود للحالات التي لا تحتاج uid
        final data = <String, dynamic>{'sts': newStatus};
        if (newStatus >= 2) data['dt_end'] = DateTime.now().toIso8601String();
        if (feedback != null) {
          data['fbk_own']    = feedback;
          data['fbk_own_dt'] = DateTime.now().toIso8601String();
        }
        await SupabaseService().client
            .from(DbTables.appointments)
            .update(data)
            .eq('id', appointmentId);
      }
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
      final response = await SupabaseService().invokeFunction(
        'user-appointments',
        body: {
          'action': 'owner_respond',
          'user_uid': ownerUid,
          'appointment_id': appointmentId,
          'accept': accept,
          'reject_reason': rejectReason,
          'reject_text': rejectText,
          'proposed_dt': proposedDt?.toIso8601String(),
        },
      );
      final data = response.data;
      if (data == null || data['success'] != true) return false;
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
      final response = await SupabaseService().invokeFunction(
        'user-appointments',
        body: {
          'action': 'requester_counter',
          'user_uid': userUid,
          'appointment_id': appointmentId,
          'accept': accept,
          'proposed_dt': proposedDt?.toIso8601String(),
        },
      );
      final data = response.data;
      if (data == null || data['success'] != true) return false;
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
