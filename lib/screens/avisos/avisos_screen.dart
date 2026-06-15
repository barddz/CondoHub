import 'package:flutter/material.dart';

import '../../widgets/base_screen.dart';
import '../../widgets/info_card.dart';

class AvisosScreen extends StatelessWidget {
  const AvisosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const BaseScreen(
      title: 'Avisos',
      subtitle: 'Comunicados recentes do condomínio',
      children: [
        InfoCard(
          title: '⚠️ Manutenção da água',
          description:
              'O abastecimento será interrompido amanhã das 8h às 12h.',
          footer: '18/05 • 14:30',
        ),
        InfoCard(
          title: 'Reunião do condomínio',
          description:
              'Assembleia marcada para sexta-feira às 19h no salão principal.',
          footer: '17/05 • 10:00',
        ),
        InfoCard(
          title: 'Limpeza da garagem',
          description: 'Evite estacionar nos setores A e B durante a manhã.',
          footer: '16/05 • 09:15',
        ),
      ],
    );
  }
}
