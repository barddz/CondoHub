import 'dart:convert';

String reservationSlotId({
  required String area,
  required String dataChave,
  required String horario,
}) {
  final slot = '$area|$dataChave|$horario';
  return base64UrlEncode(utf8.encode(slot)).replaceAll('=', '');
}
