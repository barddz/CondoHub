import 'package:flutter_application_1/core/reservation_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('status de reserva', () {
    test('morador pode cancelar reserva em análise ou aprovada', () {
      expect(reservaPodeSerCancelada(statusReservaEmAnalise), isTrue);
      expect(reservaPodeSerCancelada(statusReservaAprovada), isTrue);
    });

    test('morador não pode cancelar reserva finalizada', () {
      expect(reservaPodeSerCancelada(statusReservaRecusada), isFalse);
      expect(reservaPodeSerCancelada(statusReservaCancelada), isFalse);
    });

    test('admin pode excluir reservas com decisão final', () {
      expect(reservaPodeSerExcluidaPeloAdmin(statusReservaAprovada), isTrue);
      expect(reservaPodeSerExcluidaPeloAdmin(statusReservaRecusada), isTrue);
      expect(reservaPodeSerExcluidaPeloAdmin(statusReservaCancelada), isTrue);
      expect(
        reservaPodeSerExcluidaPeloAdmin(statusReservaEmAnalise),
        isFalse,
      );
    });
  });
}
