import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_helpers.dart';
import '../core/notification_navigation.dart';
import '../core/notification_prompt_preferences.dart';
import '../core/push_notifications_service.dart';

class InAppNotificationsHost extends StatefulWidget {
  final Widget child;

  const InAppNotificationsHost({
    super.key,
    required this.child,
  });

  @override
  State<InAppNotificationsHost> createState() => _InAppNotificationsHostState();
}

class _InAppNotificationsHostState extends State<InAppNotificationsHost> {
  final Set<String> _exibidasNestaSessao = {};
  final PushNotificationsService _pushNotifications =
      PushNotificationsService();
  bool _dialogAberto = false;
  bool _convitePushPendente = false;
  bool _convitePushAberto = false;
  bool _aberturaInicialProcessada = false;
  String? _usuarioId;
  StreamSubscription<RemoteMessage>? _pushAbertoSubscription;

  @override
  void initState() {
    super.initState();
    _pushAbertoSubscription =
        FirebaseMessaging.onMessageOpenedApp.listen(_abrirMensagemPush);
    WidgetsBinding.instance.addPostFrameCallback((_) => _inicializarPush());
  }

  Future<void> _inicializarPush() async {
    final usuario = FirebaseAuth.instance.currentUser;
    if (usuario == null) {
      return;
    }
    _usuarioId = usuario.uid;

    final status = await _pushNotifications.inicializar(usuario.uid);
    if (!mounted) {
      return;
    }

    final conviteRespondido =
        await NotificationPromptPreferences.wasAnswered(usuario.uid);
    if (!mounted) {
      return;
    }

    _convitePushPendente =
        status == AuthorizationStatus.notDetermined && !conviteRespondido;
    _tentarExibirConvitePush();
    await _processarAberturaInicial();
  }

  Future<void> _processarAberturaInicial() async {
    if (_aberturaInicialProcessada) return;
    _aberturaInicialProcessada = true;

    try {
      final mensagemInicial =
          await FirebaseMessaging.instance.getInitialMessage();
      if (mensagemInicial != null) {
        await _abrirMensagemPush(mensagemInicial);
        return;
      }
    } catch (_) {
      // Algumas plataformas web não disponibilizam a mensagem inicial.
    }

    if (kIsWeb) {
      final tipo = Uri.base.queryParameters['tipo'];
      if (tipo != null && tipo.isNotEmpty) {
        await _abrirTipoNotificacao(
          tipo,
          Uri.base.queryParameters['referenciaId'],
        );
      }
    }
  }

  Future<void> _abrirMensagemPush(RemoteMessage mensagem) async {
    await _abrirTipoNotificacao(
      mensagem.data['tipo']?.toString() ?? '',
      mensagem.data['referenciaId']?.toString(),
    );
  }

  Future<void> _abrirTipoNotificacao(
    String tipo,
    String? referenciaId,
  ) async {
    if (!mounted || tipo.trim().isEmpty) return;
    await openNotificationDestination(
      context,
      tipo: tipo,
      referenciaId: referenciaId,
    );
  }

  void _tentarExibirConvitePush() {
    if (!mounted ||
        !_convitePushPendente ||
        _convitePushAberto ||
        _dialogAberto) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted ||
          !_convitePushPendente ||
          _convitePushAberto ||
          _dialogAberto) {
        return;
      }

