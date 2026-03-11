import 'package:flutter/material.dart';

class SyncModeBadge extends StatelessWidget {
  const SyncModeBadge({
    super.key,
    required this.isActive,
    this.isLoading = false,
  });

  final bool isActive;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final base = isActive ? Colors.green : Colors.orange;
    final bg = base.withAlpha(38);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: base.withAlpha(120)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLoading) ...[
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: base),
            ),
            const SizedBox(width: 8),
          ] else ...[
            Icon(Icons.circle, size: 10, color: base),
            const SizedBox(width: 8),
          ],
          Text(
            isActive ? 'Sincronización activa' : 'Modo local',
            style: TextStyle(
              color: base,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
