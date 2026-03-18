import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/chat_message.dart';
import '../domain/gemini_action.dart';
import '../presentation/gemini_chat_controller.dart';

class GeminiChatPage extends ConsumerStatefulWidget {
  const GeminiChatPage({super.key});

  @override
  ConsumerState<GeminiChatPage> createState() => _GeminiChatPageState();
}

class _GeminiChatPageState extends ConsumerState<GeminiChatPage> {
  final _inputCtrl  = TextEditingController();
  final _scrollCtrl = ScrollController();

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    _inputCtrl.clear();
    await ref.read(geminiChatProvider.notifier).send(text);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final chatAsync = ref.watch(geminiChatProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFF1565C0),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 10),
          const Text('Asistente Gestiona'),
        ]),
        actions: [
          chatAsync.whenOrNull(
            data: (s) => s.messages.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.delete_sweep_outlined),
                    tooltip: 'Limpiar chat',
                    onPressed: () => ref.read(geminiChatProvider.notifier).clearHistory(),
                  )
                : null,
          ) ?? const SizedBox.shrink(),
          IconButton(
            icon: const Icon(Icons.key_outlined),
            tooltip: 'Configurar API Key',
            onPressed: () => _showKeyDialog(context),
          ),
        ],
      ),
      body: chatAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => Center(child: Text('Error: $e')),
        data:    (state) => _ChatBody(
          state:           state,
          scrollCtrl:      _scrollCtrl,
          inputCtrl:       _inputCtrl,
          onSend:          _send,
          onSetupKey:      () => _showKeyDialog(context),
          onConfirmAction: (action) => _executeAction(context, action),
          onDismissAction: () => ref.read(geminiChatProvider.notifier).clearPendingAction(),
        ),
      ),
    );
  }

  Future<void> _executeAction(BuildContext context, GeminiAction action) async {
    final messenger = ScaffoldMessenger.of(context);
    ref.read(geminiChatProvider.notifier).clearPendingAction();
    final result = await ref.read(geminiChatProvider.notifier).executeAction(action);
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(content: Text(result)));
  }

  Future<void> _showKeyDialog(BuildContext context) async {
    final ctrl    = ref.read(geminiChatProvider.notifier);
    final current = ref.read(geminiChatProvider).value?.apiKey ?? '';
    final tc      = TextEditingController(text: current);

    await showDialog<void>(
      context: context,
      builder: (ctx) => _ApiKeyDialog(
        controller: tc,
        onSave: (key) async {
          if (key.trim().isEmpty) {
            await ctrl.clearKey();
            return;
          }
          // Validar antes de guardar
          final error = await ctrl.validateKey(key.trim());
          if (!ctx.mounted) return;
          if (error != null) {
            ScaffoldMessenger.of(ctx).showSnackBar(
              SnackBar(
                content: Text(error),
                backgroundColor: AppColors.error,
                duration: const Duration(seconds: 5),
              ),
            );
            return;
          }
          await ctrl.saveKey(key.trim());
          if (!ctx.mounted) return;
          Navigator.pop(ctx);
          ScaffoldMessenger.of(ctx).showSnackBar(
            const SnackBar(content: Text('API Key guardada ✅')),
          );
        },
      ),
    );
  }
}

// ── Cuerpo del chat ───────────────────────────────────────────────────────────

class _ChatBody extends StatelessWidget {
  const _ChatBody({
    required this.state,
    required this.scrollCtrl,
    required this.inputCtrl,
    required this.onSend,
    required this.onSetupKey,
    required this.onConfirmAction,
    required this.onDismissAction,
  });

  final GeminiChatState             state;
  final ScrollController            scrollCtrl;
  final TextEditingController       inputCtrl;
  final VoidCallback                onSend;
  final VoidCallback                onSetupKey;
  final void Function(GeminiAction) onConfirmAction;
  final VoidCallback                onDismissAction;

