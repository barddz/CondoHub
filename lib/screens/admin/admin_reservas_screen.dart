import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_helpers.dart';
import '../../core/in_app_notifications_repository.dart';
import '../../core/reservation_slot.dart';
import '../../core/reservation_status.dart';
import '../../widgets/base_screen.dart';
import '../../widgets/info_card.dart';
import '../../widgets/list_category_filter.dart';
import '../../widgets/status_chip.dart';
import 'admin_areas_reserva_screen.dart';

class AdminReservasScreen extends StatefulWidget {
  const AdminReservasScreen({super.key});

  @override
  State<AdminReservasScreen> createState() => _AdminReservasScreenState();
}

class _AdminReservasScreenState extends State<AdminReservasScreen> {
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
    String? motivoRecusa,
  ) async {
    try {
      final firestore = FirebaseFirestore.instance;
      Map<String, dynamic>? dadosReserva;
      final dadosStatus = <String, dynamic>{
        'status': novoStatus,
        'atualizadoEm': FieldValue.serverTimestamp(),
        'motivoRecusa':
            novoStatus == 'Recusada' ? motivoRecusa : FieldValue.delete(),
        'decididoEm': novoStatus == 'Em análise'
            ? FieldValue.delete()
            : FieldValue.serverTimestamp(),
      };

      await firestore.runTransaction((transaction) async {
        final reservaSnapshot = await transaction.get(referencia);

        if (!reservaSnapshot.exists) {
          throw StateError('Reserva não encontrada.');
        }

        final dados = reservaSnapshot.data()!;
        dadosReserva = dados;
        final area = dados['area']?.toString() ?? '';
        final areaId = dados['areaId']?.toString() ?? '';
        final dataChave = dados['dataChave']?.toString() ?? '';
        final horario = dados['horario']?.toString() ?? '';

        if (area.isEmpty || dataChave.isEmpty || horario.isEmpty) {
          transaction.update(referencia, dadosStatus);
          return;
        }

        final slotRef = firestore.collection('reservas_horarios').doc(
              reservationSlotId(
                area: areaId.isEmpty ? area : areaId,
                dataChave: dataChave,
                horario: horario,
              ),
            );
        final slotSnapshot = await transaction.get(slotRef);
        final reservaNoSlot = slotSnapshot.data()?['reservaId'];

        if (novoStatus == 'Recusada') {
          if (reservaNoSlot == referencia.id) {
            transaction.delete(slotRef);
          }
        } else {
          if (reservaNoSlot is String &&
              reservaNoSlot.isNotEmpty &&
              reservaNoSlot != referencia.id) {
            final outraReservaSnapshot = await transaction.get(
              firestore.collection('reservas').doc(reservaNoSlot),
            );
            final outroStatus = outraReservaSnapshot.data()?['status'];

            if (outraReservaSnapshot.exists &&
                (outroStatus == 'Em análise' || outroStatus == 'Aprovada')) {
              throw const ReservaAdminConflitoException();
            }
          }

          transaction.set(slotRef, {
            'reservaId': referencia.id,
            if (areaId.isNotEmpty) 'areaId': areaId,
            'area': area,
            'dataChave': dataChave,
            'horario': horario,
            'status': novoStatus,
            'atualizadoEm': FieldValue.serverTimestamp(),
          });
        }

        transaction.update(referencia, dadosStatus);
      });

      final moradorId = dadosReserva?['moradorId']?.toString() ?? '';
      final area = dadosReserva?['area']?.toString() ?? 'área comum';

      if (novoStatus == 'Aprovada') {
        await InAppNotificationsRepository.notificarMorador(
          moradorId: moradorId,
          titulo: 'Reserva aprovada',
          mensagem: 'Sua reserva de $area foi aprovada.',
          tipo: 'reserva',
          referenciaId: referencia.id,
        );
      } else if (novoStatus == 'Recusada') {
        final complemento = motivoRecusa?.trim().isNotEmpty == true
            ? ' Motivo: ${motivoRecusa!.trim()}'
            : '';
        await InAppNotificationsRepository.notificarMorador(
          moradorId: moradorId,
          titulo: 'Reserva recusada',
          mensagem: 'Sua reserva de $area foi recusada.$complemento',
          tipo: 'reserva',
          referenciaId: referencia.id,
        );
      }

      if (context.mounted) {
        showSuccess(context, 'Reserva atualizada para $novoStatus.');
      }
      return true;
    } on ReservaAdminConflitoException {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Este horário já está vinculado a outra reserva ativa.',
            ),
          ),
        );
      }
      return false;
    } catch (_) {
      if (context.mounted) {
        showError(context, 'Erro ao atualizar reserva.');
      }
      return false;
    }
  }

  Future<void> _solicitarMotivoRecusa(
    BuildContext context,
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
                title: const Text('Recusar reserva'),
                content: TextField(
                  controller: motivoController,
                  enabled: !salvando,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Motivo da recusa',
                    hintText: 'Informe o motivo para o morador',
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
                              context,
                              referencia,
                              'Recusada',
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

  Future<void> _excluirReserva(
    BuildContext context,
    DocumentReference<Map<String, dynamic>> referencia,
  ) async {
    try {
      final firestore = FirebaseFirestore.instance;

      await firestore.runTransaction((transaction) async {
        final reservaSnapshot = await transaction.get(referencia);

        if (!reservaSnapshot.exists) {
          throw StateError('Reserva não encontrada.');
        }

        final dados = reservaSnapshot.data()!;
        final status = dados['status']?.toString() ?? '';

        if (!reservaPodeSerExcluidaPeloAdmin(status)) {
          throw const ReservaNaoPodeSerExcluidaException();
        }

        final area = dados['area']?.toString() ?? '';
        final areaId = dados['areaId']?.toString() ?? '';
        final dataChave = dados['dataChave']?.toString() ?? '';
        final horario = dados['horario']?.toString() ?? '';

        if (area.isNotEmpty && dataChave.isNotEmpty && horario.isNotEmpty) {
          final slotRef = firestore.collection('reservas_horarios').doc(
                reservationSlotId(
                  area: areaId.isEmpty ? area : areaId,
                  dataChave: dataChave,
                  horario: horario,
                ),
              );
          final slotSnapshot = await transaction.get(slotRef);

          if (slotSnapshot.data()?['reservaId'] == referencia.id) {
            transaction.delete(slotRef);
          }
        }

        transaction.delete(referencia);
      });

      if (context.mounted) {
        showSuccess(context, 'Reserva excluída.');
      }
    } on ReservaNaoPodeSerExcluidaException {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'A reserva precisa estar aprovada, recusada ou cancelada para ser excluída.',
            ),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível excluir a reserva.'),
          ),
        );
      }
    }
  }

  Future<void> _confirmarExclusao(
    BuildContext context,
    DocumentReference<Map<String, dynamic>> referencia,
    String status,
  ) async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Excluir reserva'),
          content: Text(
            status == 'Aprovada'
                ? 'Deseja excluir esta reserva aprovada? O horário voltará a ficar disponível.'
                : status == 'Cancelada'
                    ? 'Deseja excluir esta reserva cancelada?'
                    : 'Deseja excluir esta reserva recusada?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
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

    if (confirmou == true && context.mounted) {
      await _excluirReserva(context, referencia);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BaseScreen(
      title: 'Reservas',
      subtitle: 'Solicitações de reserva dos moradores',
      children: [
        InfoCard(
          title: 'Áreas e horários',
          description:
              'Crie áreas e defina os dias e horários disponíveis para reserva.',
          footer: 'Configurar áreas',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AdminAreasReservaScreen(),
              ),
            );
          },
        ),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('reservas').snapshots(),
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
                title: 'Erro ao carregar reservas',
                description: 'Não foi possível carregar as reservas.',
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
                title: 'Nenhuma reserva encontrada',
                description:
                    'Quando um morador solicitar uma reserva, ela aparecerá nesta tela.',
                footer: 'Aguardando novas solicitações',
              );
            }

            final reservasFiltradas = documentos.where((doc) {
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
                    'Aprovada',
                    'Recusada',
                    'Cancelada',
                  ],
                  onChanged: (value) {
                    setState(() {
                      statusSelecionado = value ?? 'Todos';
                    });
                  },
                ),
                const SizedBox(height: 16),
                if (reservasFiltradas.isEmpty)
                  const InfoCard(
                    title: 'Nenhum resultado encontrado',
                    description: 'Não há reservas com o status selecionado.',
                    footer: 'Selecione outra categoria para continuar',
                  )
                else
                  ...reservasFiltradas.map((doc) {
                    final dados = doc.data();

                    final area = dados['area'] ?? 'Área não informada';
                    final data = dados['data'] ?? 'Data não informada';
                    final horario = dados['horario'] ?? 'Horário não informado';
                    final status = dados['status'] ?? 'Em análise';
                    final moradorNome =
                        dados['moradorNome'] ?? 'Morador não informado';
                    final moradorEmail =
                        dados['moradorEmail'] ?? 'E-mail não informado';
                    final criadoEm = dados['criadoEm'];
                    final motivoRecusa =
                        dados['motivoRecusa']?.toString().trim() ?? '';

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: defaultCardDecoration(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              area,
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
                              'Data: $data\n'
                              'Horário: $horario',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Solicitada em: ${_formatarData(criadoEm)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            StatusChip(status: status),
                            if (status == 'Recusada' &&
                                motivoRecusa.isNotEmpty) ...[
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
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                            if (status != 'Cancelada') ...[
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                value: ['Em análise', 'Aprovada', 'Recusada']
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
                                    value: 'Aprovada',
                                    child: Text('Aprovada'),
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

                                  if (novoStatus == 'Recusada') {
                                    _solicitarMotivoRecusa(
                                      context,
                                      doc.reference,
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
                            ],
                            if (status == 'Aprovada' ||
                                status == 'Recusada' ||
                                status == 'Cancelada') ...[
                              const SizedBox(height: 12),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: () => _confirmarExclusao(
                                    context,
                                    doc.reference,
                                    status,
                                  ),
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Color(0xFFDC2626),
                                  ),
                                  label: const Text(
                                    'Excluir reserva',
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

class ReservaAdminConflitoException implements Exception {
  const ReservaAdminConflitoException();
}

class ReservaNaoPodeSerExcluidaException implements Exception {
  const ReservaNaoPodeSerExcluidaException();
}
