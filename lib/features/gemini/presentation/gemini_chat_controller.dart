import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../inventory/domain/inventory_item.dart';
import '../../inventory/presentation/inventory_providers.dart';
import '../../quotes/domain/quote_line.dart';
import '../../quotes/domain/quote_status.dart';
import '../../quotes/presentation/quotes_controller.dart';
import '../../subscription/presentation/entitlements_providers.dart';
import '../../work_orders/presentation/work_orders_controller.dart';
import '../data/gemini_action_parser.dart';
import '../data/gemini_key_store.dart';
import '../data/gemini_service.dart';
import '../domain/chat_message.dart';
import '../domain/gemini_action.dart';

final geminiKeyProvider = FutureProvider<String?>((ref) async => GeminiKeyStore().load());

final geminiChatProvider =
    AsyncNotifierProvider<GeminiChatController, GeminiChatState>(GeminiChatController.new);

class GeminiChatState {
  const GeminiChatState({
    this.messages = const [], this.apiKey, this.isSending = false,
    this.error, this.pendingAction,
  });
  final List<ChatMessage> messages;
  final String?           apiKey;
  final bool              isSending;
  final String?           error;
  final GeminiAction?     pendingAction;
  bool get hasKey => apiKey != null && apiKey!.isNotEmpty;

  GeminiChatState copyWith({
    List<ChatMessage>? messages, String? apiKey, bool? isSending,
    String? error, GeminiAction? pendingAction,
    bool clearError = false, bool clearPendingAction = false,
  }) => GeminiChatState(
    messages:      messages      ?? this.messages,
    apiKey:        apiKey        ?? this.apiKey,
    isSending:     isSending     ?? this.isSending,
    error:         clearError    ? null : (error ?? this.error),
    pendingAction: clearPendingAction ? null : (pendingAction ?? this.pendingAction),
  );
}

class GeminiChatController extends AsyncNotifier<GeminiChatState> {
  final _service  = GeminiService();
  final _keyStore = GeminiKeyStore();

  @override
  Future<GeminiChatState> build() async => GeminiChatState(apiKey: await _keyStore.load());

  Future<void> saveKey(String key) async {
    await _keyStore.save(key);
    state = AsyncData(state.value!.copyWith(apiKey: key, clearError: true));
  }

  Future<void> clearKey() async {
    await _keyStore.clear();
    state = AsyncData(state.value!.copyWith(apiKey: '', messages: []));
  }

  Future<String?> validateKey(String key) async {
    try { await _service.validateKey(key); return null; }
    on GeminiException catch (e) { return e.message; }
    catch (e) { return e.toString(); }
  }

  Future<void> send(String userText) async {
    final current = state.value;
    if (current == null || !current.hasKey || userText.trim().isEmpty) return;

    final userMsg  = ChatMessage(role: MessageRole.user, text: userText.trim(), createdAtMs: DateTime.now().millisecondsSinceEpoch);
    final withUser = [...current.messages, userMsg, ChatMessage.loading()];
    state = AsyncData(current.copyWith(messages: withUser, isSending: true, clearError: true, clearPendingAction: true));

    try {
      final raw = await _service.send(
        apiKey: current.apiKey!, systemPrompt: _buildSystemPrompt(),
        history: current.messages, userMessage: userText.trim(),
      );
      final (visibleText, action) = GeminiActionParser.parse(raw);
      final modelMsg = ChatMessage(role: MessageRole.model, text: visibleText, createdAtMs: DateTime.now().millisecondsSinceEpoch);
      state = AsyncData(current.copyWith(
        messages: [...withUser.where((m) => !m.isLoading), modelMsg],
        isSending: false, pendingAction: action,
      ));
    } catch (e) {
      state = AsyncData(current.copyWith(
        messages: withUser.where((m) => !m.isLoading).toList(),
        isSending: false, error: e.toString(),
      ));
    }
  }

  Future<String> executeAction(GeminiAction action) async {
    try {
      switch (action.type) {
        case GeminiActionType.createQuote:       return await _createQuote(action.params);
        case GeminiActionType.createWorkOrder:   return await _createWorkOrder(action.params);
        case GeminiActionType.addInventoryItem:  return await _addInventoryItem(action.params);
        case GeminiActionType.changeQuoteStatus: return await _changeQuoteStatus(action.params);
      }
    } catch (e) { return 'Error: $e'; }
  }

  void clearPendingAction() => state = AsyncData(state.value!.copyWith(clearPendingAction: true));

  void clearHistory() {
    final cur = state.value;
    if (cur == null) return;
    state = AsyncData(cur.copyWith(messages: [], clearError: true, clearPendingAction: true));
  }

