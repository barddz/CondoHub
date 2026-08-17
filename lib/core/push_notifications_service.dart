import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class PushNotificationsService {
  static const String _vapidPublicKey = String.fromEnvironment(
    'FCM_VAPID_KEY',
    defaultValue:
        'BD_V4L3l_zHEbphQvUgFFsK7XliF9GKRDPjGa-xdwYuSdT1kEXfY9C40gifJdjaRPtFn3Bzwxd2w8qrMbLpr49k',
  );

  final FirebaseMessaging _messaging;
  final FirebaseFirestore _firestore;

  StreamSubscription<String>? _tokenRefreshSubscription;
  String? _usuarioId;
  String? _tokenDocumentId;

  PushNotificationsService({
    FirebaseMessaging? messaging,
    FirebaseFirestore? firestore,
  })  : _messaging = messaging ?? FirebaseMessaging.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  bool get plataformaCompativel {
    if (kIsWeb) {
      return true;
    }

    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  Future<AuthorizationStatus?> inicializar(String usuarioId) async {
    if (!plataformaCompativel) {
      return null;
    }

    _usuarioId = usuarioId;

    try {
      final configuracoes = await _messaging.getNotificationSettings();

      if (_autorizado(configuracoes.authorizationStatus)) {
        await _registrarDispositivo();
      }

      return configuracoes.authorizationStatus;
    } catch (_) {
      return null;
    }
  }

  Future<AuthorizationStatus?> solicitarPermissao() async {
    if (!plataformaCompativel || _usuarioId == null) {
      return null;
    }

    try {
      final configuracoes = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (_autorizado(configuracoes.authorizationStatus)) {
        await _registrarDispositivo();
      }

      return configuracoes.authorizationStatus;
    } catch (_) {
      return null;
    }
  }

  bool _autorizado(AuthorizationStatus status) {
    return status == AuthorizationStatus.authorized ||
        status == AuthorizationStatus.provisional;
  }

  Future<void> _registrarDispositivo() async {
    final usuarioId = _usuarioId;
    if (usuarioId == null) {
      return;
    }

    final token = await _messaging.getToken(
      vapidKey: kIsWeb && _vapidPublicKey.isNotEmpty ? _vapidPublicKey : null,
    );

    if (token == null || token.isEmpty) {
      return;
    }

    await _salvarToken(usuarioId, token);

    await _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = _messaging.onTokenRefresh.listen(
      (novoToken) => _salvarToken(usuarioId, novoToken),
    );
  }

  Future<void> _salvarToken(String usuarioId, String token) async {
    final documentId = base64Url.encode(utf8.encode(token));
    final tokens = _firestore
        .collection('usuarios')
        .doc(usuarioId)
        .collection('fcmTokens');

    if (_tokenDocumentId != null && _tokenDocumentId != documentId) {
      await tokens.doc(_tokenDocumentId).delete();
    }

    await tokens.doc(documentId).set({
      'token': token,
      'plataforma': kIsWeb ? 'web' : defaultTargetPlatform.name,
      'atualizadoEm': FieldValue.serverTimestamp(),
    });

    _tokenDocumentId = documentId;
  }

  static Future<void> desregistrarDispositivoAtual(String usuarioId) async {
    final servico = PushNotificationsService();
    if (!servico.plataformaCompativel) {
      return;
    }

    try {
      final configuracoes = await servico._messaging.getNotificationSettings();
      if (servico._autorizado(configuracoes.authorizationStatus)) {
        final token = await servico._messaging.getToken(
          vapidKey:
              kIsWeb && _vapidPublicKey.isNotEmpty ? _vapidPublicKey : null,
        );

        if (token != null && token.isNotEmpty) {
          final documentId = base64Url.encode(utf8.encode(token));
          await servico._firestore
              .collection('usuarios')
              .doc(usuarioId)
              .collection('fcmTokens')
              .doc(documentId)
              .delete();
        }
      }

      await servico._messaging.deleteToken();
    } catch (_) {
      // O encerramento da sessão não deve ser bloqueado por uma falha no FCM.
    }
  }

  Future<void> dispose() async {
    await _tokenRefreshSubscription?.cancel();
  }
}
