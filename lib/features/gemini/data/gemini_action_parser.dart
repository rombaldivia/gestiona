import 'dart:convert';
import '../domain/gemini_action.dart';

/// Parsea la respuesta de Gemini buscando un bloque JSON de acción.
/// El modelo devuelve texto normal + opcionalmente un bloque:
///   ACTION_JSON: { "action": "...", "params": {...}, "description": "..." }
class GeminiActionParser {
  static const _marker = 'ACTION_JSON:';

  /// Retorna (textoVisible, acción|null)
  static (String, GeminiAction?) parse(String raw) {
    final idx = raw.indexOf(_marker);
    if (idx == -1) return (raw.trim(), null);

    final textPart   = raw.substring(0, idx).trim();
    final jsonPart   = raw.substring(idx + _marker.length).trim();

    try {
      // Extraer el JSON entre { }
      final start = jsonPart.indexOf('{');
      final end   = jsonPart.lastIndexOf('}');
      if (start == -1 || end == -1) return (textPart, null);

      final map = jsonDecode(jsonPart.substring(start, end + 1)) as Map<String, dynamic>;
      final action = _fromMap(map);
      return (textPart, action);
    } catch (_) {
      return (textPart, null);
    }
  }

  static GeminiAction? _fromMap(Map<String, dynamic> m) {
    final type   = m['action']      as String? ?? '';
    final params = m['params']      as Map<String, dynamic>? ?? {};
    final desc   = m['description'] as String? ?? '';

    switch (type) {
      case 'create_quote':
        return GeminiAction(type: GeminiActionType.createQuote,      params: params, description: desc);
      case 'create_work_order':
        return GeminiAction(type: GeminiActionType.createWorkOrder,   params: params, description: desc);
      case 'add_inventory_item':
        return GeminiAction(type: GeminiActionType.addInventoryItem,  params: params, description: desc);
      case 'change_quote_status':
        return GeminiAction(type: GeminiActionType.changeQuoteStatus, params: params, description: desc);
      default:
        return null;
    }
  }
}