  @override
  Widget build(BuildContext context) {
    if (!state.hasKey) return _NoKeyState(onSetupKey: onSetupKey);

    return Column(
      children: [
        if (state.error != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: AppColors.error.withValues(alpha: 0.1),
            child: Row(children: [
              const Icon(Icons.error_outline, color: AppColors.error, size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text(state.error!, style: const TextStyle(color: AppColors.error, fontSize: 12))),
            ]),
          ),

        // Mensajes
        Expanded(
          child: state.messages.isEmpty
              ? _EmptyChat()
              : ListView.builder(
                  controller:  scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  itemCount:   state.messages.length,
                  itemBuilder: (_, i) => _MessageBubble(msg: state.messages[i]),
                ),
        ),

        // Card de acción pendiente
        if (state.pendingAction != null)
          _ActionConfirmCard(
            action:    state.pendingAction!,
            onConfirm: () => onConfirmAction(state.pendingAction!),
            onDismiss: onDismissAction,
          ),

        // Input
        _InputBar(
          controller: inputCtrl,
          isSending:  state.isSending,
          onSend:     onSend,
        ),
      ],
    );
  }
}

// ── Burbuja de mensaje ────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.msg});
  final ChatMessage msg;

  @override
  Widget build(BuildContext context) {
    final isUser = msg.isUser;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 14),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.only(
                  topLeft:     const Radius.circular(16),
                  topRight:    const Radius.circular(16),
                  bottomLeft:  Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                border: isUser ? null : Border.all(color: AppColors.border),
                boxShadow: isUser ? null : AppShadows.card,
              ),
              child: msg.isLoading
                  ? const _TypingIndicator()
                  : Text(
                      msg.text,
                      style: TextStyle(
                        color:    isUser ? Colors.white : AppColors.textPrimary,
                        fontSize: 14,
                        height:   1.45,
                      ),
                    ),
            ),
          ),
          if (isUser) const SizedBox(width: 4),
        ],
      ),
    );
  }
}

// ── Indicador de escritura ────────────────────────────────────────────────────

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();
  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac;
  late final Animation<double>   _anim;

  @override
  void initState() {
    super.initState();
    _ac   = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 1.0).animate(_ac);
  }

  @override
  void dispose() { _ac.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        for (int i = 0; i < 3; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Container(
            width: 7, height: 7,
            decoration: const BoxDecoration(
              color: AppColors.textHint,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ]),
    );
  }
}

// ── Barra de input ────────────────────────────────────────────────────────────

class _InputBar extends StatelessWidget {
  const _InputBar({required this.controller, required this.isSending, required this.onSend});
  final TextEditingController controller;
  final bool                  isSending;
  final VoidCallback          onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 10, 16, MediaQuery.of(context).viewInsets.bottom + 14),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller:  controller,
            minLines:    1,
            maxLines:    4,
            enabled:     !isSending,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => onSend(),
            decoration: InputDecoration(
              hintText:      '¿En qué te ayudo?',
              filled:        true,
              fillColor:     AppColors.background,
              border:        OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide:   BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
        ),
        const SizedBox(width: 8),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          child: FilledButton(
            onPressed: isSending ? null : onSend,
            style: FilledButton.styleFrom(
              shape:   const CircleBorder(),
              padding: const EdgeInsets.all(14),
            ),
            child: isSending
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send_rounded, size: 18),
          ),
        ),
      ]),
    );
  }
}

// ── Estado sin API key ────────────────────────────────────────────────────────

