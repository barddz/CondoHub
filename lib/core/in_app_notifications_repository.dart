import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class InAppNotificationsRepository {
  static CollectionReference<Map<String, dynamic>> get notificacoes =>
      FirebaseFirestore.instance.collection('notificacoes');

  static Future<void> notificarMorador({
    required String moradorId,
    required String titulo,
    required String mensagem,
    required String tipo,
    String? referenciaId,
  }) async {
    if (moradorId.trim().isEmpty) {
      return;
    }

    try {
      await notificacoes.add({
        'destinatarioId': moradorId,
        'titulo': titulo,
        'mensagem': mensagem,
        'tipo': tipo,
        if (referenciaId != null) 'referenciaId': referenciaId,
        'lida': false,
        'criadoEm': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // A operação principal não deve falhar caso a notificação não seja criada.
    }
  }

  static Future<void> notificarAdministradores({
    required String titulo,
    required String mensagem,
    required String tipo,
    String? referenciaId,
  }) async {
    final remetenteId = FirebaseAuth.instance.currentUser?.uid;
    if (remetenteId == null) return;

    try {
      await notificacoes.add({
        'destinatarioId': 'administradores',
        'remetenteId': remetenteId,
        'titulo': titulo,
        'mensagem': mensagem,
        'tipo': tipo,
        if (referenciaId != null) 'referenciaId': referenciaId,
        'lida': false,
        'criadoEm': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // A operação principal não deve falhar caso a notificação não seja criada.
    }
  }

  static Future<void> notificarTodosMoradores({
    required String titulo,
    required String mensagem,
    required String tipo,
    String? referenciaId,
  }) async {
    try {
      final moradores = await FirebaseFirestore.instance
          .collection('usuarios')
          .where('tipoUsuario', isEqualTo: 'morador')
          .get();

      await Future.wait(
        moradores.docs.map(
          (doc) => notificarMorador(
            moradorId: doc.id,
            titulo: titulo,
            mensagem: mensagem,
            tipo: tipo,
            referenciaId: referenciaId,
          ),
        ),
      );
    } catch (_) {
      // Mantém a publicação principal independente das notificações.
    }
  }
}
