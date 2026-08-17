import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../widgets/base_screen.dart';
import '../../widgets/info_card.dart';
import 'documento_detalhe_screen.dart';

class DocumentosNormasScreen extends StatelessWidget {
  const DocumentosNormasScreen({super.key});

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

  void _abrirDocumento(
    BuildContext context, {
    required String titulo,
    required String descricao,
    required String categoria,
    required String conteudo,
    required dynamic atualizadoEm,
    required String arquivoCaminho,
    required String arquivoNome,
    required dynamic arquivoTamanho,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DocumentoDetalheScreen(
          titulo: titulo,
          descricao: descricao,
          categoria: categoria,
          conteudo: conteudo,
          atualizadoEm: atualizadoEm,
          arquivoCaminho: arquivoCaminho,
          arquivoNome: arquivoNome,
          arquivoTamanho: arquivoTamanho,
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
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream:
              FirebaseFirestore.instance.collection('documentos').snapshots(),
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
                title: 'Erro ao carregar documentos',
                description: 'Não foi possível carregar os documentos.',
                footer: 'Tente novamente mais tarde',
                footerColor: Color(0xFFDC2626),
              );
            }

            final List<QueryDocumentSnapshot<Map<String, dynamic>>> documentos =
                [...(snapshot.data?.docs ?? [])];

            documentos.sort((a, b) {
              final dataA = a.data()['atualizadoEm'];
              final dataB = b.data()['atualizadoEm'];

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
                title: 'Nenhum documento disponível',
                description:
                    'Quando a administração cadastrar documentos e normas, eles aparecerão nesta tela.',
                footer: 'Aguardando novos documentos',
              );
            }

            return Column(
              children: documentos.map((doc) {
                final dados = doc.data();

                final titulo = dados['titulo']?.toString() ?? 'Documento';
                final descricao =
                    dados['descricao']?.toString() ?? 'Sem descrição';
                final categoria = dados['categoria']?.toString() ?? 'Documento';
                final conteudo = dados['conteudo']?.toString() ?? '';
                final atualizadoEm = dados['atualizadoEm'];
                final arquivoCaminho =
                    dados['arquivoCaminho']?.toString().trim() ?? '';
                final arquivoNome =
                    dados['arquivoNome']?.toString().trim() ?? '';
                final arquivoTamanho = dados['arquivoTamanho'];

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: InfoCard(
                    title: titulo,
                    description: descricao,
                    footer:
                        '${arquivoCaminho.isNotEmpty ? 'PDF anexado • ' : ''}$categoria • Atualizado em ${_formatarData(atualizadoEm)}',
                    footerColor: AppColors.primary,
                    onTap: () => _abrirDocumento(
                      context,
                      titulo: titulo,
                      descricao: descricao,
                      categoria: categoria,
                      conteudo: conteudo,
                      atualizadoEm: atualizadoEm,
                      arquivoCaminho: arquivoCaminho,
                      arquivoNome: arquivoNome,
                      arquivoTamanho: arquivoTamanho,
                    ),
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
