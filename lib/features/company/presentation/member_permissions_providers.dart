import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/company_member.dart';
import 'company_providers.dart';

final currentMemberProvider = StreamProvider.autoDispose<CompanyMember?>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  final companyState = ref.watch(companyControllerProvider).asData?.value;

  if (user == null || companyState?.companyId == null) {
    return Stream.value(null);
  }

  final uid = user.uid;
  final companyId = companyState!.companyId!;

  return FirebaseFirestore.instance
      .collection('companies')
      .doc(companyId)
      .collection('members')
      .doc(uid)
      .snapshots()
      .map((snap) {
        if (!snap.exists) return null;
        final data = snap.data();
        if (data == null) return null;
        return CompanyMember.fromJson(data);
      });
});
