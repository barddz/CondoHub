import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/reserva_area.dart';

class ReservationAreasRepository {
  static CollectionReference<Map<String, dynamic>> get areas =>
      FirebaseFirestore.instance.collection('areas_reserva');

  static DocumentReference<Map<String, dynamic>> get configuracao =>
      FirebaseFirestore.instance
          .collection('configuracoes_reservas')
          .doc('areas');

  static Future<void> garantirAreasPadrao() async {
    final firestore = FirebaseFirestore.instance;

    await firestore.runTransaction((transaction) async {
      final configuracaoSnapshot = await transaction.get(configuracao);

      if (configuracaoSnapshot.data()?['inicializadas'] == true) {
        return;
      }

      final snapshots = <DocumentSnapshot<Map<String, dynamic>>>[];

      for (final area in areasPadraoReserva) {
        snapshots.add(await transaction.get(areas.doc(area.id)));
      }

      for (var index = 0; index < areasPadraoReserva.length; index++) {
        if (!snapshots[index].exists) {
          final area = areasPadraoReserva[index];
          transaction.set(
            areas.doc(area.id),
            area.toFirestore(incluirCriadoEm: true),
          );
        }
      }

      transaction.set(configuracao, {
        'inicializadas': true,
        'atualizadoEm': FieldValue.serverTimestamp(),
      });
    });
  }

  static Future<bool> areasForamInicializadas() async {
    final snapshot = await configuracao.get();
    return snapshot.data()?['inicializadas'] == true;
  }
}
