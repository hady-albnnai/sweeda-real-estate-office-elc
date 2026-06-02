import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/firestore_constants.dart';
import '../models/offer_model.dart';

/// مزود العروض — offers
class OfferProvider extends ChangeNotifier {
  List<OfferModel> _offers = [];
  OfferModel? _selectedOffer;
  bool _isLoading = false;
  String? _error;
  String? _lastDocId;

  List<OfferModel> get offers => _offers;
  OfferModel? get selectedOffer => _selectedOffer;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// جلب العروض المنشورة (للمستخدمين والزوار)
  Future<void> loadPublishedOffers({
    int? type,      // 0=عقار, 1=سيارة
    int? trans,     // 0=بيع, 1=إيجار
    int? category,
    num? minPrice,
    num? maxPrice,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      var query = FirebaseFirestore.instance
          .collection(FirestoreCollections.offers)
          .where('iPub', isEqualTo: 1)
          .where('iDel', isEqualTo: 0)
          .orderBy('tsPub', descending: true)
          .limit(20);

      if (type != null) query = query.where('typ', isEqualTo: type);
      if (trans != null) query = query.where('trx', isEqualTo: trans);
      if (category != null) query = query.where('cat', isEqualTo: category);

      final snapshot = await query.get();
      _offers = snapshot.docs
          .map((doc) => OfferModel.fromFirestore(doc))
          .toList();

      if (snapshot.docs.isNotEmpty) {
        _lastDocId = snapshot.docs.last.id;
      }
    } catch (e) {
      _error = 'فشل تحميل العروض: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  /// جلب عرض حسب ID
  Future<void> loadOfferById(String offerId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final doc = await FirebaseFirestore.instance
          .collection(FirestoreCollections.offers)
          .doc(offerId)
          .get();

      if (doc.exists) {
        _selectedOffer = OfferModel.fromFirestore(doc);
      }
    } catch (e) {
      _error = 'فشل تحميل العرض: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  /// تحديث عدد المشاهدات
  Future<void> incrementViews(String offerId) async {
    await FirebaseFirestore.instance
        .collection(FirestoreCollections.offers)
        .doc(offerId)
        .update({'vws': FieldValue.increment(1)});
  }
}