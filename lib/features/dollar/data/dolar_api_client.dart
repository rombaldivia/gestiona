import 'dart:convert';
import 'dart:io';

import '../domain/dollar_rate.dart';

class DolarApiClient {
  static const _url = 'https://bo.dolarapi.com/v1/dolares/binance';

  Future<DollarRate> fetchBinanceUsdBob() async {
    final client = HttpClient();
    try {
      final req = await client.getUrl(Uri.parse(_url));
      req.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final res = await req.close();

      final body = await res.transform(utf8.decoder).join();
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw HttpException('HTTP ${res.statusCode}: $body');
      }

      final jsonObj = json.decode(body);
      if (jsonObj is! Map<String, dynamic>) {
        throw const FormatException('Respuesta inesperada: no es JSON object');
      }

      final ventaRaw = jsonObj['venta'];
      final fechaRaw = jsonObj['fechaActualizacion'];

      final venta = (ventaRaw is num) ? ventaRaw.toDouble() : double.tryParse('$ventaRaw');
      if (venta == null) throw const FormatException('Campo "venta" inválido');

      final fecha = (fechaRaw is String && fechaRaw.isNotEmpty) ? fechaRaw : DateTime.now().toUtc().toIso8601String();

      return DollarRate(venta: venta, updatedAtIso: fecha, source: 'binance');
    } finally {
      client.close(force: true);
    }
  }
}
