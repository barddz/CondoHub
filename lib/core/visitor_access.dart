import 'package:cloud_firestore/cloud_firestore.dart';

DateTime? visitorDateTime(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}

bool visitorAccessExpired(
  Map<String, dynamic> data, {
  DateTime? now,
}) {
  final validUntil = visitorDateTime(data['validoAte']);
  if (validUntil == null) return false;
  return (now ?? DateTime.now()).isAfter(validUntil);
}

String effectiveVisitorStatus(
  Map<String, dynamic> data, {
  DateTime? now,
}) {
  final status = data['status']?.toString() ?? 'Aguardando autorização';
  final canExpire =
      status == 'Aguardando autorização' || status == 'Entrada autorizada';

  if (canExpire && visitorAccessExpired(data, now: now)) {
    return 'Expirado';
  }

  return status;
}
