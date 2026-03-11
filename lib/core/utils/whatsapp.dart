import 'dart:core';

String waSanitizePhone(String raw) {
  // deja solo dígitos
  final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
  return digits;
}

Uri waMeUri({required String message, String? phoneDigits}) {
  final text = Uri.encodeComponent(message);
  final phone = (phoneDigits ?? '').trim();

  if (phone.isEmpty) {
    return Uri.parse('https://wa.me/?text=$text');
  }
  return Uri.parse('https://wa.me/$phone?text=$text');
}
