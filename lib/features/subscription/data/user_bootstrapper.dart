import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserBootstrapper {
  UserBootstrapper._();

  static final _db = FirebaseFirestore.instance;

  static Future<void> ensureUserDoc(User user) async {
    final ref = _db.collection('users').doc(user.uid);

    await ref.set({
      'uid': user.uid,
      'email': user.email,
      'plan': 'free',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
