import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Servicio mínimo para asegurar que exista el doc:
/// companies/{companyId}
///
/// Esto evita "permission denied" en subcolecciones que dependen de ownerUid.
class CompanyCloudService {
  CompanyCloudService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _db = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  /// Crea/asegura el doc companies/{companyId} con ownerUid.
  ///
  /// - Si no existe: lo crea.
  /// - Si existe: hace merge y garantiza ownerUid correcto.
  Future<void> ensureCompanyDocExists({
    required String companyId,
    String? companyName,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('No hay usuario autenticado.');
    }

    final ref = _db.collection('companies').doc(companyId);

    // Usamos merge para no pisar otros campos si ya existe.
    await ref.set({
      'ownerUid': user.uid,
      if (companyName != null && companyName.trim().isNotEmpty)
        'name': companyName.trim(),
      'updatedAtMs': DateTime.now().millisecondsSinceEpoch,
      'createdAtMs': FieldValue.serverTimestamp(), // no pasa nada si ya existe
    }, SetOptions(merge: true));
  }
}
