import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_helpers.dart';
import '../../models/atendimento_solicitacao.dart';
import '../../widgets/base_screen.dart';
import '../../widgets/info_card.dart';

class AtendimentoScreen extends StatefulWidget {
  const AtendimentoScreen({super.key});

  @override
  State<AtendimentoScreen> createState() => _AtendimentoScreenState();
}

class _AtendimentoScreenState extends State<AtendimentoScreen> {
  final List<AtendimentoSolicitacao> solicitacoes = [];

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

    await FirebaseFirestore.instance
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
    });
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

                              if (!mounted) {
                                return;
                              }

                              setState(() {
                                solicitacoes.insert(
                                  0,
                                  AtendimentoSolicitacao(
                                    categoria: categoria,
                                    assunto: assunto,
                                    mensagem: mensagem,
                                    status: 'Em análise',
                                  ),
                                );
                              });

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

                              setDialogState(() {
                                enviando = false;
                              });
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
        if (solicitacoes.isEmpty)
          const InfoCard(
            title: 'Solicitações recentes',
            description:
                'Nenhuma solicitação enviada nesta sessão. As solicitações abertas aparecerão aqui e serão salvas no Firestore.',
            footer: 'Histórico local + Firestore',
          )
        else
          ...solicitacoes.map(
            (solicitacao) => InfoCard(
              title: solicitacao.assunto,
              description: '${solicitacao.categoria}: ${solicitacao.mensagem}',
              footer: 'Status: ${solicitacao.status}',
              footerColor: const Color(0xFF2563EB),
            ),
          ),
      ],
    );
  }
}
