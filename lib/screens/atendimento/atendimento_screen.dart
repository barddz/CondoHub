import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_helpers.dart';
import '../../core/in_app_notifications_repository.dart';
import '../../widgets/base_screen.dart';
import '../../widgets/info_card.dart';
import '../../widgets/record_section_header.dart';
import '../../widgets/status_chip.dart';

class AtendimentoScreen extends StatefulWidget {
  const AtendimentoScreen({super.key});

  @override
  State<AtendimentoScreen> createState() => _AtendimentoScreenState();
}

class _AtendimentoScreenState extends State<AtendimentoScreen> {
  Future<String> _buscarNomeMorador(User usuario) async {
    final doc = await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(usuario.uid)
        .get();

    final dados = doc.data();

    final nomeCompleto = dados?['nomeCompleto'];
    if (nomeCompleto is String && nomeCompleto.trim().isNotEmpty) {
      return nomeCompleto.trim();
    }

    final nome = dados?['nome'];
    if (nome is String && nome.trim().isNotEmpty) {
      return nome.trim();
    }

    final displayName = usuario.displayName;
    if (displayName != null && displayName.trim().isNotEmpty) {
      return displayName.trim();
    }

    return usuario.email ?? 'Morador';
  }

  Future<void> _salvarSolicitacaoNoFirestore({
    required String categoria,
    required String assunto,
    required String mensagem,
  }) async {
    final usuario = FirebaseAuth.instance.currentUser;

    if (usuario == null) {
      throw Exception('Usuário não autenticado.');
    }

    final moradorNome = await _buscarNomeMorador(usuario);

    final solicitacaoRef = await FirebaseFirestore.instance
        .collection('solicitacoes_atendimento')
        .add({
      'moradorId': usuario.uid,
      'moradorNome': moradorNome,
      'moradorEmail': usuario.email,
      'categoria': categoria,
      'assunto': assunto,
      'mensagem': mensagem,
      'status': 'Em análise',
      'criadoEm': FieldValue.serverTimestamp(),
      'atualizadoEm': FieldValue.serverTimestamp(),
    });

    await InAppNotificationsRepository.notificarAdministradores(
      titulo: 'Nova solicitação de atendimento',
      mensagem: '$moradorNome abriu “$assunto” na categoria $categoria.',
      tipo: 'atendimento_admin',
      referenciaId: solicitacaoRef.id,
    );
  }

