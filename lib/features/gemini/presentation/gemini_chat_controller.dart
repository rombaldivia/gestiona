import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../inventory/presentation/inventory_providers.dart';
import '../../quotes/presentation/quotes_controller.dart';
import '../../work_orders/presentation/work_orders_controller.dart';
import '../data/gemini_key_store.dart';
import '../data/gemini_service.dart';
import '../domain/chat_message.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final geminiKeyProvider = FutureProvider<String?>((ref) async {
  return GeminiKeyStore().load();
});

final geminiChatProvider =
    AsyncNotifierProvider<GeminiChatController, GeminiChatState>(
  GeminiChatController.new,
);

// ── State ─────────────────────────────────────────────────────────────────────

class GeminiChatState {
  const GeminiChatState({
    this.messages  = const [],
    this.apiKey,
    this.isSending = false,
    this.error,
  });

  final List<ChatMessage> messages;
  final String?           apiKey;
  final bool              isSending;
  final String?           error;

  bool get hasKey => apiKey != null && apiKey!.isNotEmpty;

  GeminiChatState copyWith({
    List<ChatMessage>? messages,
    String?            apiKey,
    bool?              isSending,
    String?            error,
    bool               clearError = false,
  }) =>
      GeminiChatState(
        messages:  messages  ?? this.messages,
        apiKey:    apiKey    ?? this.apiKey,
        isSending: isSending ?? this.isSending,
        error:     clearError ? null : (error ?? this.error),
      );
}

// ── Controller ────────────────────────────────────────────────────────────────

class GeminiChatController extends AsyncNotifier<GeminiChatState> {
  final _service  = GeminiService();
  final _keyStore = GeminiKeyStore();

  @override
  Future<GeminiChatState> build() async {
    final key = await _keyStore.load();
    return GeminiChatState(apiKey: key);
  }

  // ── API Key ──────────────────────────────────────────────────────────────────

  Future<void> saveKey(String key) async {
    await _keyStore.save(key);
    state = AsyncData(state.value!.copyWith(apiKey: key, clearError: true));
  }

  Future<void> clearKey() async {
    await _keyStore.clear();
    state = AsyncData(state.value!.copyWith(
      apiKey:   '',
      messages: [],
    ));
  }

  Future<String?> validateKey(String key) async {
    try {
      await _service.validateKey(key);
      return null; // null = éxito
    } on GeminiException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  // ── Chat ─────────────────────────────────────────────────────────────────────

  Future<void> send(String userText) async {
    final current = state.value;
    if (current == null || !current.hasKey || userText.trim().isEmpty) return;

    final userMsg = ChatMessage(
      role:        MessageRole.user,
      text:        userText.trim(),
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
    );

    final withUser = [...current.messages, userMsg, ChatMessage.loading()];
    state = AsyncData(current.copyWith(messages: withUser, isSending: true, clearError: true));

    try {
      final systemPrompt = _buildSystemPrompt();
      final response     = await _service.send(
        apiKey:       current.apiKey!,
        systemPrompt: systemPrompt,
        history:      current.messages,
        userMessage:  userText.trim(),
      );

      final modelMsg = ChatMessage(
        role:        MessageRole.model,
        text:        response,
        createdAtMs: DateTime.now().millisecondsSinceEpoch,
      );

      // Reemplaza el mensaje de loading con la respuesta real
      final finalMessages = [
        ...withUser.where((m) => !m.isLoading),
        modelMsg,
      ];

      state = AsyncData(current.copyWith(
        messages:  finalMessages,
        isSending: false,
      ));
    } catch (e) {
      // Quita el mensaje de loading y muestra el error
      final withoutLoading = withUser.where((m) => !m.isLoading).toList();
      state = AsyncData(current.copyWith(
        messages:  withoutLoading,
        isSending: false,
        error:     e.toString(),
      ));
    }
  }

  void clearHistory() {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(messages: [], clearError: true));
  }

  // ── Contexto del negocio ──────────────────────────────────────────────────────

  String _buildSystemPrompt() {
    final quotes   = ref.read(quotesControllerProvider).value?.quotes ?? [];
    final items    = ref.read(inventoryItemsProvider);
    final orders   = ref.read(workOrdersControllerProvider).value?.orders ?? [];

    final buf = StringBuffer();
    buf.writeln('Eres el asistente de negocios de Gestiona, una app para PyMEs bolivianas.');
    buf.writeln('Responde siempre en español, de forma clara y concisa.');
    buf.writeln('Usa el símbolo Bs para bolivianos.');
    buf.writeln();

    // Cotizaciones
    buf.writeln('=== COTIZACIONES (${quotes.length} total) ===');
    for (final q in quotes.take(30)) {
      final fecha = _fmtMs(q.updatedAtMs);
      final total = 'Bs ${q.totalBob.toStringAsFixed(2)}';
      buf.writeln('• COT #${q.sequence}-${q.year} | ${q.customerName ?? 'Sin cliente'} | ${q.status.label} | $total | $fecha');
      if (q.title != null) buf.writeln('  Proyecto: ${q.title}');
    }
    if (quotes.isEmpty) buf.writeln('Sin cotizaciones todavía.');
    buf.writeln();

    // Inventario
    buf.writeln('=== INVENTARIO (${items.length} items) ===');
    for (final it in items.take(30)) {
      final precio = it.salePrice != null ? 'Bs ${it.salePrice!.toStringAsFixed(2)}' : 'sin precio';
      buf.writeln('• ${it.name} | stock: ${it.stock} ${it.unit ?? ''} | $precio');
    }
    if (items.isEmpty) buf.writeln('Sin items en inventario.');
    buf.writeln();

    // Órdenes de trabajo
    buf.writeln('=== ÓRDENES DE TRABAJO (${orders.length} total) ===');
    for (final o in orders.take(20)) {
      final prog = o.steps.isEmpty ? '' : '${o.steps.where((s) => s.completed).length}/${o.steps.length} etapas';
      buf.writeln('• OT #${o.sequence}-${o.year} | ${o.customerName ?? 'Sin cliente'} | ${o.status.label} | $prog');
      if (o.quoteTitle != null) buf.writeln('  Proyecto: ${o.quoteTitle}');
    }
    if (orders.isEmpty) buf.writeln('Sin órdenes de trabajo todavía.');

    return buf.toString();
  }

  String _fmtMs(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }
}
