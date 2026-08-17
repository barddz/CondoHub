import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../widgets/base_screen.dart';
import '../../widgets/info_card.dart';
import '../../widgets/record_section_header.dart';
import '../../widgets/status_chip.dart';

class EncomendasScreen extends StatelessWidget {
  const EncomendasScreen({super.key});

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

  Widget _cardEncomenda(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final dados = doc.data();
    final origem = dados['origem'] ?? 'Origem não informada';
    final observacao = dados['observacao'] ?? '';
    final status = dados['status']?.toString() ?? 'Disponível para retirada';
    final recebidoEm = dados['recebidoEm'];
    final retiradoEm = dados['retiradoEm'];
    final descricao = observacao.toString().trim().isEmpty
        ? 'Recebido em ${_formatarData(recebidoEm)}.'
        : 'Recebido em ${_formatarData(recebidoEm)}.\n\n$observacao';
    final footer = status == 'Retirada concluída'
        ? 'Retirada em ${_formatarData(retiradoEm)}'
        : 'Aguardando retirada na portaria';

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InfoCard(
        title: origem.toString(),
        leadingIcon: Icons.inventory_2_outlined,
        description: descricao,
        footer: footer,
        badge: StatusChip(status: status),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final usuario = FirebaseAuth.instance.currentUser;

    return BaseScreen(
      title: 'Encomendas',
      subtitle: 'Acompanhe entregas recebidas na portaria',
      children: [
        if (usuario == null)
          const InfoCard(
            title: 'Usuário não autenticado',
            description:
                'Faça login novamente para visualizar suas encomendas.',
            footer: 'Encomendas',
          )
        else
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('encomendas')
                .where('moradorId', isEqualTo: usuario.uid)
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
                  title: 'Erro ao carregar encomendas',
                  description: 'Não foi possível carregar suas encomendas.',
                  footer: 'Tente novamente mais tarde',
                  footerColor: Color(0xFFDC2626),
                );
              }

              final documentos = <QueryDocumentSnapshot<Map<String, dynamic>>>[
                ...(snapshot.data?.docs ?? []),
              ];

              documentos.sort((a, b) {
                final dataA = a.data()['recebidoEm'];
                final dataB = b.data()['recebidoEm'];

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
                  title: 'Nenhuma encomenda encontrada',
                  description:
                      'Quando a portaria cadastrar uma encomenda para você, ela aparecerá nesta tela.',
                  footer: 'Aguardando novas entregas',
                );
              }

              final encomendasAtivas = documentos.where((doc) {
                return doc.data()['status'] != 'Retirada concluída';
              }).toList();
              final historico = documentos.where((doc) {
                return doc.data()['status'] == 'Retirada concluída';
              }).toList();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (encomendasAtivas.isNotEmpty) ...[
                    RecordSectionHeader(
                      title: 'Para retirar',
                      count: encomendasAtivas.length,
                      icon: Icons.inventory_2_outlined,
                    ),
                    ...encomendasAtivas.map(_cardEncomenda),
                  ],
                  if (historico.isNotEmpty) ...[
                    if (encomendasAtivas.isNotEmpty) const SizedBox(height: 8),
                    RecordSectionHeader(
                      title: 'Histórico',
                      count: historico.length,
                      icon: Icons.history,
                    ),
                    ...historico.map(_cardEncomenda),
                  ],
                ],
              );
            },
          ),
      ],
    );
  }
}
