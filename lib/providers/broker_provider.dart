import 'package:flutter/foundation.dart';
import '../models/appointment_model.dart';
import '../models/offer_model.dart';
import '../models/deal_model.dart';
import '../core/network/supabase_service.dart';
import '../core/constants/db_constants.dart';

/// Provider خاص بلوحة الوسيط/السمسار (دور role = 1)
/// يجمع كل عمليات السمسار: المواعيد، العروض، الصفقات، الإحصائيات
class BrokerProvider with ChangeNotifier {
  // ═══════════════════════════════════════
  // الحالة (State)
  // ═══════════════════════════════════════
  bool _isLoading = false;
  String? _error;

  List<AppointmentModel> _appointments = [];
  List<OfferModel> _offers = [];
  List<DealModel> _deals = [];
  Map<String, dynamic> _stats = {};

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<AppointmentModel> get appointments => _appointments;
  List<OfferModel> get offers => _offers;
  List<DealModel> get deals => _deals;
  Map<String, dynamic> get stats => _stats;

  // ═══════════════════════════════════════
  // 1) المواعيد (Appointments)
  // ═══════════════════════════════════════

  /// جلب كل المواعيد المرتبطة بعروض السمسار (المخزّنة في الحالة)
  Future<void> fetchBrokerAppointments(String brokerId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _appointments = await getBrokerAppointments(brokerId);
    } catch (e) {
      _error = 'فشل جلب المواعيد: $e';}
    _isLoading = false;
    notifyListeners();
  }

  /// جلب مواعيد السمسار (دالة مساعدة تُرجع القائمة مباشرة — تُستخدم بـ FutureBuilder)
  Future<List<AppointmentModel>> getBrokerAppointments(String brokerId) async {
    try {
      // المواعيد المرتبطة مباشرة بالسمسار (bkr_id) أو بعروضه
      final offersSnap = await SupabaseService().client
          .from(DbTables.offers)
          .select('id')
          .eq('usr_id', brokerId)
          .eq('i_del', 0);
      final offerIds = (offersSnap as List).map((o) => o['id'] as String).toList();

      final List<dynamic> result = [];

      // مواعيد عروض السمسار
      if (offerIds.isNotEmpty) {
        final appSnap = await SupabaseService().client
            .from(DbTables.appointments)
            .select()
            .inFilter('off_id', offerIds)
            .order('dt', ascending: true);
        result.addAll(appSnap as List);
      }

      // مواعيد مُسندة للسمسار مباشرة
      final assignedSnap = await SupabaseService().client
          .from(DbTables.appointments)
          .select()
          .eq('bkr_id', brokerId)
          .order('dt', ascending: true);
      result.addAll(assignedSnap as List);

      // إزالة التكرار حسب id
      final seen = <String>{};
      final unique = <AppointmentModel>[];
      for (final d in result) {
        final id = d['id'] as String;
        if (seen.add(id)) {
          unique.add(AppointmentModel.fromSupabase(
              Map<String, dynamic>.from(d), id));
        }
      }
      unique.sort((a, b) => a.dt.compareTo(b.dt));
      return unique;
    } catch (e) {return [];
    }
  }

  /// معالجة موعد: 1=قبول, 2=رفض, 0=معلّق
  Future<bool> handleAppointment(String apptId, int feedback) async {
    try {
      final now = DateTime.now().toIso8601String();
      final Map<String, dynamic> data = {'fbk_own': feedback, 'fbk_own_dt': now};
      if (feedback == 1) {
        data['sts'] = 1; // مؤكّد
      } else if (feedback == 2) {
        data['sts'] = 3; // ملغى/مرفوض
      } else {
        data['sts'] = 0; // معلّق
      }
      await SupabaseService()
          .client
          .from(DbTables.appointments)
          .update(data)
          .eq('id', apptId);

      // تحديث الحالة المحلية إن وُجد الموعد
      final i = _appointments.indexWhere((a) => a.id == apptId);
      if (i != -1) {
        _appointments[i] = AppointmentModel.fromSupabase(
          {..._appointments[i].toMap(), ...data},
          apptId,
        );
      }
      notifyListeners();
      return true;
    } catch (e) {return false;
    }
  }

  /// تعليم موعد كمكتمل (تمت المعاينة)
  Future<bool> completeAppointment(String apptId) async {
    try {
      await SupabaseService().client.from(DbTables.appointments).update({
        'sts': 2, // مكتمل
        'dt_end': DateTime.now().toIso8601String(),
      }).eq('id', apptId);
      final i = _appointments.indexWhere((a) => a.id == apptId);
      if (i != -1) {
        _appointments[i] = AppointmentModel.fromSupabase(
          {..._appointments[i].toMap(), 'sts': 2},
          apptId,
        );
      }
      notifyListeners();
      return true;
    } catch (e) {return false;
    }
  }

  // ═══════════════════════════════════════
  // 2) العروض (Offers) — عروض السمسار + العروض المُسندة له
  // ═══════════════════════════════════════

  /// جلب عروض السمسار: عروضه الخاصة + العروض المُسندة له (brk_id)
  Future<void> fetchBrokerOffers(String brokerId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final ownSnap = await SupabaseService().client
          .from(DbTables.offers)
          .select()
          .eq('usr_id', brokerId)
          .eq('i_del', 0)
          .order('ts_crt', ascending: false);

      final assignedSnap = await SupabaseService().client
          .from(DbTables.offers)
          .select()
          .eq('brk_id', brokerId)
          .eq('i_del', 0)
          .order('ts_crt', ascending: false);

      final seen = <String>{};
      final list = <OfferModel>[];
      for (final d in [...(ownSnap as List), ...(assignedSnap as List)]) {
        final id = d['id'] as String;
        if (seen.add(id)) {
          list.add(OfferModel.fromSupabase(Map<String, dynamic>.from(d), id));
        }
      }
      _offers = list;
    } catch (e) {
      _error = 'فشل جلب العروض: $e';}
    _isLoading = false;
    notifyListeners();
  }

  // ═══════════════════════════════════════
  // 3) الصفقات (Deals)
  // ═══════════════════════════════════════

  /// جلب صفقات السمسار (brk_uid)
  Future<void> fetchBrokerDeals(String brokerId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final snap = await SupabaseService().client
          .from(DbTables.deals)
          .select()
          .eq('brk_uid', brokerId)
          .eq('i_del', 0)
          .order('ts_crt', ascending: false);
      _deals = (snap as List)
          .map((d) =>
              DealModel.fromSupabase(Map<String, dynamic>.from(d), d['id'] as String))
          .toList();
    } catch (e) {
      _error = 'فشل جلب الصفقات: $e';}
    _isLoading = false;
    notifyListeners();
  }

  // ═══════════════════════════════════════
  // 4) الإحصائيات (Stats)
  // ═══════════════════════════════════════

  /// حساب إحصائيات السمسار الشاملة
  Future<void> fetchBrokerStats(String brokerId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      // العروض
      final offersSnap = await SupabaseService().client
          .from(DbTables.offers)
          .select('id, sts, vws, fvs')
          .eq('usr_id', brokerId)
          .eq('i_del', 0);
      final offersList = offersSnap as List;
      final totalOffers = offersList.length;
      final publishedOffers =
          offersList.where((o) => (o['sts'] ?? 0) == 2).length;
      final totalViews = offersList.fold<int>(
          0, (sum, o) => sum + ((o['vws'] as int?) ?? 0));
      final totalFavs = offersList.fold<int>(
          0, (sum, o) => sum + ((o['fvs'] as int?) ?? 0));

      // المواعيد
      final offerIds = offersList.map((o) => o['id'] as String).toList();
      int totalAppointments = 0;
      int completedAppointments = 0;
      if (offerIds.isNotEmpty) {
        final apptSnap = await SupabaseService().client
            .from(DbTables.appointments)
            .select('id, sts')
            .inFilter('off_id', offerIds);
        final apptList = apptSnap as List;
        totalAppointments = apptList.length;
        completedAppointments =
            apptList.where((a) => (a['sts'] ?? 0) == 2).length;
      }

      // الصفقات والعمولات
      final dealsSnap = await SupabaseService().client
          .from(DbTables.deals)
          .select('id, sts, com_val, fin_prc')
          .eq('brk_uid', brokerId)
          .eq('i_del', 0);
      final dealsList = dealsSnap as List;
      final totalDeals = dealsList.length;
      final completedDeals =
          dealsList.where((d) => (d['sts'] ?? 0) == 1).length;
      final totalCommission = dealsList
          .where((d) => (d['sts'] ?? 0) == 1)
          .fold<double>(
              0, (sum, d) => sum + (((d['com_val'] ?? 0) as num).toDouble()));
      final totalDealsValue = dealsList
          .where((d) => (d['sts'] ?? 0) == 1)
          .fold<double>(
              0, (sum, d) => sum + (((d['fin_prc'] ?? 0) as num).toDouble()));

      _stats = {
        'totalOffers': totalOffers,
        'publishedOffers': publishedOffers,
        'totalViews': totalViews,
        'totalFavs': totalFavs,
        'totalAppointments': totalAppointments,
        'completedAppointments': completedAppointments,
        'totalDeals': totalDeals,
        'completedDeals': completedDeals,
        'totalCommission': totalCommission,
        'totalDealsValue': totalDealsValue,
      };
    } catch (e) {
      _error = 'فشل جلب الإحصائيات: $e';}
    _isLoading = false;
    notifyListeners();
  }
}
