import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserBootstrapper {
  UserBootstrapper({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  Future<void> ensureUserDoc(User user) async {
    if (user.isAnonymous) return;

    final ref = _db.collection('users').doc(user.uid);
    final snap = await ref.get();

    if (snap.exists) {
      await ref.set({
        'uid': user.uid,
        if ((user.email ?? '').trim().isNotEmpty) 'email': user.email!.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return;
    }

    await ref.set({
      'uid': user.uid,
      if ((user.email ?? '').trim().isNotEmpty) 'email': user.email!.trim(),
      'plan': 'free',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
