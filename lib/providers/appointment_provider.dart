import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/appointment_model.dart';
import '../core/network/firebase_service.dart';

class AppointmentProvider with ChangeNotifier {
  final FirebaseFirestore _db = FirebaseService().db;
  List<AppointmentModel> _myAppointments = [];
  List<AppointmentModel> get myAppointments => _myAppointments;

  // Book a new appointment
  Future<bool> bookAppointment({
    required String uId,
    required String oId,
    required String day,
    required String time,
  }) async {
    try {
      DocumentReference docRef = _db.collection('appointments').doc();
      AppointmentModel appointment = AppointmentModel(
        id: docRef.id,
        uId: uId,
        oId: oId,
        day: day,
        time: time,
        sts: 0, // Pending
        fbkOwn: 0,
        fbkReq: 0,
        dtC: DateTime.now(),
        dtU: DateTime.now(),
      );

      await docRef.set(appointment.toMap());
      await fetchMyAppointments(uId);
      notifyListeners();
      return true;
    } catch (e) {
      print('Error booking appointment: $e');
      return false;
    }
  }

  // Fetch appointments for a specific user
  Future<void> fetchMyAppointments(String uId) async {
    try {
      QuerySnapshot snapshot = await _db
          .collection('appointments')
          .where('uId', isEqualTo: uId)
          .orderBy('dtC', descending: true)
          .get();

      _myAppointments = snapshot.docs
          .map((doc) => AppointmentModel.fromFirestore(doc))
          .toList();
      notifyListeners();
    } catch (e) {
      print('Error fetching appointments: $e');
    }
  }

  // Update appointment status (for owner/admin)
  Future<bool> updateStatus(String appointmentId, int newStatus, int feedback) async {
    try {
      await _db.collection('appointments').doc(appointmentId).update({
        'sts': newStatus,
        'fbkOwn': feedback,
        'dtU': Timestamp.now(),
      });
      notifyListeners();
      return true;
    } catch (e) {
      print('Error updating status: $e');
      return false;
    }
  }
}
