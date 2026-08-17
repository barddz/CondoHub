import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_helpers.dart';
import '../../core/in_app_notifications_repository.dart';
import '../../core/visitor_access.dart';
import '../../widgets/admin_form_section.dart';
import '../../widgets/base_screen.dart';
import '../../widgets/info_card.dart';
import '../../widgets/list_category_filter.dart';
import '../../widgets/resident_selector.dart';
import '../../widgets/status_chip.dart';

class AdminVisitantesScreen extends StatefulWidget {
  const AdminVisitantesScreen({super.key});

  @override
  State<AdminVisitantesScreen> createState() => _AdminVisitantesScreenState();
}

class _AdminVisitantesScreenState extends State<AdminVisitantesScreen> {
  final nomeVisitanteController = TextEditingController();
  final observacaoController = TextEditingController();
  ResidentOption? moradorSelecionado;
  int seletorVersion = 0;

  String tipoSelecionado = 'Visitante';
  String statusSelecionado = 'Todos';
  DateTime? dataPrevista;
  TimeOfDay? horarioPrevisto;
  int validadeHoras = 2;
  bool enviando = false;
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
    nomeVisitanteController.dispose();
    observacaoController.dispose();
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

  String _formatarDia(DateTime? data) {
    if (data == null) return 'Data';
    final dia = data.day.toString().padLeft(2, '0');
    final mes = data.month.toString().padLeft(2, '0');
    return '$dia/$mes/${data.year}';
  }

  String _formatarHorario(TimeOfDay? horario) {
    if (horario == null) return 'Horário';
    final hora = horario.hour.toString().padLeft(2, '0');
    final minuto = horario.minute.toString().padLeft(2, '0');
    return '$hora:$minuto';
  }

  DateTime? get _dataHoraPrevista {
    final data = dataPrevista;
    final horario = horarioPrevisto;
    if (data == null || horario == null) return null;
    return DateTime(
      data.year,
      data.month,
      data.day,
      horario.hour,
      horario.minute,
    );
  }

  Future<void> _selecionarDataPrevista() async {
    final agora = DateTime.now();
    final selecionada = await showDatePicker(
      context: context,
      initialDate: dataPrevista ?? agora,
      firstDate: DateTime(agora.year, agora.month, agora.day),
      lastDate: agora.add(const Duration(days: 365)),
    );
    if (selecionada != null && mounted) {
      setState(() => dataPrevista = selecionada);
    }
  }

  Future<void> _selecionarHorarioPrevisto() async {
    final selecionado = await showTimePicker(
      context: context,
      initialTime: horarioPrevisto ?? TimeOfDay.now(),
    );
    if (selecionado != null && mounted) {
      setState(() => horarioPrevisto = selecionado);
    }
  }

  Future<void> _cadastrarAcesso() async {
    final nomeVisitante = nomeVisitanteController.text.trim();
    final observacao = observacaoController.text.trim();

    if (moradorSelecionado == null || nomeVisitante.isEmpty) {
      showWarning(
          context, 'Selecione o morador e informe o nome do visitante.');
      return;
    }

    final dataHora = _dataHoraPrevista;
    if (dataHora == null) {
      showWarning(
          context, 'Informe a data e o horário previstos para o acesso.');
      return;
    }

    if (!dataHora.isAfter(DateTime.now())) {
      showWarning(
          context, 'A data e o horário previstos devem estar no futuro.');
      return;
    }

    setState(() {
      enviando = true;
    });

    try {
      final morador = moradorSelecionado!;

      final acessoRef = await FirebaseFirestore.instance
          .collection('acessos_visitantes')
          .add({
        'moradorId': morador.id,
        'moradorNome': morador.nome,
        'moradorEmail': morador.email,
        'nomeVisitante': nomeVisitante,
        'tipoAcesso': tipoSelecionado,
        'observacao': observacao,
        'status': 'Aguardando autorização',
        'dataHoraPrevista': Timestamp.fromDate(dataHora),
        'validoAte': Timestamp.fromDate(
          dataHora.add(Duration(hours: validadeHoras)),
        ),
        'validadeHoras': validadeHoras,
        'criadoEm': FieldValue.serverTimestamp(),
        'atualizadoEm': FieldValue.serverTimestamp(),
        'autorizadoEm': null,
        'recusadoEm': null,
        'entradaEm': null,
      });

      await InAppNotificationsRepository.notificarMorador(
        moradorId: morador.id,
        titulo: 'Nova solicitação de acesso',
        mensagem:
            '$nomeVisitante foi agendado como ${tipoSelecionado.toLowerCase()} '
            'para ${_formatarData(Timestamp.fromDate(dataHora))}.',
        tipo: 'visitante',
        referenciaId: acessoRef.id,
      );

      nomeVisitanteController.clear();
      observacaoController.clear();
      setState(() {
        moradorSelecionado = null;
        seletorVersion++;
        dataPrevista = null;
        horarioPrevisto = null;
        validadeHoras = 2;
      });

      if (mounted) {
        showSuccess(context, 'Acesso agendado com sucesso.');
      }
    } catch (_) {
      if (mounted) {
        showError(context, 'Erro ao cadastrar acesso. Tente novamente.');
      }
    } finally {
      if (mounted) {
        setState(() {
          enviando = false;
        });
      }
    }
  }

