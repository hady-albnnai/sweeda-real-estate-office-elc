import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/offer_model.dart';
import '../core/network/firebase_service.dart';

class OfferProvider with ChangeNotifier {
  final FirebaseFirestore _db = FirebaseService().db;
  List<OfferModel> _offers = [];
  List<OfferModel> get offers => _offers;

  // Fetch all published offers
  Future<void> fetchOffers() async {
    try {
      QuerySnapshot snapshot = await _db
          .collection('offers')
          .where('iPub', isEqualTo: 1)
          .orderBy('dtC', descending: true)
          .get();

      _offers = snapshot.docs
          .map((doc) => OfferModel.fromFirestore(doc))
          .toList();
      notifyListeners();
    } catch (e) {
      print('Error fetching offers: $e');
    }
  }

  // Get a single offer by ID
  OfferModel? getOfferById(String id) {
    try {
      return _offers.firstWhere((offer) => offer.id == id);
    } catch (e) {
      return null;
    }
  }

  // Add a new offer
  Future<bool> addOffer(OfferModel offer) async {
    try {
      DocumentReference docRef = _db.collection('offers').doc();
      // Create a new model with the generated ID
      OfferModel finalOffer = OfferModel(
        id: docRef.id,
        uId: offer.uId,
        title: offer.title,
        type: offer.type,
        trans: offer.trans,
        cat: offer.cat,
        prc: offer.prc,
        loc: offer.loc,
        desc: offer.desc,
        spec: offer.spec,
        imgs: offer.imgs,
        sts: offer.sts,
        iPub: offer.iPub,
        avl: offer.avl,
        dtC: offer.dtC,
        dtU: offer.dtU,
      );

      await docRef.set(finalOffer.toMap());
      notifyListeners();
      return true;
    } catch (e) {
      print('Error adding offer: $e');
      return false;
    }
  }
}
