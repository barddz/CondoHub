import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_helpers.dart';
import '../../widgets/base_screen.dart';
import '../../widgets/reserva_card.dart';

class ReservasScreen extends StatefulWidget {
  const ReservasScreen({super.key});

  @override
  State<ReservasScreen> createState() => _ReservasScreenState();
}

class _ReservasScreenState extends State<ReservasScreen> {
  final Map<String, String> reservasSolicitadas = {};

  final Map<String, Map<String, List<String>>> horariosJaReservados = {
    'Churrasqueira': {
      '2026-06-15': ['18:00 - 20:00', '20:00 - 22:00'],
      '2026-06-16': ['10:00 - 12:00'],
    },
    'Quadra esportiva': {
      '2026-06-15': ['14:00 - 16:00'],
      '2026-06-17': ['08:00 - 10:00', '16:00 - 18:00'],
    },
  };

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

  List<String> _horariosOcupados(String area, DateTime data) {
    final chaveData = _formatarDataChave(data);

    return horariosJaReservados[area]?[chaveData] ?? [];
  }

  Future<void> _abrirFormularioReserva(String area) async {
    DateTime? dataSelecionada;
    String? horarioSelecionado;

    final horarios = [
      '08:00 - 10:00',
      '10:00 - 12:00',
      '14:00 - 16:00',
      '16:00 - 18:00',
      '18:00 - 20:00',
      '20:00 - 22:00',
    ];

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final horariosOcupados = dataSelecionada == null
                ? <String>[]
                : _horariosOcupados(area, dataSelecionada!);

            return AlertDialog(
              title: const Text('Solicitar reserva'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    area,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final data = await showDatePicker(
                          context: dialogContext,
                          initialDate: DateTime.now().add(
                            const Duration(days: 1),
                          ),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(
                            const Duration(days: 60),
                          ),
                        );

                        if (data != null) {
                          setDialogState(() {
                            dataSelecionada = data;
                            horarioSelecionado = null;
                          });
                        }
                      },
                      icon: const Icon(Icons.calendar_today),
                      label: Text(
                        dataSelecionada == null
                            ? 'Selecionar data'
                            : _formatarData(dataSelecionada!),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
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
                          ocupado ? '$horario  • Reservado' : horario,
                          style: TextStyle(
                            color: ocupado
                                ? AppColors.textSecondary
                                : Colors.black,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: dataSelecionada == null
                        ? null
                        : (valor) {
                            setDialogState(() {
                              horarioSelecionado = valor;
                            });
                          },
                  ),
                  if (dataSelecionada != null &&
                      horariosOcupados.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      '${horariosOcupados.length} horário(s) já reservado(s) nessa data.',
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
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (dataSelecionada == null || horarioSelecionado == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Selecione a data e o horário.'),
                        ),
                      );
                      return;
                    }

                    final chaveData = _formatarDataChave(dataSelecionada!);

                    setState(() {
                      reservasSolicitadas[area] =
                          '${_formatarData(dataSelecionada!)} • $horarioSelecionado';

                      horariosJaReservados.putIfAbsent(area, () => {});
                      horariosJaReservados[area]!
                          .putIfAbsent(chaveData, () => []);
                      horariosJaReservados[area]![chaveData]!
                          .add(horarioSelecionado!);
                    });

                    Navigator.pop(dialogContext);

                    showSuccess(
                      context,
                      'Solicitação enviada para $area.',
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                  ),
                  child: const Text(
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

  @override
  Widget build(BuildContext context) {
    return BaseScreen(
      title: 'Reservas',
      subtitle: 'Reserve áreas comuns do condomínio',
      children: [
        ReservaCard(
          title: 'Churrasqueira',
          description: 'Disponível para reserva aos finais de semana.',
          disponivel: true,
          statusSolicitacao: reservasSolicitadas['Churrasqueira'],
          onReservar: () => _abrirFormularioReserva('Churrasqueira'),
        ),
        ReservaCard(
          title: 'Salão de festas',
          description: 'Indisponível para reserva no momento.',
          disponivel: false,
          onReservar: () {},
        ),
        ReservaCard(
          title: 'Quadra esportiva',
          description: 'Horários disponíveis das 8h às 22h.',
          disponivel: true,
          statusSolicitacao: reservasSolicitadas['Quadra esportiva'],
          onReservar: () => _abrirFormularioReserva('Quadra esportiva'),
        ),
      ],
    );
  }
}
