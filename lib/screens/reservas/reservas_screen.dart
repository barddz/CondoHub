import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_helpers.dart';
import '../../core/in_app_notifications_repository.dart';
import '../../core/reservation_areas_repository.dart';
import '../../core/reservation_slot.dart';
import '../../core/reservation_status.dart';
import '../../models/reserva_area.dart';
import '../../widgets/base_screen.dart';
import '../../widgets/info_card.dart';
import '../../widgets/record_section_header.dart';
import '../../widgets/reserva_card.dart';
import '../../widgets/status_chip.dart';

class ReservasScreen extends StatefulWidget {
  const ReservasScreen({super.key});

  @override
  State<ReservasScreen> createState() => _ReservasScreenState();
}

class _ReservasScreenState extends State<ReservasScreen> {
  String _formatarData(DateTime data) {
    final dia = data.day.toString().padLeft(2, '0');
    final mes = data.month.toString().padLeft(2, '0');
    final ano = data.year.toString();

    return '$dia/$mes/$ano';
  }

  String _formatarDataChave(DateTime data) {
    final mes = data.month.toString().padLeft(2, '0');
    final dia = data.day.toString().padLeft(2, '0');

    return '${data.year}-$mes-$dia';
  }

  String _formatarDataFirestore(dynamic valor) {
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

  Future<void> _cancelarReserva(
    DocumentReference<Map<String, dynamic>> referencia,
  ) async {
    final usuario = FirebaseAuth.instance.currentUser;

    if (usuario == null) {
      showWarning(context, 'Faça login novamente para cancelar a reserva.');
      return;
    }

    try {
      final firestore = FirebaseFirestore.instance;
      final reservaAntes = await referencia.get();
      final dadosAntes = reservaAntes.data() ?? <String, dynamic>{};

      await firestore.runTransaction((transaction) async {
        final reservaSnapshot = await transaction.get(referencia);

        if (!reservaSnapshot.exists) {
          throw const ReservaCancelamentoNaoPermitidoException();
        }

        final dados = reservaSnapshot.data()!;
        final moradorId = dados['moradorId']?.toString() ?? '';
        final status = dados['status']?.toString() ?? '';

        if (moradorId != usuario.uid || !reservaPodeSerCancelada(status)) {
          throw const ReservaCancelamentoNaoPermitidoException();
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

        transaction.update(referencia, {
          'status': statusReservaCancelada,
          'canceladoEm': FieldValue.serverTimestamp(),
          'atualizadoEm': FieldValue.serverTimestamp(),
        });
      });

      await InAppNotificationsRepository.notificarAdministradores(
        titulo: 'Reserva cancelada pelo morador',
        mensagem:
            '${dadosAntes['moradorNome'] ?? 'Um morador'} cancelou a reserva de '
            '${dadosAntes['area'] ?? 'área comum'} em '
            '${dadosAntes['data'] ?? 'data não informada'}, '
            '${dadosAntes['horario'] ?? 'horário não informado'}.',
        tipo: 'reserva_admin',
        referenciaId: referencia.id,
      );

      if (mounted) {
        showSuccess(context, 'Reserva cancelada e horário liberado.');
      }
    } on ReservaCancelamentoNaoPermitidoException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Apenas reservas em análise ou aprovadas podem ser canceladas.',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível cancelar a reserva.'),
          ),
        );
      }
    }
  }

  Future<void> _confirmarCancelamento(
    DocumentReference<Map<String, dynamic>> referencia,
    String status,
  ) async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Cancelar reserva'),
          content: Text(
            status == statusReservaAprovada
                ? 'Deseja cancelar esta reserva aprovada? O horário voltará a ficar disponível.'
                : 'Deseja cancelar esta solicitação? O horário voltará a ficar disponível.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Manter reserva'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
              ),
              child: const Text(
                'Cancelar reserva',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );

    if (confirmou == true && mounted) {
      await _cancelarReserva(referencia);
    }
  }

  bool _reservaPertenceAArea(
    Map<String, dynamic> dados,
    ReservaArea area,
  ) {
    if (dados['areaId'] == area.id) {
      return true;
    }

    if (dados['areaId'] != null) {
      return false;
    }

    final nomesLegados = <String>{area.nome};
    for (final areaPadrao in areasPadraoReserva) {
      if (areaPadrao.id == area.id) {
        nomesLegados.add(areaPadrao.nome);
      }
    }

    return nomesLegados.contains(dados['area']);
  }

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

  Future<List<String>> _buscarHorariosOcupados(
    ReservaArea area,
    DateTime data,
  ) async {
    final chaveData = _formatarDataChave(data);

    final snapshot = await FirebaseFirestore.instance
        .collection('reservas')
        .where('dataChave', isEqualTo: chaveData)
        .get();

    final horariosFirestore = snapshot.docs
        .where((doc) {
          final dados = doc.data();
          final status = dados['status'];
          final mesmaArea = _reservaPertenceAArea(dados, area);
          return mesmaArea && (status == 'Em análise' || status == 'Aprovada');
        })
        .map((doc) => doc.data()['horario'])
        .whereType<String>()
        .toList();

    return horariosFirestore.toSet().toList();
  }

  Future<void> _salvarReservaNoFirestore({
    required ReservaArea area,
    required DateTime data,
    required String horario,
  }) async {
    final usuario = FirebaseAuth.instance.currentUser;

    if (usuario == null) {
      throw Exception('Usuário não autenticado.');
    }

    final firestore = FirebaseFirestore.instance;
    final dataChave = _formatarDataChave(data);
    final areaSnapshot =
        await ReservationAreasRepository.areas.doc(area.id).get();
    ReservaArea areaAtual = area;

    if (areaSnapshot.exists) {
      areaAtual = ReservaArea.fromSnapshot(areaSnapshot);
    } else if (await ReservationAreasRepository.areasForamInicializadas()) {
      throw const AreaReservaIndisponivelException();
    }

    final configuracaoValida = areaAtual.disponivelParaReserva &&
        areaAtual.diasSemanaDisponiveis.contains(data.weekday) &&
        areaAtual.horariosDisponiveis.contains(horario);

    if (!configuracaoValida) {
      throw const AreaReservaIndisponivelException();
    }

    final moradorNome = await _buscarNomeMorador(usuario);

    final conflitosExistentes = await firestore
        .collection('reservas')
        .where('dataChave', isEqualTo: dataChave)
        .get();

    final horarioJaOcupado = conflitosExistentes.docs.any((doc) {
      final dados = doc.data();
      final status = dados['status'];
      final mesmaArea = _reservaPertenceAArea(dados, areaAtual);
      return mesmaArea &&
          dados['horario'] == horario &&
          (status == 'Em análise' || status == 'Aprovada');
    });

    if (horarioJaOcupado) {
      throw const ReservaIndisponivelException();
    }

    final reservaRef = firestore.collection('reservas').doc();
    final slotRef = firestore.collection('reservas_horarios').doc(
          reservationSlotId(
            area: areaAtual.id,
            dataChave: dataChave,
            horario: horario,
          ),
        );

    final dadosReserva = <String, dynamic>{
      'moradorId': usuario.uid,
      'moradorNome': moradorNome,
      'moradorEmail': usuario.email,
      'areaId': areaAtual.id,
      'area': areaAtual.nome,
      'data': _formatarData(data),
      'dataChave': dataChave,
      'horario': horario,
      'status': 'Em análise',
      'criadoEm': FieldValue.serverTimestamp(),
      'atualizadoEm': FieldValue.serverTimestamp(),
    };

    await firestore.runTransaction((transaction) async {
      final slotSnapshot = await transaction.get(slotRef);

      if (slotSnapshot.exists) {
        final reservaExistenteId = slotSnapshot.data()?['reservaId'];

        if (reservaExistenteId is String && reservaExistenteId.isNotEmpty) {
          final reservaExistenteSnapshot = await transaction.get(
            firestore.collection('reservas').doc(reservaExistenteId),
          );
          final statusExistente = reservaExistenteSnapshot.data()?['status'];

          if (reservaExistenteSnapshot.exists &&
              (statusExistente == 'Em análise' ||
                  statusExistente == 'Aprovada')) {
            throw const ReservaIndisponivelException();
          }
        }
      }

      transaction.set(reservaRef, dadosReserva);
      transaction.set(slotRef, {
        'reservaId': reservaRef.id,
        'areaId': areaAtual.id,
        'area': areaAtual.nome,
        'dataChave': dataChave,
        'horario': horario,
        'status': 'Em análise',
        'atualizadoEm': FieldValue.serverTimestamp(),
      });
    });

    await InAppNotificationsRepository.notificarAdministradores(
      titulo: 'Nova reserva para análise',
      mensagem: '$moradorNome solicitou ${areaAtual.nome} para '
          '${_formatarData(data)} às $horario.',
      tipo: 'reserva_admin',
      referenciaId: reservaRef.id,
    );
  }

  DateTime _proximaDataDisponivel(ReservaArea area) {
    final hoje = DateTime.now();

    for (var dias = 1; dias <= 60; dias++) {
      final data = hoje.add(Duration(days: dias));
      if (area.diasSemanaDisponiveis.contains(data.weekday)) {
        return data;
      }
    }

    return hoje.add(const Duration(days: 1));
  }

  Future<void> _abrirFormularioReserva(ReservaArea area) async {
    DateTime? dataSelecionada;
    String? horarioSelecionado;
    List<String> horariosOcupados = [];
    bool carregandoHorarios = false;
    bool enviando = false;

    final horarios = area.horariosDisponiveis;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            Future<void> selecionarData() async {
              final data = await showDatePicker(
                context: dialogContext,
                initialDate: _proximaDataDisponivel(area),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(
                  const Duration(days: 60),
                ),
                selectableDayPredicate: (data) =>
                    area.diasSemanaDisponiveis.contains(data.weekday),
              );

              if (data == null) {
                return;
              }

              setDialogState(() {
                dataSelecionada = data;
                horarioSelecionado = null;
                horariosOcupados = [];
                carregandoHorarios = true;
              });

              try {
                final ocupados = await _buscarHorariosOcupados(area, data);

                if (!dialogContext.mounted) {
                  return;
                }

                setDialogState(() {
                  horariosOcupados = ocupados;
                  carregandoHorarios = false;
                });
              } catch (_) {
                if (!dialogContext.mounted) {
                  return;
                }

                setDialogState(() {
                  carregandoHorarios = false;
                });
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Não foi possível consultar os horários. Tente novamente.',
                    ),
                  ),
                );
              }
            }

            return AlertDialog(
              title: const Text('Solicitar reserva'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    area.nome,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: carregandoHorarios || enviando
                          ? null
                          : selecionarData,
                      icon: const Icon(Icons.calendar_today),
                      label: Text(
                        dataSelecionada == null
                            ? 'Selecionar data'
                            : _formatarData(dataSelecionada!),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (carregandoHorarios)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else
                    DropdownButtonFormField<String>(
                      value: horarioSelecionado,
                      decoration: const InputDecoration(
                        labelText: 'Horário',
                        border: OutlineInputBorder(),
                      ),
                      items: horarios.map((horario) {
                        final ocupado = horariosOcupados.contains(horario);

                        return DropdownMenuItem(
                          value: horario,
                          enabled: !ocupado,
                          child: Text(
                            ocupado ? '$horario  • Ocupado' : horario,
                            style: TextStyle(
                              color: ocupado
                                  ? AppColors.textSecondary
                                  : Colors.black,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: dataSelecionada == null || enviando
                          ? null
                          : (valor) {
                              if (valor == null ||
                                  horariosOcupados.contains(valor)) {
                                return;
                              }

                              setDialogState(() {
                                horarioSelecionado = valor;
                              });
                            },
                    ),
                  if (dataSelecionada != null &&
                      horariosOcupados.isNotEmpty &&
                      !carregandoHorarios) ...[
                    const SizedBox(height: 8),
                    Text(
                      '${horariosOcupados.length} horário(s) indisponível(is) nessa data.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
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
                          if (dataSelecionada == null ||
                              horarioSelecionado == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Selecione a data e o horário.'),
                              ),
                            );
                            return;
                          }

                          setDialogState(() {
                            enviando = true;
                          });

                          try {
                            await _salvarReservaNoFirestore(
                              area: area,
                              data: dataSelecionada!,
                              horario: horarioSelecionado!,
                            );

                            if (!dialogContext.mounted || !mounted) {
                              return;
                            }

                            Navigator.pop(dialogContext);

                            showSuccess(
                              context,
                              'Solicitação de reserva enviada para ${area.nome}.',
                            );
                          } on AreaReservaIndisponivelException {
                            if (!mounted || !dialogContext.mounted) {
                              return;
                            }

                            Navigator.pop(dialogContext);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'A disponibilidade desta área foi alterada. Consulte as opções novamente.',
                                ),
                              ),
                            );
                          } on ReservaIndisponivelException {
                            if (dialogContext.mounted) {
                              setDialogState(() {
                                enviando = false;
                                horarioSelecionado = null;
                              });
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Este horário acabou de ser reservado. Escolha outro horário.',
                                  ),
                                ),
                              );
                            }
                          } catch (_) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Erro ao enviar reserva. Tente novamente.',
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
                          'Confirmar',
                          style: TextStyle(color: Colors.white),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _cardHistoricoReserva(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final dados = doc.data();
    final area = dados['area'] ?? 'Área não informada';
    final data = dados['data'] ?? 'Data não informada';
    final horario = dados['horario'] ?? 'Horário não informado';
    final status = dados['status']?.toString() ?? 'Em análise';
    final criadoEm = dados['criadoEm'];
    final motivoRecusa = dados['motivoRecusa']?.toString().trim() ?? '';
    final descricaoMotivo = status == 'Recusada' && motivoRecusa.isNotEmpty
        ? '\n\nMotivo da recusa: $motivoRecusa'
        : '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InfoCard(
        title: area,
        description: 'Data: $data\nHorário: $horario$descricaoMotivo',
        footer: 'Solicitada em ${_formatarDataFirestore(criadoEm)}',
        badge: StatusChip(status: status),
        action: reservaPodeSerCancelada(status)
            ? Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _confirmarCancelamento(
                    doc.reference,
                    status,
                  ),
                  icon: const Icon(
                    Icons.cancel_outlined,
                    color: Color(0xFFDC2626),
                  ),
                  label: const Text(
                    'Cancelar reserva',
                    style: TextStyle(color: Color(0xFFDC2626)),
                  ),
                ),
              )
            : null,
      ),
    );
  }

  Widget _historicoReservas() {
    final usuario = FirebaseAuth.instance.currentUser;

    if (usuario == null) {
      return const InfoCard(
        title: 'Usuário não autenticado',
        description: 'Faça login novamente para visualizar suas reservas.',
        footer: 'Reservas',
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('reservas')
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
            title: 'Erro ao carregar reservas',
            description: 'Não foi possível carregar suas reservas.',
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
            title: 'Minhas reservas',
            description:
                'Nenhuma reserva solicitada até o momento. As reservas abertas aparecerão aqui.',
            footer: 'Aguardando novas solicitações',
          );
        }

        final reservasAtivas = documentos.where((doc) {
          final status = doc.data()['status']?.toString() ?? 'Em análise';
          return reservaPodeSerCancelada(status);
        }).toList();
        final historico = documentos.where((doc) {
          final status = doc.data()['status']?.toString() ?? 'Em análise';
          return !reservaPodeSerCancelada(status);
        }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (reservasAtivas.isNotEmpty) ...[
              RecordSectionHeader(
                title: 'Próximas reservas',
                count: reservasAtivas.length,
                icon: Icons.event_available_outlined,
              ),
              ...reservasAtivas.map(_cardHistoricoReserva),
            ],
            if (historico.isNotEmpty) ...[
              if (reservasAtivas.isNotEmpty) const SizedBox(height: 8),
              RecordSectionHeader(
                title: 'Histórico',
                count: historico.length,
                icon: Icons.history,
              ),
              ...historico.map(_cardHistoricoReserva),
            ],
          ],
        );
      },
    );
  }

  Widget _cardsAreas(List<ReservaArea> areas) {
    final areasOrdenadas = [...areas]..sort((a, b) => a.nome.compareTo(b.nome));

    return Column(
      children: areasOrdenadas.map((area) {
        final descricaoBase = area.descricao.isEmpty
            ? 'Área comum do condomínio.'
            : area.descricao;
        final descricaoDisponibilidade = area.disponivelParaReserva
            ? '${resumoDiasSemana(area.diasSemanaDisponiveis)} • '
                '${area.horariosDisponiveis.length} horário(s) por dia'
            : 'Temporariamente indisponível para novas reservas';

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: ReservaCard(
            title: area.nome,
            description: '$descricaoBase\n$descricaoDisponibilidade.',
            disponivel: area.disponivelParaReserva,
            onReservar: () => _abrirFormularioReserva(area),
          ),
        );
      }).toList(),
    );
  }

  Widget _listaAreasReserva() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: ReservationAreasRepository.areas.snapshots(),
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
            title: 'Não foi possível carregar as áreas',
            description: 'Tente novamente mais tarde.',
            footer: 'Reservas',
            footerColor: Color(0xFFDC2626),
          );
        }

        final areas =
            (snapshot.data?.docs ?? []).map(ReservaArea.fromSnapshot).toList();

        if (areas.isNotEmpty) {
          return _cardsAreas(areas);
        }

        return FutureBuilder<bool>(
          future: ReservationAreasRepository.areasForamInicializadas(),
          builder: (context, configuracaoSnapshot) {
            if (configuracaoSnapshot.connectionState ==
                ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              );
            }

            if (configuracaoSnapshot.hasError) {
              return const InfoCard(
                title: 'Não foi possível carregar as áreas',
                description: 'Tente novamente mais tarde.',
                footer: 'Reservas',
                footerColor: Color(0xFFDC2626),
              );
            }

            if (configuracaoSnapshot.data == true) {
              return const InfoCard(
                title: 'Nenhuma área disponível',
                description:
                    'A administração ainda não disponibilizou áreas para reserva.',
                footer: 'Aguardando novas áreas',
              );
            }

            return _cardsAreas(areasPadraoReserva);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BaseScreen(
      title: 'Reservas',
      subtitle: 'Reserve áreas comuns do condomínio',
      children: [
        _listaAreasReserva(),
        _historicoReservas(),
      ],
    );
  }
}

class ReservaIndisponivelException implements Exception {
  const ReservaIndisponivelException();
}

class AreaReservaIndisponivelException implements Exception {
  const AreaReservaIndisponivelException();
}

class ReservaCancelamentoNaoPermitidoException implements Exception {
  const ReservaCancelamentoNaoPermitidoException();
}
