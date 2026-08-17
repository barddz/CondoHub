import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_helpers.dart';
import '../../core/notification_navigation.dart';
import '../../widgets/base_screen.dart';
import '../../widgets/info_card.dart';

IconData notificationTypeIcon(String tipo) {
  if (tipo.startsWith('reserva')) return Icons.calendar_month_outlined;
  if (tipo.startsWith('atendimento')) return Icons.support_agent_outlined;
  if (tipo.startsWith('visitante')) return Icons.badge_outlined;
  if (tipo.startsWith('encomenda')) return Icons.inventory_2_outlined;
  if (tipo.startsWith('aviso')) return Icons.campaign_outlined;
  return Icons.notifications_outlined;
}

class NotificacoesScreen extends StatelessWidget {
  const NotificacoesScreen({super.key});

  String _formatarData(dynamic valor) {
    if (valor is! Timestamp) return 'Agora';
    final data = valor.toDate();
    final dia = data.day.toString().padLeft(2, '0');
    final mes = data.month.toString().padLeft(2, '0');
    final hora = data.hour.toString().padLeft(2, '0');
    final minuto = data.minute.toString().padLeft(2, '0');
    return '$dia/$mes/${data.year} às $hora:$minuto';
  }

  Future<void> _marcarComoLida(
    BuildContext context,
    DocumentReference<Map<String, dynamic>> referencia,
  ) async {
    try {
      await referencia.update({
        'lida': true,
        'lidaEm': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      if (context.mounted) {
        showError(context, 'Não foi possível atualizar a notificação.');
      }
    }
  }

  Future<void> _abrirNotificacao(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final dados = doc.data();
    if (dados['lida'] != true) {
      await _marcarComoLida(context, doc.reference);
    }

    if (!context.mounted) return;

    final abriu = await openNotificationDestination(
      context,
      tipo: dados['tipo']?.toString() ?? '',
      referenciaId: dados['referenciaId']?.toString(),
    );

    if (!abriu && context.mounted) {
      showInfo(context, 'Esta notificação não possui uma tela relacionada.');
    }
  }

  Future<void> _marcarTodasComoLidas(
    BuildContext context,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> documentos,
  ) async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in documentos.where((doc) => doc.data()['lida'] != true)) {
        batch.update(doc.reference, {
          'lida': true,
          'lidaEm': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
      if (context.mounted) {
        showSuccess(
            context, 'Todas as notificações foram marcadas como lidas.');
      }
    } catch (_) {
      if (context.mounted) {
        showError(context, 'Não foi possível atualizar as notificações.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final usuario = FirebaseAuth.instance.currentUser;

    return BaseScreen(
      title: 'Notificações',
      subtitle: 'Acompanhe as novidades e atualizações da sua conta.',
      children: [
        if (usuario == null)
          const InfoCard(
            title: 'Sessão encerrada',
            description: 'Entre novamente para ver suas notificações.',
            leadingIcon: Icons.lock_outline,
          )
        else
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('notificacoes')
                .where('destinatarioId', isEqualTo: usuario.uid)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return const InfoCard(
                  title: 'Não foi possível carregar',
                  description: 'Verifique sua conexão e tente novamente.',
                  leadingIcon: Icons.cloud_off_outlined,
                );
              }

              final docs = [...?snapshot.data?.docs];
              docs.sort((a, b) {
                final aData = a.data()['criadoEm'];
                final bData = b.data()['criadoEm'];
                if (aData is Timestamp && bData is Timestamp) {
                  return bData.compareTo(aData);
                }
                return 0;
              });
              final naoLidas = docs.where((doc) => doc.data()['lida'] != true);

              if (docs.isEmpty) {
                return const InfoCard(
                  title: 'Tudo em dia',
                  description: 'Você ainda não possui notificações.',
                  leadingIcon: Icons.notifications_none_outlined,
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (naoLidas.isNotEmpty) ...[
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => _marcarTodasComoLidas(context, docs),
                        icon: const Icon(Icons.done_all),
                        label: const Text('Marcar todas como lidas'),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  ...docs.map((doc) {
                    final dados = doc.data();
                    final lida = dados['lida'] == true;
                    final tipo = dados['tipo']?.toString() ?? '';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: InfoCard(
                        title: dados['titulo']?.toString() ?? 'Notificação',
                        description: dados['mensagem']?.toString() ?? '',
                        footer: _formatarData(dados['criadoEm']),
                        leadingIcon: notificationTypeIcon(tipo),
                        badge: lida
                            ? null
                            : Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Text(
                                  'Nova',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                        onTap: () => _abrirNotificacao(context, doc),
                      ),
                    );
                  }),
                ],
              );
            },
          ),
      ],
    );
  }
}
