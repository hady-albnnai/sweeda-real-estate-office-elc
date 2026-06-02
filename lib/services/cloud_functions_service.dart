import 'package:cloud_functions/cloud_functions.dart';

/// خدمة Cloud Functions — استدعاء الدوال من العميل
class CloudFunctionsService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// استدعاء دالة بنج
  Future<dynamic> callFunction(String name, {Map<String, dynamic>? params}) async {
    try {
      final result = await _functions.httpsCallable(name).call(params);
      return result.data;
    } on FirebaseFunctionsException catch (e) {
      throw Exception('خطأ في استدعاء الدالة $name: ${e.message}');
    }
  }

  /// إنشاء عرض جديد
  Future<void> createOffer(Map<String, dynamic> offerData) async {
    await callFunction('onNewOffer', params: offerData);
  }

  /// حجز موعد
  Future<void> createAppointment(Map<String, dynamic> appointmentData) async {
    await callFunction('onAppointmentCreated', params: appointmentData);
  }

  /// تبليغ
  Future<void> reportUser(Map<String, dynamic> reportData) async {
    await callFunction('onUserReport', params: reportData);
  }
}