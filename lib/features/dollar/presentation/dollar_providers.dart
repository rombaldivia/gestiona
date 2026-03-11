import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/dollar_repository.dart';

final dollarRepositoryProvider = Provider<DollarRepository>((ref) {
  return DollarRepository();
});

/// Estado de protección dólar por UID (vive en users/{uid}.dollarProtection)
final dollarProtectionProvider =
    StreamProvider.family<DollarProtectionState, String>((ref, uid) {
      final repo = ref.watch(dollarRepositoryProvider);
      return repo.watchState(uid);
    });
