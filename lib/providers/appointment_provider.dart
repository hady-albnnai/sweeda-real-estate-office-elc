import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/appointment_model.dart';
import '../core/network/supabase_service.dart';
import '../core/constants/db_constants.dart';

/// نتيجة محاولة حجز موعد — تحمل رمز الخطأ والاقتراح البديل إن وُجد
class BookingResult {
  final bool success;
  final String? errorCode;
  final DateTime? suggestedDt;
  final int activeCount;

  const BookingResult({
    required this.success,
    this.errorCode,
    this.suggestedDt,
    this.activeCount = 0,
  });
}

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

  Future<BookingResult> bookAppointment({
    required String userId,
    required String offerId,
    required String selectedDayKey,
    required String selectedTime,
    String? brokerId,
    String? requestId,
  }) async {
    try {
      if (userId.isEmpty || offerId.isEmpty) {
        return const BookingResult(success: false, errorCode: 'INVALID_INPUT');
      }

      final dateTime = _resolveNextAppointmentDate(
        selectedDayKey,
        selectedTime,
      );
      if (dateTime == null) {
        return const BookingResult(success: false, errorCode: 'INVALID_INPUT');
      }

      final resultRes = await SupabaseService().invokeFunction(
        'user-appointments',
        body: {
          'action': 'book',
          'user_uid': userId,
          'offerId': offerId,
          // إرسال بصيغة UTC مع لاحقة Z — بدونها يفسّر السيرفر الوقت خطأً
          // وينزاح عن اختيار المستخدم (يكسر فحص avl)
          'dt': dateTime.toUtc().toIso8601String(),
          'brokerId': brokerId,
          'requestId': requestId,
        },
      );
      final result = resultRes.data;

      // السيرفر يرجع JSONB:
      // نجاح: {success:true, appointment_id, active_appointments, supervisor_uid}
      // فشل مُدار: {success:false, error:'NO_SUPERVISOR_AVAILABLE', suggested_dt}
      if (result is Map) {
        if (result['success'] == true) {
          lastBookingActiveCount = (result['active_appointments'] ?? 0) as int;
          await fetchMyAppointments(userId);
          notifyListeners();
          return BookingResult(
            success: true,
            activeCount: lastBookingActiveCount,
          );
        }
        DateTime? suggested;
        final rawSuggested = result['suggested_dt'];
        if (rawSuggested is String && rawSuggested.isNotEmpty) {
          suggested = DateTime.tryParse(rawSuggested)?.toLocal();
        }
        return BookingResult(
          success: false,
          errorCode: (result['error'] ?? 'UNKNOWN').toString(),
          suggestedDt: suggested,
        );
      }
      return const BookingResult(success: false, errorCode: 'UNKNOWN');
    } on FunctionException catch (e) {
      // أخطاء RPC المرفوعة كـ EXCEPTION تصل هنا برمزها من الـ Edge Function
      final details = e.details;
      String code = 'UNKNOWN';
      if (details is Map && details['error'] != null) {
        code = details['error'].toString();
      }
      return BookingResult(success: false, errorCode: code);
    } catch (e) {
      return const BookingResult(success: false, errorCode: 'NETWORK');
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

  /// تحويل رد السيرفر (JSONB) لنتيجة مهيكلة — مشترك لمسارَي التراشق
  BookingResult _parseNegotiationResponse(dynamic data) {
    if (data is Map) {
      if (data['success'] == true) {
        notifyListeners();
        return const BookingResult(success: true);
      }
      DateTime? suggested;
      final rawSuggested = data['suggested_dt'];
      if (rawSuggested is String && rawSuggested.isNotEmpty) {
        suggested = DateTime.tryParse(rawSuggested)?.toLocal();
      }
      return BookingResult(
        success: false,
        errorCode: (data['error'] ?? 'UNKNOWN').toString(),
        suggestedDt: suggested,
      );
    }
    return const BookingResult(success: false, errorCode: 'UNKNOWN');
  }

  /// رد صاحب العرض على طلب الحجز
  /// rejectReason: 0=الوقت لا يناسب، 1=غير مهتم، 2=آخر
  Future<BookingResult> ownerRespondAppointment({
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
          // UTC مع لاحقة Z — كما في bookAppointment
          'proposed_dt': proposedDt?.toUtc().toIso8601String(),
        },
      );
      return _parseNegotiationResponse(response.data);
    } on FunctionException catch (e) {
      final details = e.details;
      String code = 'UNKNOWN';
      if (details is Map && details['error'] != null) {
        code = details['error'].toString();
      }
      return BookingResult(success: false, errorCode: code);
    } catch (e) {
      return const BookingResult(success: false, errorCode: 'NETWORK');
    }
  }

  /// رد طالب الحجز على الوقت البديل المقترح
  Future<BookingResult> requesterCounterAppointment({
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
          // UTC مع لاحقة Z — كما في bookAppointment
          'proposed_dt': proposedDt?.toUtc().toIso8601String(),
        },
      );
      return _parseNegotiationResponse(response.data);
    } on FunctionException catch (e) {
      final details = e.details;
      String code = 'UNKNOWN';
      if (details is Map && details['error'] != null) {
        code = details['error'].toString();
      }
      return BookingResult(success: false, errorCode: code);
    } catch (e) {
      return const BookingResult(success: false, errorCode: 'NETWORK');
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
