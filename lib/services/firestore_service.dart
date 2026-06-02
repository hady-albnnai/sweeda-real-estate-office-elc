import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/firestore_constants.dart';

/// خدمة Firestore العامة — عمليات قراءة/كتابة مشتركة
class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // --- قراءة ---
  Future<DocumentSnapshot> getDoc(String collection, String docId) {
    return _firestore.collection(collection).doc(docId).get();
  }

  Future<QuerySnapshot> queryDocs(
    String collection, {
    List<WhereClause>? where,
    String? orderByField,
    bool descending = true,
    int? limit,
  }) {
    Query query = _firestore.collection(collection);

    if (where != null) {
      for (final w in where) {
        query = query.where(w.field, isEqualTo: w.value);
      }
    }

    if (orderByField != null) {
      query = query.orderBy(orderByField, descending: descending);
    }

    if (limit != null) {
      query = query.limit(limit);
    }

    return query.get();
  }

  // --- كتابة ---
  Future<void> setDoc(String collection, String docId, Map<String, dynamic> data) {
    return _firestore.collection(collection).doc(docId).set(data);
  }

  Future<void> updateDoc(String collection, String docId, Map<String, dynamic> data) {
    return _firestore.collection(collection).doc(docId).update(data);
  }

  Future<DocumentReference> addDoc(String collection, Map<String, dynamic> data) {
    return _firestore.collection(collection).add(data);
  }

  // --- حذف ناعم (Soft Delete) ---
  Future<void> softDelete(String collection, String docId) {
    return _firestore.collection(collection).doc(docId).update({'iDel': 1});
  }

  // --- زيادة عداد ---
  Future<void> incrementCounter(String collection, String docId, String field, {int amount = 1}) {
    return _firestore.collection(collection).doc(docId).update({
      field: FieldValue.increment(amount),
    });
  }
}

/// فئة مساعدة لـ where clauses
class WhereClause {
  final String field;
  final dynamic value;
  WhereClause({required this.field, required this.value});
}