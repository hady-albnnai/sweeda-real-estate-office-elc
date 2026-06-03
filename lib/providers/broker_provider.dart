import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/network/firebase_service.dart';
import '../models/appointment_model.dart';

class BrokerProvider with ChangeNotifier {
  final FirebaseFirestore _db = FirebaseService().db;

  // Fetch appointments for a broker's offers
  Future<List<AppointmentModel>> getBrokerAppointments(String brokerId) async {
    try {
      // Logic: Find all offers owned by this broker, then find appointments for those offers
      QuerySnapshot offersSnap = await _db
          .collection('offers')
          .where('uId', isEqualTo: brokerId)
          .get();
      
      List<String> offerIds = offersSnap.docs.map((doc) => doc.id).toList();
      
      if (offerIds.isEmpty) return [];

      QuerySnapshot appSnap = await _db
          .collection('appointments')
          .where('oId', whereIn: offerIds)
          .get();

      return appSnap.docs.map((doc) => AppointmentModel.fromFirestore(doc)).toList();
    } catch (e) {
      print('Broker appt error: $e');
      return [];
    }
  }

  // Handle appointment request
  Future<bool> handleAppointment(String apptId, int feedback) async {
    try {
      await _db.collection('appointments').doc(apptId).update({
        'fbkOwn': feedback, // 1=Accept, 2=Reject, 3=Deadline
        'sts': feedback == 1 ? 1 : (feedback == 2 ? 3 : 0),
        'dtU': Timestamp.now(),
      });
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }
}
