class ParsedPhoneForField {
  const ParsedPhoneForField({
    required this.iso2Code,
    required this.nationalNumber,
  });

  final String iso2Code;
  final String nationalNumber;
}

ParsedPhoneForField parsePhoneForField(String? raw) {
  final value = (raw ?? '').trim();

  if (value.isEmpty) {
    return const ParsedPhoneForField(
      iso2Code: 'BO',
      nationalNumber: '',
    );
  }

  final normalized = value.replaceAll(RegExp(r'[^0-9+]'), '');
  final digits = normalized.startsWith('+')
      ? normalized.substring(1)
      : normalized;

  const dialToIso = <String, String>{
    '591': 'BO',
    '51': 'PE',
    '54': 'AR',
    '55': 'BR',
    '56': 'CL',
    '57': 'CO',
    '58': 'VE',
    '593': 'EC',
    '595': 'PY',
    '598': 'UY',
    '1': 'US',
  };

  final codes = dialToIso.keys.toList()
    ..sort((a, b) => b.length.compareTo(a.length));

  for (final code in codes) {
    if (digits.startsWith(code)) {
      return ParsedPhoneForField(
        iso2Code: dialToIso[code]!,
        nationalNumber: digits.substring(code.length),
      );
    }
  }

  return ParsedPhoneForField(
    iso2Code: 'BO',
    nationalNumber: digits,
  );
}
