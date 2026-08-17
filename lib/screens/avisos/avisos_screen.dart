import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../widgets/base_screen.dart';
import '../../widgets/info_card.dart';

class AvisosScreen extends StatelessWidget {
  const AvisosScreen({super.key});

  String _formatarData(dynamic valor) {
    if (valor is! Timestamp) {
      return 'Data não informada';
    }

    final data = valor.toDate();

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
      title: 'Avisos',
      subtitle: 'Comunicados recentes do condomínio',
      children: [
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('avisos').snapshots(),
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
                title: 'Erro ao carregar avisos',
                description: 'Não foi possível carregar os avisos.',
                footer: 'Tente novamente mais tarde',
                footerColor: Color(0xFFDC2626),
              );
            }

            final documentos = [...(snapshot.data?.docs ?? [])];

            documentos.sort((a, b) {
              final dataA = a.data()['criadoEm'];
              final dataB = b.data()['criadoEm'];

              if (dataA is Timestamp && dataB is Timestamp) {
                return dataB.toDate().compareTo(dataA.toDate());
              }

              if (dataA is Timestamp) {
                return -1;
              }

              if (dataB is Timestamp) {
                return 1;
              }

              return 0;
            });

            if (documentos.isEmpty) {
              return const InfoCard(
                title: 'Nenhum aviso publicado',
                description:
                    'Quando a administração publicar um aviso, ele aparecerá nesta tela.',
                footer: 'Aguardando novos comunicados',
              );
            }

            return Column(
              children: documentos.map((doc) {
                final dados = doc.data();

                final titulo = dados['titulo'] ?? 'Aviso sem título';
                final mensagem = dados['mensagem'] ?? 'Sem mensagem';
                final criadoEm = dados['criadoEm'];

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: InfoCard(
                    title: titulo,
                    description: mensagem,
                    footer: _formatarData(criadoEm),
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
