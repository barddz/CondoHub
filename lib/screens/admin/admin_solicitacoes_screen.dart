import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../widgets/base_screen.dart';
import '../../widgets/info_card.dart';

class AdminSolicitacoesScreen extends StatelessWidget {
  const AdminSolicitacoesScreen({super.key});

  String _formatarData(Timestamp? timestamp) {
    if (timestamp == null) {
      return 'Data não informada';
    }

    final data = timestamp.toDate();

    final dia = data.day.toString().padLeft(2, '0');
    final mes = data.month.toString().padLeft(2, '0');
    final ano = data.year.toString();
    final hora = data.hour.toString().padLeft(2, '0');
    final minuto = data.minute.toString().padLeft(2, '0');

    return '$dia/$mes/$ano às $hora:$minuto';
  }

  @override
  Widget build(BuildContext context) {
    return BaseScreen(
      title: 'Solicitações',
      subtitle: 'Solicitações enviadas pelos moradores',
      children: [
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('solicitacoes_atendimento')
              .orderBy('criadoEm', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              );
            }

            if (snapshot.hasError) {
              return const InfoCard(
                title: 'Erro ao carregar solicitações',
                description:
                    'Não foi possível buscar as solicitações no Firestore.',
                footer: 'Verifique a conexão ou as regras do banco',
                footerColor: Color(0xFFDC2626),
              );
            }

            final documentos = snapshot.data?.docs ?? [];

            if (documentos.isEmpty) {
              return const InfoCard(
                title: 'Nenhuma solicitação encontrada',
                description:
                    'Quando um morador abrir uma solicitação, ela aparecerá nesta tela.',
                footer: 'Firestore conectado',
              );
            }

            return Column(
              children: documentos.map((doc) {
                final dados = doc.data();

                final assunto = dados['assunto'] ?? 'Sem assunto';
                final categoria =
                    dados['categoria'] ?? 'Categoria não informada';
                final mensagem = dados['mensagem'] ?? 'Mensagem não informada';
                final status = dados['status'] ?? 'Em análise';
                final moradorNome =
                    dados['moradorNome'] ?? 'Morador não informado';
                final criadoEm = dados['criadoEm'];

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: InfoCard(
                    title: assunto,
                    description:
                        'Morador: $moradorNome\nCategoria: $categoria\n\n$mensagem',
                    footer: 'Status: $status • ${_formatarData(criadoEm)}',
                    footerColor: AppColors.primary,
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}
