import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/request_model.dart';
import '../core/network/firebase_service.dart';

class RequestProvider with ChangeNotifier {
  final FirebaseFirestore _db = FirebaseService().db;
  List<RequestModel> _myRequests = [];
  List<RequestModel> get myRequests => _myRequests;

  Future<bool> addRequest(RequestModel request) async {
    try {
      DocumentReference docRef = _db.collection('requests').doc();
      await docRef.set(request.toMap());
      await fetchMyRequests(request.uId);
      notifyListeners();
      return true;
    } catch (e) {
      print('Error adding request: $e');
      return false;
    }
  }

  Future<void> fetchMyRequests(String uId) async {
    try {
      QuerySnapshot snapshot = await _db
          .collection('requests')
          .where('uId', isEqualTo: uId)
          .orderBy('dtC', descending: true)
          .get();

      _myRequests = snapshot.docs
          .map((doc) => RequestModel.fromFirestore(doc))
          .toList();
      notifyListeners();
    } catch (e) {
      print('Error fetching requests: $e');
    }
  }
}
