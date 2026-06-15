import 'package:flutter/material.dart';

import '../../widgets/base_screen.dart';
import '../../widgets/info_card.dart';

class EncomendasScreen extends StatelessWidget {
  const EncomendasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const BaseScreen(
      title: 'Encomendas',
      subtitle: 'Acompanhe entregas recebidas na portaria',
      children: [
        InfoCard(
          title: '📦 Amazon',
          description: 'Recebido em 13/05 às 10:05.',
          footer: 'Disponível para retirada',
          footerColor: Color(0xFF16A34A),
        ),
        InfoCard(
          title: '📦 Mercado Livre',
          description: 'Recebido em 12/05 às 15:40.',
          footer: 'Disponível para retirada',
          footerColor: Color(0xFF16A34A),
        ),
        InfoCard(
          title: '📦 Shopee',
          description: 'Retirado em 11/05 às 19:10.',
          footer: 'Retirada concluída',
          footerColor: Color(0xFF2563EB),
        ),
      ],
    );
  }
}
