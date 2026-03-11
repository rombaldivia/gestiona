import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserBootstrapper {
  static final _db = FirebaseFirestore.instance;

  static Future<void> ensureUserDoc(User user) async {
    final ref = _db.collection('users').doc(user.uid);
    final snap = await ref.get();

    final data = <String, dynamic>{
      'uid': user.uid,
      'email': user.email,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // SOLO en creación
    if (!snap.exists) {
      data['plan'] = 'free';
      data['createdAt'] = FieldValue.serverTimestamp();
    }

    // merge para no pisar plan
    await ref.set(data, SetOptions(merge: true));
  }
}
