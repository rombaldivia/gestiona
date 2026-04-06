import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/module_permission_guard.dart';

import '../domain/quote.dart';
import '../domain/quote_status.dart';
import '../presentation/quotes_controller.dart';
import '../presentation/quotes_state.dart';
import 'quote_editor_page.dart';

class QuotesPage extends ConsumerWidget {
  const QuotesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(quotesControllerProvider);
    final ctrl = ref.read(quotesControllerProvider.notifier);

    return ModulePermissionGuard(
      moduleKey: 'quotes',
      moduleLabel: 'Cotizaciones',
      child: Scaffold(
        appBar: AppBar(title: const Text('Cotizaciones')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () async {
            final q = await ctrl.newDraft(); // ✅ newDraft() es Future<Quote>
            if (!context.mounted) return;
            _openEditor(context, q);
          },
          icon: const Icon(Icons.add),
          label: const Text('Nueva'),
        ),
        body: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (state) => _Body(state: state, ctrl: ctrl),
        ),
      ),
    );
  }

  void _openEditor(BuildContext context, Quote quote) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => QuoteEditorPage(quote: quote)));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _Body extends ConsumerWidget {
  const _Body({required this.state, required this.ctrl});
  final QuotesState state;
  final QuotesController ctrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quotes = state.visible;

    return Column(
      children: [
        // Barra de búsqueda
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: TextField(
            onChanged: ctrl.setQuery,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Buscar por cliente o número…',
            ),
          ),
        ),
        // Chips de filtro
        SizedBox(
          height: 52,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            scrollDirection: Axis.horizontal,
            children: [
              _FilterChip(
                label: 'Todas',
                selected: state.filterStatus == null,
                onTap: () => ctrl.setFilter(null),
              ),
              ...QuoteStatus.values.map(
                (s) => _FilterChip(
                  label: s.label,
                  selected: state.filterStatus == s,
                  status: s,
                  onTap: () => ctrl.setFilter(s),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // Lista
        Expanded(
          child: quotes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.description_outlined,
                        size: 56,
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.3),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        state.filterStatus == null && state.query.isEmpty
                            ? 'Aún no hay cotizaciones.\nToca + para crear la primera.'
                            : 'Sin resultados.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                  itemCount: quotes.length,
                  separatorBuilder: (_, i) => const SizedBox(height: 10),
                  itemBuilder: (_, i) =>
                      _QuoteCard(quote: quotes[i], ctrl: ctrl),
                ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.status,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final QuoteStatus? status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = status == null
        ? scheme.primary
        : _statusColor(status!, scheme);

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        selectedColor: color.withValues(alpha: 0.15),
        checkmarkColor: color,
        labelStyle: TextStyle(
          color: selected ? color : scheme.onSurfaceVariant,
          fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
        ),
        side: BorderSide(
          color: selected ? color : scheme.outlineVariant,
          width: selected ? 1.5 : 1,
        ),
        backgroundColor: Colors.transparent,
        onSelected: (_) => onTap(),
      ),
    );
  }

  Color _statusColor(QuoteStatus s, ColorScheme scheme) => switch (s) {
    QuoteStatus.draft => Colors.blueGrey,
    QuoteStatus.sent => scheme.primary,
    QuoteStatus.accepted => Colors.green.shade700,
    QuoteStatus.cancelled => Colors.redAccent,
  };
}

// ─────────────────────────────────────────────────────────────────────────────
class _QuoteCard extends ConsumerWidget {
  const _QuoteCard({required this.quote, required this.ctrl});
  final Quote quote;
  final QuotesController ctrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final date = DateTime.fromMillisecondsSinceEpoch(quote.updatedAtMs);
    final dateStr =
        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

    return Card(
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => QuoteEditorPage(quote: quote)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: número + estado
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'COT #${quote.sequence}-${quote.year}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  _StatusBadge(status: quote.status),
                ],
              ),
              const SizedBox(height: 6),
              // Cliente
              if ((quote.customerName ?? '').isNotEmpty)
                Row(
                  children: [
                    Icon(
                      Icons.person_outline,
                      size: 15,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        quote.customerName!,
                        style: TextStyle(color: scheme.onSurfaceVariant),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 8),
              // Footer: total + fecha
              Row(
                children: [
                  Text(
                    'Bs ${quote.totalBob.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: scheme.primary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    dateStr,
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 10),
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert,
                      size: 18,
                      color: scheme.onSurfaceVariant,
                    ),
                    onSelected: (v) async {
                      if (v == 'delete') {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Eliminar cotización'),
                            content: Text(
                              '¿Eliminar COT #${quote.sequence}-${quote.year}?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancelar'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Eliminar'),
                              ),
                            ],
                          ),
                        );
                        if (ok == true) await ctrl.delete(quote.id);
                      }
                      if (v == 'duplicate') {
                        final dup = await ctrl.duplicate(
                          quote,
                          mode: 'duplicate',
                        );
                        if (!context.mounted) return;
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => QuoteEditorPage(quote: dup),
                          ),
                        );
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'duplicate',
                        child: Text('Duplicar'),
                      ),
                      PopupMenuDivider(),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text(
                          'Eliminar',
                          style: TextStyle(color: Colors.redAccent),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final QuoteStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      QuoteStatus.draft => Colors.blueGrey,
      QuoteStatus.sent => Theme.of(context).colorScheme.primary,
      QuoteStatus.accepted => Colors.green.shade700,
      QuoteStatus.cancelled => Colors.redAccent,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
