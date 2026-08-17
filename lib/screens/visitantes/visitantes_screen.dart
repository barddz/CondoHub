import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_helpers.dart';
import '../../core/in_app_notifications_repository.dart';
import '../../core/visitor_access.dart';
import '../../widgets/base_screen.dart';
import '../../widgets/info_card.dart';
import '../../widgets/record_section_header.dart';
import '../../widgets/status_chip.dart';

class VisitantesScreen extends StatefulWidget {
  const VisitantesScreen({super.key});

  @override
  State<VisitantesScreen> createState() => _VisitantesScreenState();
}

class _VisitantesScreenState extends State<VisitantesScreen> {
  Timer? _relogioExpiracao;

  @override
  void initState() {
    super.initState();
    _relogioExpiracao = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _relogioExpiracao?.cancel();
    super.dispose();
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

  Future<bool> _atualizarStatus(
    DocumentReference<Map<String, dynamic>> referencia,
    String novoStatus,
    String? motivoRecusa,
  ) async {
    try {
      final registro = await referencia.get();
      final dadosRegistro = registro.data() ?? <String, dynamic>{};
      if (effectiveVisitorStatus(dadosRegistro) == 'Expirado') {
        if (mounted) {
          showWarning(
            context,
            'O período deste acesso expirou. Solicite um novo agendamento.',
          );
        }
        return false;
      }

      final dadosAtualizacao = <String, dynamic>{
        'status': novoStatus,
        'atualizadoEm': FieldValue.serverTimestamp(),
      };

      if (novoStatus == 'Entrada autorizada') {
        dadosAtualizacao['autorizadoEm'] = FieldValue.serverTimestamp();
        dadosAtualizacao['recusadoEm'] = FieldValue.delete();
        dadosAtualizacao['motivoRecusa'] = FieldValue.delete();
      }

      if (novoStatus == 'Entrada recusada') {
        dadosAtualizacao['recusadoEm'] = FieldValue.serverTimestamp();
        dadosAtualizacao['autorizadoEm'] = FieldValue.delete();
        dadosAtualizacao['motivoRecusa'] = motivoRecusa;
      }

      await referencia.update(dadosAtualizacao);

      await InAppNotificationsRepository.notificarAdministradores(
        titulo: novoStatus == 'Entrada autorizada'
            ? 'Acesso autorizado pelo morador'
            : 'Acesso recusado pelo morador',
        mensagem:
            '${dadosRegistro['moradorNome'] ?? 'O morador'} respondeu ao acesso de '
            '${dadosRegistro['nomeVisitante'] ?? 'visitante'}.'
            '${motivoRecusa?.trim().isNotEmpty == true ? ' Motivo: ${motivoRecusa!.trim()}.' : ''}',
        tipo: 'visitante_admin',
        referenciaId: referencia.id,
      );

      if (mounted) {
        showSuccess(context, 'Status atualizado para $novoStatus.');
      }
      return true;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao atualizar autorização.'),
          ),
        );
      }
      return false;
    }
  }

  Future<void> _recusarAcesso(
    DocumentReference<Map<String, dynamic>> referencia,
  ) async {
    final motivoController = TextEditingController();
    bool salvando = false;

    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              return AlertDialog(
                title: const Text('Recusar acesso'),
                content: TextField(
                  controller: motivoController,
                  enabled: !salvando,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Motivo da recusa',
                    hintText: 'Informe o motivo para a portaria',
                    border: OutlineInputBorder(),
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
                            final motivo = motivoController.text.trim();

                            if (motivo.isEmpty) {
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                const SnackBar(
                                  content: Text('Informe o motivo da recusa.'),
                                ),
                              );
                              return;
                            }

                            setDialogState(() {
                              salvando = true;
                            });

                            final atualizada = await _atualizarStatus(
                              referencia,
                              'Entrada recusada',
                              motivo,
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
                        : const Text('Confirmar recusa'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      motivoController.dispose();
    }
  }

  Widget _cardAcesso(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final dados = doc.data();

    final nomeVisitante = dados['nomeVisitante']?.toString() ?? 'Visitante';
    final tipoAcesso = dados['tipoAcesso']?.toString() ?? 'Acesso';
    final observacao = dados['observacao']?.toString() ?? '';
    final status = effectiveVisitorStatus(dados);
    final motivoRecusa = dados['motivoRecusa']?.toString().trim() ?? '';
    final criadoEm = dados['criadoEm'];
    final dataHoraPrevista = dados['dataHoraPrevista'];
    final validoAte = dados['validoAte'];

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: defaultCardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  tipoAcesso == 'Entrega'
                      ? Icons.inventory_2_outlined
                      : Icons.person_outline,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    nomeVisitante,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              observacao.trim().isEmpty
                  ? 'Solicitação de acesso enviada pela portaria.'
                  : observacao,
              style: const TextStyle(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Tipo: $tipoAcesso\n'
              '${dataHoraPrevista is Timestamp ? 'Previsto para: ${_formatarData(dataHoraPrevista)}\n' : ''}'
              '${validoAte is Timestamp ? 'Válido até: ${_formatarData(validoAte)}\n' : ''}'
              'Solicitado em: ${_formatarData(criadoEm)}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            StatusChip(status: status),
            if (status == 'Entrada recusada' && motivoRecusa.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1F2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Motivo da recusa: $motivoRecusa',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ],
            if (status == 'Aguardando autorização') ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _atualizarStatus(
                        doc.reference,
                        'Entrada autorizada',
                        null,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                      ),
                      child: const Text(
                        'Autorizar',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _recusarAcesso(doc.reference),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                      ),
                      child: const Text(
                        'Recusar',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _listaAcessos() {
    final usuario = FirebaseAuth.instance.currentUser;

    if (usuario == null) {
      return const InfoCard(
        title: 'Usuário não autenticado',
        description: 'Faça login novamente para visualizar seus acessos.',
        footer: 'Visitantes',
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('acessos_visitantes')
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
            title: 'Erro ao carregar visitantes',
            description: 'Não foi possível carregar suas autorizações.',
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
            title: 'Nenhuma solicitação de acesso',
            description:
                'Quando a portaria registrar um visitante ou entrega para você, a solicitação aparecerá aqui.',
            footer: 'Aguardando novos registros',
          );
        }

        final acessosAtivos = documentos.where((doc) {
          final status = effectiveVisitorStatus(doc.data());
          return status == 'Aguardando autorização' ||
              status == 'Entrada autorizada';
        }).toList();
        final historico = documentos.where((doc) {
          final status = effectiveVisitorStatus(doc.data());
          return status != 'Aguardando autorização' &&
              status != 'Entrada autorizada';
        }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (acessosAtivos.isNotEmpty) ...[
              RecordSectionHeader(
                title: 'Aguardando ação',
                count: acessosAtivos.length,
                icon: Icons.notifications_active_outlined,
              ),
              ...acessosAtivos.map(_cardAcesso),
            ],
            if (historico.isNotEmpty) ...[
              if (acessosAtivos.isNotEmpty) const SizedBox(height: 8),
              RecordSectionHeader(
                title: 'Histórico',
                count: historico.length,
                icon: Icons.history,
              ),
              ...historico.map(_cardAcesso),
            ],
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BaseScreen(
      title: 'Visitantes',
      subtitle: 'Gerencie autorizações de acesso',
      children: [
        _listaAcessos(),
      ],
    );
  }
}
