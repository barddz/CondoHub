import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_helpers.dart';
import '../../core/in_app_notifications_repository.dart';
import '../../widgets/base_screen.dart';
import '../../widgets/info_card.dart';
import '../../widgets/list_category_filter.dart';
import '../../widgets/status_chip.dart';

class AdminSolicitacoesScreen extends StatefulWidget {
  const AdminSolicitacoesScreen({super.key});

  @override
  State<AdminSolicitacoesScreen> createState() =>
      _AdminSolicitacoesScreenState();
}

class _AdminSolicitacoesScreenState extends State<AdminSolicitacoesScreen> {
  String statusSelecionado = 'Todos';

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

  Future<bool> _atualizarStatus(
    BuildContext context,
    DocumentReference<Map<String, dynamic>> referencia,
    String novoStatus,
    String? resposta,
  ) async {
    try {
      final solicitacaoSnapshot = await referencia.get();
      final dadosSolicitacao = solicitacaoSnapshot.data();
      final dadosAtualizacao = <String, dynamic>{
        'status': novoStatus,
        'atualizadoEm': FieldValue.serverTimestamp(),
      };

      if (novoStatus == 'Em análise') {
        dadosAtualizacao.addAll({
          'respostaAdmin': FieldValue.delete(),
          'motivoRecusa': FieldValue.delete(),
          'respondidoEm': FieldValue.delete(),
        });
      } else {
        dadosAtualizacao.addAll({
          'respostaAdmin': resposta,
          'motivoRecusa':
              novoStatus == 'Recusada' ? resposta : FieldValue.delete(),
          'respondidoEm': FieldValue.serverTimestamp(),
        });
      }

      await referencia.update(dadosAtualizacao);

      if (novoStatus == 'Resolvida' || novoStatus == 'Recusada') {
        final moradorId = dadosSolicitacao?['moradorId']?.toString() ?? '';
        final assunto =
            dadosSolicitacao?['assunto']?.toString() ?? 'sua solicitação';
        final titulo = novoStatus == 'Resolvida'
            ? 'Atendimento respondido'
            : 'Atendimento recusado';
        final mensagem = resposta?.trim().isNotEmpty == true
            ? '$assunto: ${resposta!.trim()}'
            : '$assunto foi atualizado para $novoStatus.';

        await InAppNotificationsRepository.notificarMorador(
          moradorId: moradorId,
          titulo: titulo,
          mensagem: mensagem,
          tipo: 'atendimento',
          referenciaId: referencia.id,
        );
      }

      if (context.mounted) {
        showSuccess(context, 'Status atualizado para $novoStatus.');
      }
      return true;
    } catch (_) {
      if (context.mounted) {
        showError(context, 'Erro ao atualizar status.');
      }
      return false;
    }
  }

