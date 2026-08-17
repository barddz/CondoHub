import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_helpers.dart';
import '../../core/reservation_areas_repository.dart';
import '../../models/reserva_area.dart';
import '../../widgets/base_screen.dart';
import '../../widgets/info_card.dart';

class AdminAreasReservaScreen extends StatefulWidget {
  const AdminAreasReservaScreen({super.key});

  @override
  State<AdminAreasReservaScreen> createState() =>
      _AdminAreasReservaScreenState();
}

class _AdminAreasReservaScreenState extends State<AdminAreasReservaScreen> {
  late Future<void> _inicializacaoFuture;

  @override
  void initState() {
    super.initState();
    _inicializacaoFuture = ReservationAreasRepository.garantirAreasPadrao();
  }

  int _minutosDoHorario(String horario) {
    final partes = horario.split(':');
    return int.parse(partes[0]) * 60 + int.parse(partes[1]);
  }

  bool _horarioValido(String horario) {
    final formato = RegExp(
      r'^([01]\d|2[0-3]):[0-5]\d - ([01]\d|2[0-3]):[0-5]\d$',
    );

    if (!formato.hasMatch(horario)) {
      return false;
    }

    final limites = horario.split(' - ');
    return _minutosDoHorario(limites[0]) < _minutosDoHorario(limites[1]);
  }

