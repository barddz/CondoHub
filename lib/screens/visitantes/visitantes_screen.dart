import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_helpers.dart';
import '../../widgets/base_screen.dart';
import '../../widgets/info_card.dart';

class VisitantesScreen extends StatefulWidget {
  const VisitantesScreen({super.key});

  @override
  State<VisitantesScreen> createState() => _VisitantesScreenState();
}

class _VisitantesScreenState extends State<VisitantesScreen> {
  String entregaStatus = 'Aguardando autorização';

  void autorizarEntrega() {
    setState(() {
      entregaStatus = 'Entrada autorizada';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Entrega autorizada com sucesso.'),
      ),
    );
  }

  void recusarEntrega() {
    setState(() {
      entregaStatus = 'Entrada recusada';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Entrada recusada.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BaseScreen(
      title: 'Visitantes',
      subtitle: 'Gerencie autorizações de acesso',
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: defaultCardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '🍔 Entrega iFood',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                entregaStatus == 'Aguardando autorização'
                    ? 'Entregador aguardando autorização na portaria.'
                    : entregaStatus,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              if (entregaStatus == 'Aguardando autorização')
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: autorizarEntrega,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF16A34A),
                        ),
                        child: const Text(
                          'Autorizar',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: recusarEntrega,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDC2626),
                        ),
                        child: const Text(
                          'Recusar',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        const InfoCard(
          title: 'Maria Oliveira',
          description: 'Visitante autorizado até 22h.',
          footer: 'Ativo',
          footerColor: Color(0xFF16A34A),
        ),
        const InfoCard(
          title: 'Histórico de acessos',
          description: 'Visualizar entradas recentes no condomínio.',
          footer: 'Últimos registros',
        ),
      ],
    );
  }
}
