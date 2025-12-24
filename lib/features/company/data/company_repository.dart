import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/company_summary.dart';

class CompanyRepository {
  CompanyRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  Stream<List<CompanySummary>> watchUserCompanies(String uid) {
    final ref = _db.collection('users').doc(uid).collection('companies');

    return ref.snapshots().map((snap) {
      return snap.docs.map((d) {
        final data = d.data();
        final name = (data['name'] as String?)?.trim();
        return CompanySummary(
          id: d.id,
          name: (name == null || name.isEmpty) ? 'Empresa ${d.id}' : name,
        );
      }).toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    });
  }
}
