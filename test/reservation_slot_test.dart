import 'package:flutter_application_1/core/reservation_slot.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('identificador do horário de reserva', () {
    test('é determinístico e seguro para uso como id de documento', () {
      final primeiro = reservationSlotId(
        area: 'piscina',
        dataChave: '2026-10-20',
        horario: '14:00',
      );
      final segundo = reservationSlotId(
        area: 'piscina',
        dataChave: '2026-10-20',
        horario: '14:00',
      );

      expect(primeiro, 'cGlzY2luYXwyMDI2LTEwLTIwfDE0OjAw');
      expect(segundo, primeiro);
      expect(primeiro, isNot(contains('=')));
      expect(primeiro, isNot(contains('/')));
    });

    test('muda quando área, data ou horário são diferentes', () {
      final base = reservationSlotId(
        area: 'piscina',
        dataChave: '2026-10-20',
        horario: '14:00',
      );

      expect(
        reservationSlotId(
          area: 'churrasqueira',
          dataChave: '2026-10-20',
          horario: '14:00',
        ),
        isNot(base),
      );
      expect(
        reservationSlotId(
          area: 'piscina',
          dataChave: '2026-10-21',
          horario: '14:00',
        ),
        isNot(base),
      );
      expect(
        reservationSlotId(
          area: 'piscina',
          dataChave: '2026-10-20',
          horario: '15:00',
        ),
        isNot(base),
      );
    });
  });
}