  Future<void> _solicitarResposta(
    BuildContext context,
    DocumentReference<Map<String, dynamic>> referencia,
    String novoStatus,
  ) async {
    final respostaController = TextEditingController();
    bool salvando = false;

    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              final recusada = novoStatus == 'Recusada';

              return AlertDialog(
                title: Text(
                  recusada ? 'Recusar solicitação' : 'Resolver solicitação',
                ),
                content: TextField(
                  controller: respostaController,
                  enabled: !salvando,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText:
                        recusada ? 'Motivo da recusa' : 'Resposta ao morador',
                    hintText: recusada
                        ? 'Explique por que a solicitação foi recusada'
                        : 'Informe a orientação ou solução adotada',
                    border: const OutlineInputBorder(),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed:
                        salvando ? null : () => Navigator.pop(dialogContext),
                    child: const Text('Cancelar'),
                  ),
                  ElevatedButton(
                    onPressed: salvando
                        ? null
                        : () async {
                            final resposta = respostaController.text.trim();

                            if (resposta.isEmpty) {
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    recusada
                                        ? 'Informe o motivo da recusa.'
                                        : 'Informe uma resposta ao morador.',
                                  ),
                                ),
                              );
                              return;
                            }

                            setDialogState(() {
                              salvando = true;
                            });

                            final atualizada = await _atualizarStatus(
                              context,
                              referencia,
                              novoStatus,
                              resposta,
                            );

                            if (atualizada && dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            } else if (dialogContext.mounted) {
                              setDialogState(() {
                                salvando = false;
                              });
                            }
                          },
                    child: salvando
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        : const Text('Confirmar'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      respostaController.dispose();
    }
  }

  Future<void> _excluirSolicitacao(
    BuildContext context,
    String id,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('solicitacoes_atendimento')
          .doc(id)
          .delete();

      if (context.mounted) {
        showSuccess(context, 'Solicitação excluída.');
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao excluir solicitação.'),
          ),
        );
      }
    }
  }

  Future<void> _confirmarExclusao(
    BuildContext context,
    String id,
  ) async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Excluir solicitação'),
          content: const Text(
            'Tem certeza que deseja excluir esta solicitação?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
              ),
              child: const Text(
                'Excluir',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );

    if (confirmou == true) {
      if (!context.mounted) {
        return;
      }

      await _excluirSolicitacao(context, id);
    }
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
                description: 'Não foi possível carregar as solicitações.',
                footer: 'Tente novamente mais tarde',
                footerColor: Color(0xFFDC2626),
              );
            }

            final documentos = snapshot.data?.docs ?? [];

            if (documentos.isEmpty) {
              return const InfoCard(
                title: 'Nenhuma solicitação encontrada',
                description:
                    'Quando um morador abrir uma solicitação, ela aparecerá nesta tela.',
                footer: 'Aguardando novas solicitações',
              );
            }

            final solicitacoesFiltradas = documentos.where((doc) {
              final dados = doc.data();
              final status = dados['status']?.toString() ?? 'Em análise';
              final correspondeStatus =
                  statusSelecionado == 'Todos' || status == statusSelecionado;

              return correspondeStatus;
            }).toList();

            return Column(
              children: [
                ListCategoryFilter(
                  selectedValue: statusSelecionado,
                  options: const [
                    'Todos',
                    'Em análise',
                    'Resolvida',
                    'Recusada',
                  ],
                  onChanged: (value) {
                    setState(() {
                      statusSelecionado = value ?? 'Todos';
                    });
                  },
                ),
                const SizedBox(height: 16),
                if (solicitacoesFiltradas.isEmpty)
                  const InfoCard(
                    title: 'Nenhum resultado encontrado',
                    description:
                        'Não há solicitações com o status selecionado.',
                    footer: 'Selecione outra categoria para continuar',
                  )
                else
                  ...solicitacoesFiltradas.map((doc) {
                    final dados = doc.data();

                    final assunto = dados['assunto'] ?? 'Sem assunto';
                    final categoria =
                        dados['categoria'] ?? 'Categoria não informada';
                    final mensagem =
                        dados['mensagem'] ?? 'Mensagem não informada';
                    final status = dados['status'] ?? 'Em análise';
                    final moradorNome =
                        dados['moradorNome'] ?? 'Morador não informado';
                    final moradorEmail =
                        dados['moradorEmail'] ?? 'E-mail não informado';
                    final criadoEm = dados['criadoEm'];
                    final respostaAdmin =
                        dados['respostaAdmin']?.toString().trim() ?? '';

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: defaultCardDecoration(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              assunto,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Morador: $moradorNome\n'
                              'E-mail: $moradorEmail\n'
                              'Categoria: $categoria\n\n'
                              '$mensagem',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Criada em: ${_formatarData(criadoEm)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            StatusChip(status: status),
                            if (respostaAdmin.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF3F4F6),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  status == 'Recusada'
                                      ? 'Motivo da recusa: $respostaAdmin'
                                      : 'Resposta ao morador: $respostaAdmin',
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              value: ['Em análise', 'Resolvida', 'Recusada']
                                      .contains(status)
                                  ? status
                                  : 'Em análise',
                              decoration: const InputDecoration(
                                labelText: 'Alterar status',
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'Em análise',
                                  child: Text('Em análise'),
                                ),
                                DropdownMenuItem(
                                  value: 'Resolvida',
                                  child: Text('Resolvida'),
                                ),
                                DropdownMenuItem(
                                  value: 'Recusada',
                                  child: Text('Recusada'),
                                ),
                              ],
                              onChanged: (novoStatus) {
                                if (novoStatus == null ||
                                    novoStatus == status) {
                                  return;
                                }

                                if (novoStatus == 'Resolvida' ||
                                    novoStatus == 'Recusada') {
                                  _solicitarResposta(
                                    context,
                                    doc.reference,
                                    novoStatus,
                                  );
                                } else {
                                  _atualizarStatus(
                                    context,
                                    doc.reference,
                                    novoStatus,
                                    null,
                                  );
                                }
                              },
                            ),
                            if (status == 'Resolvida' ||
                                status == 'Recusada') ...[
                              const SizedBox(height: 12),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: () =>
                                      _confirmarExclusao(context, doc.id),
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Color(0xFFDC2626),
                                  ),
                                  label: const Text(
                                    'Excluir solicitação',
                                    style: TextStyle(
                                      color: Color(0xFFDC2626),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            );
          },
        ),
      ],
    );
  }
}
