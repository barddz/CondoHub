import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/visitor_access.dart';

void main() {
  final now = DateTime(2026, 8, 17, 14);

  test('mantém autorização dentro do período de validade', () {
    final data = <String, dynamic>{
      'status': 'Entrada autorizada',
      'validoAte': Timestamp.fromDate(now.add(const Duration(hours: 1))),
    };

    expect(effectiveVisitorStatus(data, now: now), 'Entrada autorizada');
  });

  test('considera pendência ou autorização vencida como expirada', () {
    final data = <String, dynamic>{
      'status': 'Aguardando autorização',
      'validoAte': Timestamp.fromDate(now.subtract(const Duration(minutes: 1))),
    };

    expect(visitorAccessExpired(data, now: now), isTrue);
    expect(effectiveVisitorStatus(data, now: now), 'Expirado');
  });

  test('preserva status final mesmo após a validade', () {
    final data = <String, dynamic>{
      'status': 'Entrada realizada',
      'validoAte': Timestamp.fromDate(now.subtract(const Duration(hours: 1))),
    };

    expect(effectiveVisitorStatus(data, now: now), 'Entrada realizada');
  });
}
