import 'package:flutter/foundation.dart';
import '../models/appointment_model.dart';
import '../models/offer_model.dart';
import '../models/deal_model.dart';
import '../core/network/supabase_service.dart';

/// Provider خاص بلوحة الوسيط/السمسار (دور role = 1)
/// يجمع كل عمليات السمسار: المواعيد، العروض، الصفقات، الإحصائيات
class BrokerProvider with ChangeNotifier {
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

  Future<void> fetchBrokerAppointments(String brokerId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _appointments = await getBrokerAppointments(brokerId);
    } catch (e) {
      _error = 'فشل جلب المواعيد: $e';
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<List<AppointmentModel>> getBrokerAppointments(String brokerId) async {
    try {
      final response = await SupabaseService().client.functions.invoke(
        'user-appointments',
        body: {
          'action': 'list_broker_appointments',
          'user_uid': brokerId,
        },
      );
      final data = response.data;
      if (data == null || data['success'] != true) throw Exception(data?['error'] ?? 'Unknown error');
      final list = data['appointments'] as List;
      return list
          .map((d) => AppointmentModel.fromSupabase(
              Map<String, dynamic>.from(d), d['id'] as String))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<bool> handleAppointment(String brokerUid, String apptId, int feedback) async {
    try {
      final action = feedback == 1
          ? 'confirm'
          : feedback == 2
              ? 'reject'
              : 'pending';
      if (action == 'pending') return false;
      await SupabaseService().client.rpc(
        'broker_handle_appointment_internal',
        params: {
          'p_broker_uid': brokerUid,
          'p_appointment_id': apptId,
          'p_action': action,
        },
      );
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> completeAppointment(String brokerUid, String apptId) async {
    try {
      await SupabaseService().client.rpc(
        'broker_handle_appointment_internal',
        params: {
          'p_broker_uid': brokerUid,
          'p_appointment_id': apptId,
          'p_action': 'complete',
        },
      );
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> fetchBrokerOffers(String brokerId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final response = await SupabaseService().client.functions.invoke(
        'user-offers',
        body: {
          'action': 'broker_offers',
          'user_uid': brokerId,
        },
      );
      final data = response.data;
      if (data == null || data['success'] != true) throw Exception('Error');
      _offers = (data['offers'] as List)
          .map((d) =>
              OfferModel.fromSupabase(Map<String, dynamic>.from(d), d['id'] as String))
          .toList();
    } catch (e) {
      _error = 'فشل جلب العروض: $e';
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchBrokerDeals(String brokerId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final response = await SupabaseService().client.functions.invoke(
        'user-offers',
        body: {
          'action': 'broker_deals',
          'user_uid': brokerId,
        },
      );
      final data = response.data;
      if (data == null || data['success'] != true) throw Exception('Error');
      _deals = (data['deals'] as List)
          .map((d) =>
              DealModel.fromSupabase(Map<String, dynamic>.from(d), d['id'] as String))
          .toList();
    } catch (e) {
      _error = 'فشل جلب الصفقات: $e';
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchBrokerStats(String brokerId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final offersRes = await SupabaseService().client.functions.invoke(
        'user-offers',
        body: {
          'action': 'broker_offers',
          'user_uid': brokerId,
        },
      );
      final offersList = offersRes.data != null && offersRes.data['success'] == true 
          ? offersRes.data['offers'] as List 
          : [];
      final totalOffers = offersList.length;
      final publishedOffers =
          offersList.where((o) => (o['sts'] ?? 0) == 2).length;
      final totalViews = offersList.fold<int>(
          0, (sum, o) => sum + ((o['vws'] as int?) ?? 0));
      final totalFavs = offersList.fold<int>(
          0, (sum, o) => sum + ((o['fvs'] as int?) ?? 0));

      final apptRes = await SupabaseService().client.functions.invoke(
        'user-appointments',
        body: {
          'action': 'list_broker_appointments',
          'user_uid': brokerId,
        },
      );
      final apptList = apptRes.data != null && apptRes.data['success'] == true 
          ? apptRes.data['appointments'] as List 
          : [];
      final totalAppointments = apptList.length;
      final completedAppointments =
          apptList.where((a) => (a['sts'] ?? 0) == 2).length;

      final dealsRes = await SupabaseService().client.functions.invoke(
        'user-offers',
        body: {
          'action': 'broker_deals',
          'user_uid': brokerId,
        },
      );
      final dealsList = dealsRes.data != null && dealsRes.data['success'] == true 
          ? dealsRes.data['deals'] as List 
          : [];
      final totalDeals = dealsList.length;
      final completedDeals =
          dealsList.where((d) => (d['sts'] ?? 0) == 1).length;
      final totalCommission = dealsList
          .where((d) => (d['sts'] ?? 0) == 1)
          .fold<double>(0,
              (sum, d) => sum + (((d['com_val'] ?? 0) as num).toDouble()));
      final totalDealsValue = dealsList
          .where((d) => (d['sts'] ?? 0) == 1)
          .fold<double>(0,
              (sum, d) => sum + (((d['fin_prc'] ?? 0) as num).toDouble()));

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
      _error = 'فشل جلب الإحصائيات: $e';
    }
    _isLoading = false;
    notifyListeners();
  }
}
