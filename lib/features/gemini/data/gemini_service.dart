import 'dart:convert';
import 'package:http/http.dart' as http;

import '../domain/chat_message.dart';

class GeminiService {
  static const _model = 'gemini-flash-latest';
  static const _url =
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent';

  Future<String> send({
    required String apiKey,
    required String systemPrompt,
    required List<ChatMessage> history,
    required String userMessage,
  }) async {
    final contents = <Map<String, dynamic>>[];

    // ✅ Si systemInstruction te da problemas, lo metemos como primer mensaje "user"
    if (systemPrompt.trim().isNotEmpty) {
      contents.add({
        'role': 'user',
        'parts': [
          {'text': 'INSTRUCCIONES DEL SISTEMA:\n$systemPrompt'}
        ],
      });
    }

    for (final msg in history) {
      if (msg.isLoading) continue;
      contents.add({
        'role': msg.isUser ? 'user' : 'model',
        'parts': [
          {'text': msg.text}
        ],
      });
    }

    contents.add({
      'role': 'user',
      'parts': [
        {'text': userMessage}
      ],
    });

    final body = jsonEncode({
      'contents': contents,
      'generationConfig': {
        'temperature': 0.7,
        'maxOutputTokens': 512,
      },
    });

    final res = await http.post(
      Uri.parse(_url),
      headers: {
        'Content-Type': 'application/json',
        'X-goog-api-key': apiKey.trim(),
      },
      body: body,
    );

    if (res.statusCode == 200) {
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      return (json['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? '')
          .toString();
    }

    String googleMsg = '';
    try {
      final err = jsonDecode(res.body);
      googleMsg = err['error']?['message']?.toString() ?? res.body;
    } catch (_) {
      googleMsg = res.body;
    }

    throw GeminiException('Error ${res.statusCode}: $googleMsg');
  }

  Future<void> validateKey(String apiKey) async {
    await send(
      apiKey: apiKey,
      systemPrompt: '',
      history: const [],
      userMessage: 'Hola',
    );
  }
}

class GeminiException implements Exception {
  const GeminiException(this.message);
  final String message;
  @override
  String toString() => message;
}
