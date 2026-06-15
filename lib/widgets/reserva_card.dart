import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_helpers.dart';

class ReservaCard extends StatelessWidget {
  final String title;
  final String description;
  final bool disponivel;
  final VoidCallback onReservar;
  final String? statusSolicitacao;

  const ReservaCard({
    super.key,
    required this.title,
    required this.description,
    required this.disponivel,
    required this.onReservar,
    this.statusSolicitacao,
  });

  @override
  Widget build(BuildContext context) {
    final bool solicitacaoEnviada = statusSolicitacao != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: defaultCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                solicitacaoEnviada
                    ? 'Solicitação enviada'
                    : disponivel
                        ? 'Disponível'
                        : 'Indisponível',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: solicitacaoEnviada
                      ? const Color(0xFF2563EB)
                      : disponivel
                          ? const Color(0xFF16A34A)
                          : const Color(0xFFDC2626),
                ),
              ),
              const Spacer(),
              if (disponivel)
                ElevatedButton(
                  onPressed: onReservar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                  ),
                  child: Text(
                    solicitacaoEnviada ? 'Ver horários' : 'Solicitar',
                    style: const TextStyle(
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          if (solicitacaoEnviada) ...[
            const SizedBox(height: 8),
            Text(
              'Data e horário: $statusSolicitacao',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
