import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/network/firebase_service.dart';
import '../models/offer_model.dart';
import '../models/user_model.dart';

class AdminProvider with ChangeNotifier {
  final FirebaseFirestore _db = FirebaseService().db;

  // Get all offers pending review (sts == 0)
  Future<List<OfferModel>> getPendingOffers() async {
    QuerySnapshot snapshot = await _db
        .collection('offers')
        .where('sts', isEqualTo: 0)
        .get();
    return snapshot.docs.map((doc) => OfferModel.fromFirestore(doc)).toList();
  }

  // Approve or Reject Offer
  Future<bool> reviewOffer(String offerId, bool approve) async {
    try {
      await _db.collection('offers').doc(offerId).update({
        'sts': approve ? 1 : 3, // 1=Published, 3=Cancelled/Rejected
        'iPub': approve ? 1 : 0,
        'dtU': Timestamp.now(),
      });
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  // User Management: Change Role
  Future<bool> updateUserRole(String uid, int newRole) async {
    try {
      await _db.collection('users').doc(uid).update({'role': newRole});
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  // Payment Management: Activate Package
  Future<bool> activatePackage(String paymentId, String uid) async {
    try {
      // 1. Mark payment as success
      await _db.collection('payments').doc(paymentId).update({'sts': 1});
      // 2. Update user package (simplified logic)
      await _db.collection('users').doc(uid).update({
        'package': 'Premium',
        'points': FieldValue.increment(100),
      });
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }
}
