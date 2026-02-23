import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/quote.dart';

class QuotesCloudService {
  QuotesCloudService({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _col(String companyId) {
    return _db.collection('companies').doc(companyId).collection('quotes');
  }

  Stream<List<Quote>> watchQuotes({required String companyId}) {
    return _col(companyId)
        .orderBy('updatedAtMs', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => Quote.fromJson(d.data())).toList());
  }

  Future<void> upsertQuote({
    required String companyId,
    required String uid,
    required Quote quote,
  }) async {
    final data = quote.toJson();

    // metadata útil para debug/auditoría
    data['updatedByUid'] = uid;

    await _col(companyId).doc(quote.id).set(data, SetOptions(merge: true));
  }

  Future<void> deleteQuote({
    required String companyId,
    required String quoteId,
  }) async {
    await _col(companyId).doc(quoteId).delete();
  }
}
