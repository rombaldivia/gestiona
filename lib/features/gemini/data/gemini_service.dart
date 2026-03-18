import 'dart:convert';
import 'package:http/http.dart' as http;
import '../domain/chat_message.dart';

class GeminiService {
  static const _models = [
    'gemini-2.5-flash-preview-05-20',
    'gemini-2.5-flash',
    'gemini-2.0-flash',
    'gemini-2.0-flash-lite',
  ];

  static String _url(String model) =>
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent';

  Future<String> send({
    required String            apiKey,
    required String            systemPrompt,
    required List<ChatMessage> history,
    required String            userMessage,
  }) async {
    for (final model in _models) {
      try {
        return await _sendWithModel(model: model, apiKey: apiKey,
            systemPrompt: systemPrompt, history: history, userMessage: userMessage);
      } on GeminiException catch (e) {
        if (e.isQuotaError || e.isUnavailable) continue;
        rethrow;
      }
    }
    throw const GeminiException('Todos los modelos están ocupados. Intenta en unos minutos.');
  }

  Future<String> _sendWithModel({
    required String model, required String apiKey,
    required String systemPrompt, required List<ChatMessage> history,
    required String userMessage,
  }) async {
    final contents = <Map<String, dynamic>>[];
    if (systemPrompt.trim().isNotEmpty) {
      contents.add({'role': 'user', 'parts': [{'text': 'INSTRUCCIONES DEL SISTEMA:\n$systemPrompt'}]});
    }
    for (final msg in history) {
      if (msg.isLoading) continue;
      contents.add({'role': msg.isUser ? 'user' : 'model', 'parts': [{'text': msg.text}]});
    }
    contents.add({'role': 'user', 'parts': [{'text': userMessage}]});

    final res = await http.post(
      Uri.parse(_url(model)),
      headers: {'Content-Type': 'application/json', 'X-goog-api-key': apiKey.trim()},
      body: jsonEncode({'contents': contents, 'generationConfig': {'temperature': 0.7, 'maxOutputTokens': 8192}}),
    );

    if (res.statusCode == 200) {
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      return (json['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? '').toString();
    }
    String msg = '';
    try { msg = (jsonDecode(res.body)['error']?['message'] ?? res.body).toString(); } catch (_) { msg = res.body; }
    throw GeminiException('Error ${res.statusCode} ($model): $msg');
  }

  Future<void> validateKey(String apiKey) async =>
      send(apiKey: apiKey, systemPrompt: '', history: const [], userMessage: 'Hola');
}

class GeminiException implements Exception {
  const GeminiException(this.message);
  final String message;
  bool get isQuotaError => message.contains('429') || message.contains('quota') || message.contains('RESOURCE_EXHAUSTED');
  bool get isUnavailable => message.contains('503') || message.contains('not found') || message.contains('not supported');
  @override
  String toString() => message;
}
