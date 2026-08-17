import 'package:cloud_firestore/cloud_firestore.dart';

const horariosPadraoReserva = <String>[
  '08:00 - 10:00',
  '10:00 - 12:00',
  '14:00 - 16:00',
  '16:00 - 18:00',
  '18:00 - 20:00',
  '20:00 - 22:00',
];

class ReservaArea {
  final String id;
  final String nome;
  final String descricao;
  final bool ativa;
  final List<int> diasSemanaDisponiveis;
  final List<String> horariosDisponiveis;

  const ReservaArea({
    required this.id,
    required this.nome,
    required this.descricao,
    required this.ativa,
    required this.diasSemanaDisponiveis,
    required this.horariosDisponiveis,
  });

  bool get disponivelParaReserva =>
      ativa &&
      diasSemanaDisponiveis.isNotEmpty &&
      horariosDisponiveis.isNotEmpty;

  factory ReservaArea.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final dados = snapshot.data() ?? <String, dynamic>{};

    final dias = (dados['diasSemanaDisponiveis'] as List<dynamic>? ?? [])
        .whereType<num>()
        .map((dia) => dia.toInt())
        .where((dia) => dia >= DateTime.monday && dia <= DateTime.sunday)
        .toSet()
        .toList()
      ..sort();

    final horarios = (dados['horariosDisponiveis'] as List<dynamic>? ?? [])
        .whereType<String>()
        .map((horario) => horario.trim())
        .where((horario) => horario.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    return ReservaArea(
      id: snapshot.id,
      nome: dados['nome']?.toString().trim().isNotEmpty == true
          ? dados['nome'].toString().trim()
          : 'Área sem nome',
      descricao: dados['descricao']?.toString().trim() ?? '',
      ativa: dados['ativa'] == true,
      diasSemanaDisponiveis: dias,
      horariosDisponiveis: horarios,
    );
  }

  Map<String, dynamic> toFirestore({required bool incluirCriadoEm}) {
    return {
      'nome': nome,
      'nomeNormalizado': nome.trim().toLowerCase(),
      'descricao': descricao,
      'ativa': ativa,
      'diasSemanaDisponiveis': diasSemanaDisponiveis,
      'horariosDisponiveis': horariosDisponiveis,
      if (incluirCriadoEm) 'criadoEm': FieldValue.serverTimestamp(),
      'atualizadoEm': FieldValue.serverTimestamp(),
    };
  }
}

const areasPadraoReserva = <ReservaArea>[
  ReservaArea(
    id: 'churrasqueira',
    nome: 'Churrasqueira',
    descricao: 'Espaço para confraternizações e refeições.',
    ativa: true,
    diasSemanaDisponiveis: [DateTime.saturday, DateTime.sunday],
    horariosDisponiveis: horariosPadraoReserva,
  ),
  ReservaArea(
    id: 'salao-festas',
    nome: 'Salão de festas',
    descricao: 'Espaço para festas e eventos do condomínio.',
    ativa: false,
    diasSemanaDisponiveis: [
      DateTime.friday,
      DateTime.saturday,
      DateTime.sunday,
    ],
    horariosDisponiveis: horariosPadraoReserva,
  ),
  ReservaArea(
    id: 'quadra-esportiva',
    nome: 'Quadra esportiva',
    descricao: 'Espaço destinado a atividades esportivas.',
    ativa: true,
    diasSemanaDisponiveis: [
      DateTime.monday,
      DateTime.tuesday,
      DateTime.wednesday,
      DateTime.thursday,
      DateTime.friday,
      DateTime.saturday,
      DateTime.sunday,
    ],
    horariosDisponiveis: horariosPadraoReserva,
  ),
];

const nomesDiasSemana = <int, String>{
  DateTime.monday: 'Seg',
  DateTime.tuesday: 'Ter',
  DateTime.wednesday: 'Qua',
  DateTime.thursday: 'Qui',
  DateTime.friday: 'Sex',
  DateTime.saturday: 'Sáb',
  DateTime.sunday: 'Dom',
};

String resumoDiasSemana(List<int> dias) {
  final diasOrdenados = [...dias]..sort();

  if (diasOrdenados.length == 7) {
    return 'Todos os dias';
  }

  if (diasOrdenados.length == 5 &&
      diasOrdenados.every((dia) => dia <= DateTime.friday)) {
    return 'Segunda a sexta';
  }

  if (diasOrdenados.length == 2 &&
      diasOrdenados.contains(DateTime.saturday) &&
      diasOrdenados.contains(DateTime.sunday)) {
    return 'Finais de semana';
  }

  return diasOrdenados
      .map((dia) => nomesDiasSemana[dia])
      .whereType<String>()
      .join(', ');
}
