import 'package:flutter/material.dart';

import '../screens/admin/admin_encomendas_screen.dart';
import '../screens/admin/admin_reservas_screen.dart';
import '../screens/admin/admin_solicitacoes_screen.dart';
import '../screens/admin/admin_visitantes_screen.dart';
import '../screens/atendimento/atendimento_screen.dart';
import '../screens/avisos/avisos_screen.dart';
import '../screens/documentos/documentos_normas_screen.dart';
import '../screens/encomendas/encomendas_screen.dart';
import '../screens/reservas/reservas_screen.dart';
import '../screens/visitantes/visitantes_screen.dart';

Widget? notificationDestination(String tipo) {
  final tipoNormalizado = tipo.trim().toLowerCase();
  final paraAdministrador = tipoNormalizado.endsWith('_admin');

  if (tipoNormalizado.startsWith('reserva')) {
    return paraAdministrador
        ? const AdminReservasScreen()
        : const ReservasScreen();
  }

  if (tipoNormalizado.startsWith('atendimento')) {
    return paraAdministrador
        ? const AdminSolicitacoesScreen()
        : const AtendimentoScreen();
  }

  if (tipoNormalizado.startsWith('visitante')) {
    return paraAdministrador
        ? const AdminVisitantesScreen()
        : const VisitantesScreen();
  }

  if (tipoNormalizado.startsWith('encomenda')) {
    return paraAdministrador
        ? const AdminEncomendasScreen()
        : const EncomendasScreen();
  }

  if (tipoNormalizado.startsWith('aviso')) {
    return const AvisosScreen();
  }

  if (tipoNormalizado.startsWith('documento')) {
    return const DocumentosNormasScreen();
  }

  return null;
}

Future<bool> openNotificationDestination(
  BuildContext context, {
  required String tipo,
  String? referenciaId,
}) async {
  final destino = notificationDestination(tipo);
  if (destino == null) return false;

  await Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => destino),
  );
  return true;
}