  Future<void> _registrarEntrada(
    DocumentReference<Map<String, dynamic>> referencia,
  ) async {
    try {
      final registro = await referencia.get();
      if (effectiveVisitorStatus(registro.data() ?? {}) == 'Expirado') {
        if (mounted) {
          showWarning(
              context, 'Esta autorização expirou e não aceita entrada.');
        }
        return;
      }

      await referencia.update({
        'status': 'Entrada realizada',
        'entradaEm': FieldValue.serverTimestamp(),
        'atualizadoEm': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        showSuccess(context, 'Entrada registrada com sucesso.');
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao registrar entrada.'),
          ),
        );
      }
    }
  }

  Future<void> _excluirRegistro(String id) async {
    try {
      await FirebaseFirestore.instance
          .collection('acessos_visitantes')
          .doc(id)
          .delete();

      if (mounted) {
        showSuccess(context, 'Registro excluído.');
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao excluir registro.'),
          ),
        );
      }
    }
  }

  Future<void> _confirmarExclusao(String id) async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Excluir registro'),
          content: const Text('Tem certeza que deseja excluir este registro?'),
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
      await _excluirRegistro(id);
    }
  }

  Widget _formularioAcesso({bool compacto = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: defaultCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!compacto) ...[
            const Text(
              'Novo acesso',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
          ],
          ResidentSelector(
            key: ValueKey(seletorVersion),
            value: moradorSelecionado,
            onChanged: (morador) =>
                setState(() => moradorSelecionado = morador),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: nomeVisitanteController,
            decoration: const InputDecoration(
              labelText: 'Nome do visitante / entrega',
              hintText: 'Ex: Maria Oliveira, iFood, técnico da internet',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: tipoSelecionado,
            decoration: const InputDecoration(
              labelText: 'Tipo de acesso',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                value: 'Visitante',
                child: Text('Visitante'),
              ),
              DropdownMenuItem(
                value: 'Entrega',
                child: Text('Entrega'),
              ),
              DropdownMenuItem(
                value: 'Prestador de serviço',
                child: Text('Prestador de serviço'),
              ),
            ],
            onChanged: (valor) {
              if (valor == null) {
                return;
              }

              setState(() {
                tipoSelecionado = valor;
              });
            },
          ),
          const SizedBox(height: 16),
          const Text(
            'Agendamento',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: enviando ? null : _selecionarDataPrevista,
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: Text(_formatarDia(dataPrevista)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: enviando ? null : _selecionarHorarioPrevisto,
                  icon: const Icon(Icons.schedule_outlined),
                  label: Text(_formatarHorario(horarioPrevisto)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            value: validadeHoras,
            decoration: const InputDecoration(
              labelText: 'Período de validade após o horário previsto',
              prefixIcon: Icon(Icons.timer_outlined),
            ),
            items: const [
              DropdownMenuItem(value: 1, child: Text('1 hora')),
              DropdownMenuItem(value: 2, child: Text('2 horas')),
              DropdownMenuItem(value: 4, child: Text('4 horas')),
              DropdownMenuItem(value: 8, child: Text('8 horas')),
              DropdownMenuItem(value: 24, child: Text('24 horas')),
            ],
            onChanged: enviando
                ? null
                : (valor) {
                    if (valor != null) setState(() => validadeHoras = valor);
                  },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: observacaoController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Observação',
              hintText: 'Ex: aguardando na portaria, entrega de comida...',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: enviando ? null : _cadastrarAcesso,
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
                      'Agendar acesso',
                      style: TextStyle(color: Colors.white),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _listaAcessos() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('acessos_visitantes')
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
            title: 'Erro ao carregar acessos',
            description: 'Não foi possível carregar os acessos cadastrados.',
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
            title: 'Nenhum acesso cadastrado',
            description:
                'Os acessos cadastrados pela portaria aparecerão nesta lista.',
            footer: 'Aguardando novos registros',
          );
        }

        final acessosFiltrados = documentos.where((doc) {
          final dados = doc.data();
          final status = effectiveVisitorStatus(dados);
          final correspondeStatus =
              statusSelecionado == 'Todos' || status == statusSelecionado;

          return correspondeStatus;
        }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListCategoryFilter(
              selectedValue: statusSelecionado,
              options: const [
                'Todos',
                'Aguardando autorização',
                'Entrada autorizada',
                'Entrada recusada',
                'Entrada realizada',
                'Expirado',
              ],
              onChanged: (value) {
                setState(() {
                  statusSelecionado = value ?? 'Todos';
                });
              },
            ),
            const SizedBox(height: 16),
            if (acessosFiltrados.isEmpty)
              const InfoCard(
                title: 'Nenhum resultado encontrado',
                description: 'Não há acessos com o status selecionado.',
                footer: 'Selecione outra categoria para continuar',
              ),
            if (acessosFiltrados.isNotEmpty)
              Text(
                'Acessos cadastrados (${acessosFiltrados.length})',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            if (acessosFiltrados.isNotEmpty) const SizedBox(height: 12),
            ...acessosFiltrados.map((doc) {
              final dados = doc.data();

              final nomeVisitante =
                  dados['nomeVisitante']?.toString() ?? 'Visitante';
              final tipoAcesso = dados['tipoAcesso']?.toString() ?? 'Acesso';
              final observacao = dados['observacao']?.toString() ?? '';
              final status = effectiveVisitorStatus(dados);
              final moradorNome =
                  dados['moradorNome']?.toString() ?? 'Morador não informado';
              final moradorEmail =
                  dados['moradorEmail']?.toString() ?? 'E-mail não informado';
              final criadoEm = dados['criadoEm'];
              final entradaEm = dados['entradaEm'];
              final motivoRecusa =
                  dados['motivoRecusa']?.toString().trim() ?? '';
              final dataHoraPrevista = dados['dataHoraPrevista'];
              final validoAte = dados['validoAte'];

              final entradaTexto = status == 'Entrada realizada'
                  ? '\nEntrada em: ${_formatarData(entradaEm)}'
                  : '';

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
                        'Morador: $moradorNome\n'
                        'E-mail: $moradorEmail\n'
                        'Tipo: $tipoAcesso\n'
                        '${dataHoraPrevista is Timestamp ? 'Previsto para: ${_formatarData(dataHoraPrevista)}\n' : ''}'
                        '${validoAte is Timestamp ? 'Válido até: ${_formatarData(validoAte)}\n' : ''}'
                        'Solicitado em: ${_formatarData(criadoEm)}'
                        '$entradaTexto'
                        '${observacao.trim().isEmpty ? '' : '\n\nObservação: $observacao'}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      StatusChip(status: status),
                      if (status == 'Entrada recusada' &&
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
                      if (status == 'Entrada autorizada') ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _registrarEntrada(doc.reference),
                            icon: const Icon(
                              Icons.login,
                              color: Colors.white,
                            ),
                            label: const Text(
                              'Registrar entrada',
                              style: TextStyle(color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => _confirmarExclusao(doc.id),
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Color(0xFFDC2626),
                          ),
                          label: const Text(
                            'Excluir registro',
                            style: TextStyle(
                              color: Color(0xFFDC2626),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BaseScreen(
      title: 'Visitantes',
      subtitle: 'Agende visitantes, entregas e prestadores',
      children: [
        AdminFormSection(
          title: 'Agendar novo acesso',
          subtitle: 'Defina o visitante, o horário e o período de validade',
          icon: Icons.person_add_alt_1_outlined,
          child: _formularioAcesso(compacto: true),
        ),
        _listaAcessos(),
      ],
    );
  }
}
