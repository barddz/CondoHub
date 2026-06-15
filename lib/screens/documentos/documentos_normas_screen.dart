import 'package:flutter/material.dart';

import '../../widgets/base_screen.dart';
import '../../widgets/info_card.dart';
import 'documento_detalhe_screen.dart';

class DocumentosNormasScreen extends StatelessWidget {
  const DocumentosNormasScreen({super.key});

  void _abrirDocumento(
    BuildContext context,
    String titulo,
    String descricao,
    String tipo,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DocumentoDetalheScreen(
          titulo: titulo,
          descricao: descricao,
          tipo: tipo,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BaseScreen(
      title: 'Documentos',
      subtitle: 'Normas e documentos do condomínio',
      children: [
        InfoCard(
          title: 'Regulamento interno',
          description:
              'Regras de convivência, uso de áreas comuns, garagem, visitantes, animais, reformas e horários.',
          footer: 'Atualizado em 10/05/2026',
          onTap: () => _abrirDocumento(
            context,
            'Regulamento interno',
            'Regras de convivência, uso de áreas comuns, garagem, visitantes, animais, reformas e horários.',
            'regulamento',
          ),
        ),
        InfoCard(
          title: 'Convenção do condomínio',
          description:
              'Documento formal com regras de administração, direitos, deveres dos condôminos e funcionamento do condomínio.',
          footer: 'Documento oficial',
          onTap: () => _abrirDocumento(
            context,
            'Convenção do condomínio',
            'Documento formal com regras de administração, direitos, deveres dos condôminos e funcionamento do condomínio.',
            'convencao',
          ),
        ),
        InfoCard(
          title: 'Atas de assembleia',
          description:
              'Registro das decisões tomadas em reuniões e assembleias do condomínio.',
          footer: 'Consulta disponível',
          onTap: () => _abrirDocumento(
            context,
            'Atas de assembleia',
            'Registro das decisões tomadas em reuniões e assembleias do condomínio.',
            'atas',
          ),
        ),
        InfoCard(
          title: 'Comunicados administrativos',
          description:
              'Documentos, informes e orientações emitidos pela administração do condomínio.',
          footer: 'Administração',
          onTap: () => _abrirDocumento(
            context,
            'Comunicados administrativos',
            'Documentos, informes e orientações emitidos pela administração do condomínio.',
            'comunicados',
          ),
        ),
      ],
    );
  }
}