  Future<void> _abrirFormulario({ReservaArea? area}) async {
    final nomeController = TextEditingController(text: area?.nome ?? '');
    final descricaoController = TextEditingController(
      text: area?.descricao ?? '',
    );
    final novoHorarioController = TextEditingController();

    final diasSelecionados = <int>{
      ...(area?.diasSemanaDisponiveis ?? <int>[]),
    };
    final horariosSelecionados = <String>{
      ...(area?.horariosDisponiveis ?? horariosPadraoReserva),
    };
    bool ativa = area?.ativa ?? true;
    bool salvando = false;

    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              final horariosExibidos = <String>{
                ...horariosPadraoReserva,
                ...horariosSelecionados,
              }.toList()
                ..sort();

              void adicionarHorario() {
                final horario = novoHorarioController.text.trim();

                if (!_horarioValido(horario)) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Informe um horário válido, como 12:00 - 14:00.',
                      ),
                    ),
                  );
                  return;
                }

                setDialogState(() {
                  horariosSelecionados.add(horario);
                  novoHorarioController.clear();
                });
              }

              return AlertDialog(
                title: Text(area == null ? 'Nova área' : 'Editar área'),
                content: SizedBox(
                  width: 520,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: nomeController,
                          enabled: !salvando,
                          decoration: const InputDecoration(
                            labelText: 'Nome da área',
                            hintText: 'Ex: Piscina',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: descricaoController,
                          enabled: !salvando,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Descrição',
                            hintText: 'Ex: Espaço de lazer para moradores',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Disponível para reservas'),
                          subtitle: const Text(
                            'Desative para suspender novas solicitações.',
                          ),
                          value: ativa,
                          onChanged: salvando
                              ? null
                              : (valor) {
                                  setDialogState(() {
                                    ativa = valor;
                                  });
                                },
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Dias disponíveis',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: nomesDiasSemana.entries.map((entry) {
                            return FilterChip(
                              label: Text(entry.value),
                              selected: diasSelecionados.contains(entry.key),
                              onSelected: salvando
                                  ? null
                                  : (selecionado) {
                                      setDialogState(() {
                                        if (selecionado) {
                                          diasSelecionados.add(entry.key);
                                        } else {
                                          diasSelecionados.remove(entry.key);
                                        }
                                      });
                                    },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Horários disponíveis',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: horariosExibidos.map((horario) {
                            return FilterChip(
                              label: Text(horario),
                              selected: horariosSelecionados.contains(horario),
                              onSelected: salvando
                                  ? null
                                  : (selecionado) {
                                      setDialogState(() {
                                        if (selecionado) {
                                          horariosSelecionados.add(horario);
                                        } else {
                                          horariosSelecionados.remove(horario);
                                        }
                                      });
                                    },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TextField(
                                controller: novoHorarioController,
                                enabled: !salvando,
                                decoration: const InputDecoration(
                                  labelText: 'Adicionar outro horário',
                                  hintText: '12:00 - 14:00',
                                  border: OutlineInputBorder(),
                                ),
                                onSubmitted: (_) => adicionarHorario(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filled(
                              tooltip: 'Adicionar horário',
                              onPressed: salvando ? null : adicionarHorario,
                              icon: const Icon(Icons.add),
                            ),
                          ],
                        ),
                      ],
                    ),
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
                            final nome = nomeController.text.trim();
                            final descricao = descricaoController.text.trim();

                            if (nome.isEmpty || descricao.isEmpty) {
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Preencha o nome e a descrição da área.',
                                  ),
                                ),
                              );
                              return;
                            }

                            if (ativa && diasSelecionados.isEmpty) {
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Selecione pelo menos um dia disponível.',
                                  ),
                                ),
                              );
                              return;
                            }

                            if (ativa && horariosSelecionados.isEmpty) {
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Selecione pelo menos um horário disponível.',
                                  ),
                                ),
                              );
                              return;
                            }

                            setDialogState(() {
                              salvando = true;
                            });

                            try {
                              final nomeNormalizado = nome.toLowerCase();
                              final nomesIguais =
                                  await ReservationAreasRepository.areas
                                      .where(
                                        'nomeNormalizado',
                                        isEqualTo: nomeNormalizado,
                                      )
                                      .get();

                              final duplicada = nomesIguais.docs.any(
                                (doc) => doc.id != area?.id,
                              );

                              if (duplicada) {
                                if (dialogContext.mounted) {
                                  setDialogState(() {
                                    salvando = false;
                                  });
                                  ScaffoldMessenger.of(dialogContext)
                                      .showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Já existe uma área com esse nome.',
                                      ),
                                    ),
                                  );
                                }
                                return;
                              }

                              final dias = diasSelecionados.toList()..sort();
                              final horarios = horariosSelecionados.toList()
                                ..sort();
                              final areaAtualizada = ReservaArea(
                                id: area?.id ?? '',
                                nome: nome,
                                descricao: descricao,
                                ativa: ativa,
                                diasSemanaDisponiveis: dias,
                                horariosDisponiveis: horarios,
                              );

                              if (area == null) {
                                await ReservationAreasRepository.areas.add(
                                  areaAtualizada.toFirestore(
                                    incluirCriadoEm: true,
                                  ),
                                );
                              } else {
                                await ReservationAreasRepository.areas
                                    .doc(area.id)
                                    .set(
                                      areaAtualizada.toFirestore(
                                        incluirCriadoEm: false,
                                      ),
                                      SetOptions(merge: true),
                                    );
                              }

                              if (!mounted || !dialogContext.mounted) {
                                return;
                              }

                              Navigator.pop(dialogContext);
                              showSuccess(
                                context,
                                area == null
                                    ? 'Área criada com sucesso.'
                                    : 'Área atualizada com sucesso.',
                              );
                            } catch (_) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Não foi possível salvar a área.',
                                    ),
                                  ),
                                );
                              }

                              if (dialogContext.mounted) {
                                setDialogState(() {
                                  salvando = false;
                                });
                              }
                            }
                          },
                    child: salvando
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        : const Text('Salvar'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      nomeController.dispose();
      descricaoController.dispose();
      novoHorarioController.dispose();
    }
  }

  Future<void> _confirmarExclusao(ReservaArea area) async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Excluir área'),
          content: Text(
            'Deseja excluir a área “${area.nome}”? Reservas anteriores continuarão no histórico.',
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

    if (confirmou != true || !mounted) {
      return;
    }

    try {
      final reservasSnapshot =
          await FirebaseFirestore.instance.collection('reservas').get();
      final nomePadrao = areasPadraoReserva
          .where((padrao) => padrao.id == area.id)
          .map((padrao) => padrao.nome)
          .firstOrNull;
      final agora = DateTime.now();
      final hojeChave =
          '${agora.year}-${agora.month.toString().padLeft(2, '0')}-'
          '${agora.day.toString().padLeft(2, '0')}';

      final possuiReservaAtiva = reservasSnapshot.docs.any((doc) {
        final dados = doc.data();
        final status = dados['status'];
        final dataChave = dados['dataChave']?.toString();
        final pertenceAArea = dados['areaId'] == area.id ||
            dados['area'] == area.nome ||
            (nomePadrao != null && dados['area'] == nomePadrao);
        final aprovadaAindaValida = status == 'Aprovada' &&
            (dataChave == null || dataChave.compareTo(hojeChave) >= 0);

        return pertenceAArea && (status == 'Em análise' || aprovadaAindaValida);
      });

      if (possuiReservaAtiva) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Não é possível excluir uma área com reservas ativas. Recuse essas reservas primeiro.',
              ),
            ),
          );
        }
        return;
      }

      await ReservationAreasRepository.areas.doc(area.id).delete();

      if (mounted) {
        showSuccess(context, 'Área excluída.');
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível excluir a área.'),
          ),
        );
      }
    }
  }

  Widget _listaAreas() {
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
            footer: 'Configuração de reservas',
            footerColor: Color(0xFFDC2626),
          );
        }

        final areas = (snapshot.data?.docs ?? [])
            .map(ReservaArea.fromSnapshot)
            .toList()
          ..sort((a, b) => a.nome.compareTo(b.nome));

        if (areas.isEmpty) {
          return const InfoCard(
            title: 'Nenhuma área cadastrada',
            description:
                'Crie uma área para disponibilizar novos espaços aos moradores.',
            footer: 'Aguardando cadastro',
          );
        }

        return Column(
          children: areas.map((area) {
            final resumoDias = area.diasSemanaDisponiveis.isEmpty
                ? 'Nenhum dia selecionado'
                : resumoDiasSemana(area.diasSemanaDisponiveis);
            final resumoHorarios = area.horariosDisponiveis.isEmpty
                ? 'Nenhum horário selecionado'
                : area.horariosDisponiveis.join(', ');

            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: defaultCardDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            area.nome,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: area.ativa
                                ? const Color(0xFFE8F5E9)
                                : const Color(0xFFFFEBEE),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            area.ativa ? 'Ativa' : 'Inativa',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: area.ativa
                                  ? const Color(0xFF15803D)
                                  : const Color(0xFFB91C1C),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      area.descricao,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Dias: $resumoDias',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Horários: $resumoHorarios',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: () => _abrirFormulario(area: area),
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Editar'),
                        ),
                        TextButton.icon(
                          onPressed: () => _confirmarExclusao(area),
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Color(0xFFDC2626),
                          ),
                          label: const Text(
                            'Excluir',
                            style: TextStyle(color: Color(0xFFDC2626)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BaseScreen(
      title: 'Áreas de reserva',
      subtitle: 'Defina espaços, dias e horários disponíveis',
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _abrirFormulario(),
            icon: const Icon(Icons.add),
            label: const Text('Nova área'),
          ),
        ),
        FutureBuilder<void>(
          future: _inicializacaoFuture,
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
              return InfoCard(
                title: 'Não foi possível preparar as áreas',
                description: 'Tente novamente para carregar as configurações.',
                footer: 'Tentar novamente',
                footerColor: const Color(0xFFDC2626),
                onTap: () {
                  setState(() {
                    _inicializacaoFuture =
                        ReservationAreasRepository.garantirAreasPadrao();
                  });
                },
              );
            }

            return _listaAreas();
          },
        ),
      ],
    );
  }
}
