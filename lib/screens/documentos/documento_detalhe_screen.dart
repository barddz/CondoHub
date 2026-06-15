import 'package:flutter/material.dart';

import '../../widgets/base_screen.dart';
import '../../widgets/info_card.dart';

class DocumentoDetalheScreen extends StatelessWidget {
  final String titulo;
  final String descricao;
  final String tipo;

  const DocumentoDetalheScreen({
    super.key,
    required this.titulo,
    required this.descricao,
    required this.tipo,
  });

  List<Widget> _conteudoDocumento() {
    if (tipo == 'regulamento') {
      return const [
        InfoCard(
          title: 'Visão geral',
          description:
              'O regulamento interno reúne as regras práticas do dia a dia do condomínio, incluindo convivência, uso das áreas comuns, garagem, visitantes e horários.',
          footer: 'Conteúdo demonstrativo do MVP',
        ),
        InfoCard(
          title: 'Horário de silêncio',
          description:
              'Define os períodos em que ruídos devem ser evitados para preservar o conforto dos moradores.',
          footer: 'Seção do regulamento',
        ),
        InfoCard(
          title: 'Uso das áreas comuns',
          description:
              'Regras para utilização de churrasqueira, salão de festas, quadra esportiva e demais espaços compartilhados.',
          footer: 'Seção do regulamento',
        ),
        InfoCard(
          title: 'Garagem e vagas',
          description:
              'Orientações sobre circulação, velocidade máxima, vagas de visitantes e uso adequado do estacionamento.',
          footer: 'Seção do regulamento',
        ),
        InfoCard(
          title: 'Visitantes e prestadores',
          description:
              'Regras para entrada de visitantes, entregadores, prestadores de serviço e autorizações de acesso.',
          footer: 'Seção do regulamento',
        ),
        InfoCard(
          title: 'Animais de estimação',
          description:
              'Normas de convivência relacionadas à circulação de animais nas áreas comuns do condomínio.',
          footer: 'Seção do regulamento',
        ),
      ];
    }

    return [
      InfoCard(
        title: titulo,
        description: descricao,
        footer: 'Conteúdo demonstrativo do MVP',
      ),
      const InfoCard(
        title: 'Conteúdo do documento',
        description:
            'Nesta versão inicial do MVP, o conteúdo é exibido de forma simulada. Em uma versão integrada ao banco de dados, o documento completo seria carregado a partir do Firebase/Firestore ou por meio de um arquivo armazenado no sistema.',
        footer: 'Integração futura com banco de dados',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return BaseScreen(
      title: titulo,
      subtitle: 'Visualização do documento',
      children: _conteudoDocumento(),
    );
  }
}
