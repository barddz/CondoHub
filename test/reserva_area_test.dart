import 'package:flutter_application_1/models/reserva_area.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resumoDiasSemana', () {
    test('identifica finais de semana', () {
      expect(
        resumoDiasSemana([DateTime.saturday, DateTime.sunday]),
        'Finais de semana',
      );
    });

    test('identifica dias úteis', () {
      expect(
        resumoDiasSemana([
          DateTime.monday,
          DateTime.tuesday,
          DateTime.wednesday,
          DateTime.thursday,
          DateTime.friday,
        ]),
        'Segunda a sexta',
      );
    });

    test('ordena uma seleção personalizada', () {
      expect(
        resumoDiasSemana([
          DateTime.sunday,
          DateTime.tuesday,
          DateTime.thursday,
        ]),
        'Ter, Qui, Dom',
      );
    });
  });
}