  Future<String> _createQuote(Map<String, dynamic> p) async {
    final ctrl  = ref.read(quotesControllerProvider.notifier);
    final draft = await ctrl.newDraft();
    final lines = (p['lines'] as List? ?? []).map<QuoteLine>((l) {
      final m = l as Map<String, dynamic>;
      return QuoteLine(
        lineId: DateTime.now().microsecondsSinceEpoch.toString(), kind: 'manual',
        nameSnapshot: m['name']?.toString() ?? 'Item',
        qty: (m['qty'] as num?)?.toDouble() ?? 1,
        unitPriceBobSnapshot: (m['unitPriceBob'] as num?)?.toDouble() ?? 0,
        unitSnapshot: m['unit']?.toString(),
      );
    }).toList();
    final quote = draft.copyWith(
      customerName: p['customerName']?.toString(),
      title: p['title']?.toString(),
      lines: lines.isNotEmpty ? lines : draft.lines,
    );
    await ctrl.upsert(quote);
    return 'COT #${quote.sequence}-${quote.year} creada ✅';
  }

  Future<String> _createWorkOrder(Map<String, dynamic> p) async {
    final ctrl  = ref.read(workOrdersControllerProvider.notifier);
    final order = ctrl.newOrder(customerName: p['customerName']?.toString(), customerPhone: p['customerPhone']?.toString());
    await ctrl.upsert(order);
    return 'OT #${order.sequence}-${order.year} creada ✅';
  }

  Future<String> _addInventoryItem(Map<String, dynamic> p) async {
    final ctrl = ref.read(inventoryControllerProvider.notifier);
    final now  = DateTime.now().millisecondsSinceEpoch;
    final name = p['name']?.toString() ?? 'Item';
    final item = InventoryItem(
      id: now.toRadixString(36), name: name,
      sku: p['sku']?.toString(), unit: p['unit']?.toString(),
      stock: (p['stock'] as num?) ?? 0,
      salePrice: p['salePrice'] as num?, cost: p['costPrice'] as num?,
      updatedAtMs: now,
    );
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final ent = await ref.read(entitlementsProvider(uid).future);
    await ctrl.upsertItem(item: item, ent: ent);
    return 'Item "$name" agregado ✅';
  }

  Future<String> _changeQuoteStatus(Map<String, dynamic> p) async {
    final ctrl      = ref.read(quotesControllerProvider.notifier);
    final quotes    = ref.read(quotesControllerProvider).value?.quotes ?? [];
    final sequence  = (p['sequence'] as num?)?.toInt();
    final newStatus = QuoteStatus.fromString(p['status']?.toString());
    if (sequence == null) return 'Falta el número de cotización.';
    final quote = quotes.where((q) => q.sequence == sequence).firstOrNull;
    if (quote == null) return 'No encontré COT #$sequence.';
    await ctrl.upsert(quote.copyWith(status: newStatus));
    return 'COT #$sequence → "${newStatus.label}" ✅';
  }

  String _buildSystemPrompt() {
    final quotes = ref.read(quotesControllerProvider).value?.quotes ?? [];
    final items  = ref.read(inventoryItemsProvider);
    final orders = ref.read(workOrdersControllerProvider).value?.orders ?? [];
    final buf = StringBuffer();
    buf.writeln('Eres el asistente de Gestiona, app para PyMEs bolivianas. Responde en español. Usa Bs.');
    buf.writeln();
    buf.writeln('Puedes ejecutar acciones. Si el usuario pide crear/modificar algo, responde con texto Y agrega al final:');
    buf.writeln('ACTION_JSON: { "action": "ACCION", "params": { ... }, "description": "texto corto" }');
    buf.writeln();
    buf.writeln('Acciones: create_quote(customerName,title,lines[{name,qty,unitPriceBob,unit}]) | create_work_order(customerName,customerPhone) | add_inventory_item(name,sku,unit,stock,salePrice,costPrice) | change_quote_status(sequence,status[draft|sent|accepted|cancelled])');
    buf.writeln('Solo ACTION_JSON si el usuario PIDE crear/modificar. Para consultas solo texto.');
    buf.writeln();
    buf.writeln('COTIZACIONES(${quotes.length}):');
    for (final q in quotes.take(20)) {
      buf.writeln('COT#${q.sequence}-${q.year}|${q.customerName ?? "-"}|${q.status.label}|Bs${q.totalBob.toStringAsFixed(0)}${q.title != null ? "|${q.title}" : ""}');
    }
    buf.writeln('INVENTARIO(${items.length}):');
    for (final it in items.take(20)) {
      buf.writeln('${it.name}|stock:${it.stock}${it.unit ?? ""}|${it.salePrice != null ? "Bs${it.salePrice!.toStringAsFixed(0)}" : "-"}');
    }
    buf.writeln('OTs(${orders.length}):');
    for (final o in orders.take(15)) {
      buf.writeln('OT#${o.sequence}-${o.year}|${o.customerName ?? "-"}|${o.status.label}');
    }
    return buf.toString();
  }
}