      _convitePushAberto = true;
      final ativar = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            icon: const Icon(
              Icons.notifications_active_outlined,
              color: AppColors.primary,
              size: 34,
            ),
            title: const Text(
              'Receba avisos do CondoHub',
              textAlign: TextAlign.center,
            ),
            content: const Text(
              'Ative as notificações para ser avisado sobre reservas, '
              'encomendas, visitantes e atendimentos mesmo com o aplicativo '
              'em segundo plano.',
              textAlign: TextAlign.center,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Agora não'),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.pop(dialogContext, true),
                icon: const Icon(Icons.notifications_outlined),
                label: const Text('Ativar'),
              ),
            ],
          );
        },
      );

      _convitePushPendente = false;
      _convitePushAberto = false;

      final usuarioId = _usuarioId;
      if (usuarioId != null) {
        await NotificationPromptPreferences.markAnswered(usuarioId);
      }

      if (ativar != true || !mounted) {
        return;
      }

      final status = await _pushNotifications.solicitarPermissao();
      if (!mounted) {
        return;
      }

      if (status == AuthorizationStatus.authorized ||
          status == AuthorizationStatus.provisional) {
        showSuccess(context, 'Notificações ativadas neste dispositivo.');
      } else if (status == AuthorizationStatus.denied) {
        showError(
          context,
          'A permissão não foi concedida. Você ainda receberá os avisos '
          'dentro do CondoHub.',
        );
      } else {
        showError(
          context,
          'Não foi possível registrar este dispositivo. Tente novamente '
          'ao acessar o CondoHub outra vez.',
        );
      }
    });
  }

  @override
  void dispose() {
    _pushAbertoSubscription?.cancel();
    _pushNotifications.dispose();
    super.dispose();
  }

  IconData _iconeTipo(String tipo) {
    if (tipo.startsWith('aviso')) return Icons.campaign_outlined;
    if (tipo.startsWith('encomenda')) return Icons.inventory_2_outlined;
    if (tipo.startsWith('visitante')) return Icons.badge_outlined;
    if (tipo.startsWith('reserva')) return Icons.calendar_month_outlined;
    if (tipo.startsWith('atendimento')) return Icons.support_agent_outlined;
    return Icons.notifications_outlined;
  }

  Future<void> _exibirNotificacao(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    if (!mounted || _dialogAberto || _exibidasNestaSessao.contains(doc.id)) {
      return;
    }

    _dialogAberto = true;
    _exibidasNestaSessao.add(doc.id);

    final dados = doc.data();
    final titulo = dados['titulo']?.toString() ?? 'Nova notificação';
    final mensagem = dados['mensagem']?.toString() ?? '';
    final tipo = dados['tipo']?.toString() ?? '';

    final acao = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          icon: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.10),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              _iconeTipo(tipo),
              color: AppColors.primary,
              size: 30,
            ),
          ),
          title: Text(titulo, textAlign: TextAlign.center),
          content: Text(mensagem, textAlign: TextAlign.center),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, 'lida'),
              child: const Text('Entendi'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(dialogContext, 'abrir'),
              icon: const Icon(Icons.open_in_new),
              label: const Text('Ver detalhes'),
            ),
          ],
        );
      },
    );

    if (acao != null) {
      try {
        await doc.reference.update({
          'lida': true,
          'lidaEm': FieldValue.serverTimestamp(),
        });
      } catch (_) {
        if (mounted) {
          showError(
              context, 'Não foi possível marcar a notificação como lida.');
        }
      }
    }

    if (acao == 'abrir' && mounted) {
      await openNotificationDestination(
        context,
        tipo: tipo,
        referenciaId: dados['referenciaId']?.toString(),
      );
    }

    _dialogAberto = false;
    if (mounted) {
      setState(() {});
      _tentarExibirConvitePush();
    }
  }

  @override
  Widget build(BuildContext context) {
    final usuario = FirebaseAuth.instance.currentUser;

    if (usuario == null) {
      return widget.child;
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('notificacoes')
          .where('destinatarioId', isEqualTo: usuario.uid)
          .snapshots(),
      builder: (context, snapshot) {
        final naoLidas = (snapshot.data?.docs ?? []).where((doc) {
          return doc.data()['lida'] != true &&
              !_exibidasNestaSessao.contains(doc.id);
        }).toList();

        naoLidas.sort((a, b) {
          final dataA = a.data()['criadoEm'];
          final dataB = b.data()['criadoEm'];

          if (dataA is Timestamp && dataB is Timestamp) {
            return dataA.toDate().compareTo(dataB.toDate());
          }

          return 0;
        });

        if (naoLidas.isNotEmpty && !_dialogAberto) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _exibirNotificacao(naoLidas.first);
          });
        }

        return widget.child;
      },
    );
  }
}
