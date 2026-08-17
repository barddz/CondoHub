import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/notification_navigation.dart';
import 'package:flutter_application_1/screens/admin/admin_reservas_screen.dart';
import 'package:flutter_application_1/screens/admin/admin_visitantes_screen.dart';
import 'package:flutter_application_1/screens/reservas/reservas_screen.dart';

void main() {
  test('direciona notificações conforme tipo e perfil', () {
    expect(notificationDestination('reserva'), isA<ReservasScreen>());
    expect(
      notificationDestination('reserva_admin'),
      isA<AdminReservasScreen>(),
    );
    expect(
      notificationDestination('visitante_admin'),
      isA<AdminVisitantesScreen>(),
    );
  });

  test('não cria destino para tipo desconhecido', () {
    expect(notificationDestination('tipo_desconhecido'), isNull);
  });
}
