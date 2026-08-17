import 'package:flutter/material.dart';

class StatusChip extends StatelessWidget {
  final String status;

  const StatusChip({
    super.key,
    required this.status,
  });

  Color get _color {
    if ({
      'Aprovada',
      'Resolvida',
      'Entrada autorizada',
      'Entrada realizada',
      'Retirada concluída',
    }.contains(status)) {
      return const Color(0xFF15803D);
    }

    if ({'Recusada', 'Entrada recusada'}.contains(status)) {
      return const Color(0xFFB91C1C);
    }

    if (status == 'Cancelada' || status == 'Expirado') {
      return const Color(0xFF6B7280);
    }

    if ({
      'Em análise',
      'Aguardando autorização',
      'Disponível para retirada',
    }.contains(status)) {
      return const Color(0xFFB45309);
    }

    return const Color(0xFF2563EB);
  }

  IconData get _icon {
    if ({
      'Aprovada',
      'Resolvida',
      'Entrada autorizada',
      'Entrada realizada',
      'Retirada concluída',
    }.contains(status)) {
      return Icons.check_circle_outline;
    }

    if ({'Recusada', 'Entrada recusada'}.contains(status)) {
      return Icons.highlight_off;
    }

    if (status == 'Cancelada' || status == 'Expirado') {
      return Icons.cancel_outlined;
    }

    if ({
      'Em análise',
      'Aguardando autorização',
      'Disponível para retirada',
    }.contains(status)) {
      return Icons.schedule;
    }

    return Icons.info_outline;
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;

    return Semantics(
      label: 'Status: $status',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_icon, size: 15, color: color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                status,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