  Future<void> _abrirFormulario(String categoria) async {
    final assuntoController = TextEditingController();
    final mensagemController = TextEditingController();

    try {
      await showDialog(
        context: context,
        builder: (dialogContext) {
          bool enviando = false;

          return StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              return AlertDialog(
                title: Text('Solicitação - $categoria'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: assuntoController,
                      decoration: const InputDecoration(
                        labelText: 'Assunto',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: mensagemController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Mensagem',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: enviando
                        ? null
                        : () {
                            Navigator.pop(dialogContext);
                          },
                    child: const Text('Cancelar'),
                  ),
                  ElevatedButton(
                    onPressed: enviando
                        ? null
                        : () async {
                            final assunto = assuntoController.text.trim();
                            final mensagem = mensagemController.text.trim();

                            if (assunto.isEmpty || mensagem.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Preencha o assunto e a mensagem.',
                                  ),
                                ),
                              );
                              return;
                            }

                            setDialogState(() {
                              enviando = true;
                            });

                            try {
                              await _salvarSolicitacaoNoFirestore(
                                categoria: categoria,
                                assunto: assunto,
                                mensagem: mensagem,
                              );

                              if (!mounted || !dialogContext.mounted) {
                                return;
                              }

                              Navigator.pop(dialogContext);

                              showSuccess(
                                context,
                                'Solicitação enviada para $categoria.',
                              );
                            } catch (_) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Erro ao enviar solicitação. Tente novamente.',
                                    ),
                                  ),
                                );
                              }

                              if (dialogContext.mounted) {
                                setDialogState(() {
                                  enviando = false;
                                });
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                    ),
                    child: enviando
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Text(
                            'Enviar',
                            style: TextStyle(color: Colors.white),
                          ),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      assuntoController.dispose();
      mensagemController.dispose();
    }
  }

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

  Widget _cardSolicitacao(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final dados = doc.data();
    final assunto = dados['assunto'] ?? 'Sem assunto';
    final categoria = dados['categoria'] ?? 'Categoria não informada';
    final mensagem = dados['mensagem'] ?? 'Mensagem não informada';
    final status = dados['status']?.toString() ?? 'Em análise';
    final criadoEm = dados['criadoEm'];
    final respostaAdmin = dados['respostaAdmin']?.toString().trim() ?? '';
    final descricaoResposta = respostaAdmin.isEmpty
        ? ''
        : status == 'Recusada'
            ? '\n\nMotivo da recusa: $respostaAdmin'
            : '\n\nResposta da administração: $respostaAdmin';

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InfoCard(
        title: assunto,
        description: '$categoria: $mensagem$descricaoResposta',
        footer: _formatarData(criadoEm),
        badge: StatusChip(status: status),
      ),
    );
  }

  Widget _historicoSolicitacoes() {
    final usuario = FirebaseAuth.instance.currentUser;

    if (usuario == null) {
      return const InfoCard(
        title: 'Usuário não autenticado',
        description: 'Faça login novamente para visualizar suas solicitações.',
        footer: 'Atendimento',
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('solicitacoes_atendimento')
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
            title: 'Erro ao carregar solicitações',
            description: 'Não foi possível carregar suas solicitações.',
            footer: 'Tente novamente mais tarde',
            footerColor: Color(0xFFDC2626),
          );
        }

        final documentos = <QueryDocumentSnapshot<Map<String, dynamic>>>[
          ...(snapshot.data?.docs ?? []),
        ];

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
            title: 'Minhas solicitações',
            description:
                'Nenhuma solicitação enviada até o momento. As solicitações abertas aparecerão aqui.',
            footer: 'Aguardando novas solicitações',
          );
        }

        final solicitacoesAtivas = documentos.where((doc) {
          final status = doc.data()['status']?.toString() ?? 'Em análise';
          return status == 'Em análise';
        }).toList();
        final historico = documentos.where((doc) {
          final status = doc.data()['status']?.toString() ?? 'Em análise';
          return status != 'Em análise';
        }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (solicitacoesAtivas.isNotEmpty) ...[
              RecordSectionHeader(
                title: 'Em andamento',
                count: solicitacoesAtivas.length,
                icon: Icons.pending_actions_outlined,
              ),
              ...solicitacoesAtivas.map(_cardSolicitacao),
            ],
            if (historico.isNotEmpty) ...[
              if (solicitacoesAtivas.isNotEmpty) const SizedBox(height: 8),
              RecordSectionHeader(
                title: 'Histórico',
                count: historico.length,
                icon: Icons.history,
              ),
              ...historico.map(_cardSolicitacao),
            ],
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BaseScreen(
      title: 'Atendimento',
      subtitle: 'Comunique-se com a portaria e administração',
      children: [
        InfoCard(
          title: 'Portaria',
          description:
              'Solicitações relacionadas a visitantes, entregas, acessos e comunicação direta com a portaria.',
          footer: 'Abrir solicitação',
          onTap: () => _abrirFormulario('Portaria'),
        ),
        InfoCard(
          title: 'Administração',
          description:
              'Dúvidas sobre documentos, regras, reservas, comunicados e solicitações administrativas.',
          footer: 'Abrir solicitação',
          onTap: () => _abrirFormulario('Administração'),
        ),
        InfoCard(
          title: 'Manutenção',
          description:
              'Informe problemas em áreas comuns, iluminação, vazamentos, limpeza ou equipamentos.',
          footer: 'Abrir solicitação',
          onTap: () => _abrirFormulario('Manutenção'),
        ),
        InfoCard(
          title: 'Ocorrências',
          description:
              'Registre situações envolvendo barulho, garagem, convivência ou reclamações gerais.',
          footer: 'Abrir solicitação',
          onTap: () => _abrirFormulario('Ocorrências'),
        ),
        _historicoSolicitacoes(),
      ],
    );
  }
}
