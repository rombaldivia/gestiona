import 'dart:convert';
import 'package:http/http.dart' as http;

class UsdRateService {
  static const _url = 'https://bo.dolarapi.com/v1/dolares/binance';

  static Future<double> fetchBinanceBobPerUsd() async {
    final resp = await http.get(Uri.parse(_url));
    if (resp.statusCode != 200) {
      throw Exception('HTTP ${resp.statusCode}');
    }
    final m = jsonDecode(resp.body) as Map<String, dynamic>;

    double? d(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString().replaceAll(',', '.'));
    }

    final venta = d(m['venta']);
    final promedio = d(m['promedio']);
    final compra = d(m['compra']);
    final rate = venta ?? promedio ?? compra;

    if (rate == null || rate <= 0) {
      throw Exception('Respuesta inválida dolarapi');
    }
    return rate;
  }
}