class _NoKeyState extends StatelessWidget {
  const _NoKeyState({required this.onSetupKey});
  final VoidCallback onSetupKey;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.key_outlined, color: AppColors.primary, size: 36),
            ),
            const SizedBox(height: 20),
            Text('Configura tu API Key',
                style: AppTextStyles.title.copyWith(fontSize: 18)),
            const SizedBox(height: 8),
            Text(
              'Obtén tu API Key gratuita en aistudio.google.com\ny pégala aquí para activar el asistente.',
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onSetupKey,
              icon:  const Icon(Icons.key_outlined),
              label: const Text('Agregar API Key'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Chat vacío ────────────────────────────────────────────────────────────────

class _EmptyChat extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final suggestions = [
      '¿Qué cotizaciones tengo pendientes?',
      '¿Cuánto vendí este mes?',
      '¿Qué producto tengo con más stock?',
      '¿Cuáles OTs están en proceso?',
    ];

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 20),
        Center(
          child: Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.auto_awesome, color: AppColors.primary, size: 32),
          ),
        ),
        const SizedBox(height: 16),
        Text('¿En qué te ayudo hoy?',
            textAlign: TextAlign.center,
            style: AppTextStyles.title.copyWith(fontSize: 17)),
        const SizedBox(height: 6),
        Text('Conozco tus cotizaciones, inventario y órdenes de trabajo.',
            textAlign: TextAlign.center,
            style: AppTextStyles.label),
        const SizedBox(height: 28),
        ...suggestions.map((s) => _SuggestionChip(text: s)),
      ],
    );
  }
}

class _SuggestionChip extends ConsumerWidget {
  const _SuggestionChip({required this.text});
  final String text;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => ref.read(geminiChatProvider.notifier).send(text),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color:        AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border:       Border.all(color: AppColors.border),
            boxShadow:    AppShadows.card,
          ),
          child: Row(children: [
            const Icon(Icons.chat_bubble_outline, size: 16, color: AppColors.primaryLight),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: AppTextStyles.body.copyWith(fontSize: 13))),
            const Icon(Icons.arrow_forward_ios, size: 12, color: AppColors.textHint),
          ]),
        ),
      ),
    );
  }
}

// ── Diálogo de API Key ────────────────────────────────────────────────────────

class _ApiKeyDialog extends StatefulWidget {
  const _ApiKeyDialog({required this.controller, required this.onSave});
  final TextEditingController       controller;
  final Future<void> Function(String) onSave;

  @override
  State<_ApiKeyDialog> createState() => _ApiKeyDialogState();
}

class _ApiKeyDialogState extends State<_ApiKeyDialog> {
  bool _saving  = false;
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(children: [
        Icon(Icons.key_outlined, size: 20),
        SizedBox(width: 8),
        Text('API Key de Gemini'),
      ]),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Obtén tu key gratuita en:',
            style: AppTextStyles.label,
          ),
          const SelectableText(
            'aistudio.google.com',
            style: TextStyle(
              color:      AppColors.primaryLight,
              fontWeight: FontWeight.w600,
              fontSize:   13,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller:  widget.controller,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: 'AIza...',
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving
              ? null
              : () async {
                  setState(() => _saving = true);
                  await widget.onSave(widget.controller.text);
                  if (mounted) setState(() => _saving = false);
                },
          child: _saving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Guardar'),
        ),
      ],
    );
  }
}

// ── Card de confirmación de acción ────────────────────────────────────────────
class _ActionConfirmCard extends StatelessWidget {
  const _ActionConfirmCard({required this.action, required this.onConfirm, required this.onDismiss});
  final GeminiAction action;
  final VoidCallback onConfirm;
  final VoidCallback onDismiss;

  IconData get _icon {
    switch (action.type) {
      case GeminiActionType.createQuote:       return Icons.request_quote_outlined;
      case GeminiActionType.createWorkOrder:   return Icons.engineering_outlined;
      case GeminiActionType.addInventoryItem:  return Icons.inventory_2_outlined;
      case GeminiActionType.changeQuoteStatus: return Icons.swap_horiz_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F7FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF90CAF9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(_icon, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(child: Text(action.description,
                style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.primary, fontSize: 13))),
            IconButton(
              icon: const Icon(Icons.close, size: 16),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: onDismiss,
            ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            const Spacer(),
            TextButton(onPressed: onDismiss, child: const Text('Cancelar')),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: onConfirm,
              icon: const Icon(Icons.check, size: 16),
              label: const Text('Confirmar'),
            ),
          ]),
        ],
      ),
    );
  }
}

// ── Card de confirmación de acción ────────────────────────────────────────────
