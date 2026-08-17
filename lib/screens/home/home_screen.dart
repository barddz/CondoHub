import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/push_notifications_service.dart';
import '../../core/visitor_access.dart';
import '../../widgets/live_home_card.dart';
import '../../widgets/notification_bell.dart';
import '../atendimento/atendimento_screen.dart';
import '../avisos/avisos_screen.dart';
import '../documentos/documentos_normas_screen.dart';
import '../encomendas/encomendas_screen.dart';
import '../perfil/perfil_screen.dart';
import '../reservas/reservas_screen.dart';
import '../visitantes/visitantes_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _goTo(BuildContext context, Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  String _nomePeloEmailOuDisplayName(User? usuario) {
    final displayName = usuario?.displayName?.trim();

    if (displayName != null && displayName.isNotEmpty) {
      return displayName.split(' ').first;
    }

    final email = usuario?.email;

    if (email != null && email.isNotEmpty) {
      return email.split('@').first;
    }

    return 'morador';
  }

  @override
  Widget build(BuildContext context) {
    final usuario = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final margem = constraints.maxWidth < 600 ? 16.0 : 24.0;
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1440),
                child: Padding(
                  padding: EdgeInsets.all(margem),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                        future: usuario == null
                            ? null
                            : FirebaseFirestore.instance
                                .collection('usuarios')
                                .doc(usuario.uid)
                                .get(),
                        builder: (context, snapshot) {
                          String nomeUsuario =
                              _nomePeloEmailOuDisplayName(usuario);

                          if (snapshot.hasData && snapshot.data!.exists) {
                            final dados = snapshot.data!.data();
                            final nomeFirestore = dados?['nome'];

                            if (nomeFirestore is String &&
                                nomeFirestore.trim().isNotEmpty) {
                              nomeUsuario = nomeFirestore.trim();
                            }
                          }

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  'Bem-vindo, $nomeUsuario',
                                  style: const TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                              const NotificationBell(),
                              IconButton(
                                tooltip: 'Meu perfil',
                                onPressed: () => _goTo(
                                  context,
                                  const PerfilScreen(),
                                ),
                                icon: const Icon(
                                  Icons.person_outline,
                                  color: AppColors.primary,
                                ),
                              ),
                              IconButton(
                                tooltip: 'Sair',
                                onPressed: () async {
                                  final usuarioAtual =
                                      FirebaseAuth.instance.currentUser;

                                  if (usuarioAtual != null) {
                                    await PushNotificationsService
                                        .desregistrarDispositivoAtual(
                                      usuarioAtual.uid,
                                    );
                                  }

                                  await FirebaseAuth.instance.signOut();
                                },
                                icon: const Icon(
                                  Icons.logout,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Acesse os serviços do condomínio em um só lugar.',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 32),
                      Expanded(
                        child: GridView(
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 300,
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 16,
                            childAspectRatio: 1.05,
                          ),
                          children: [
                            LiveHomeCard(
                              query: FirebaseFirestore.instance
                                  .collection('avisos'),
                              icon: Icons.campaign,
                              title: 'Avisos',
                              subtitleBuilder: (quantidade) => quantidade == 1
                                  ? '1 comunicado publicado'
                                  : '$quantidade comunicados publicados',
                              onTap: () => _goTo(context, const AvisosScreen()),
                            ),
                            LiveHomeCard(
                              query: FirebaseFirestore.instance
                                  .collection('acessos_visitantes')
                                  .where('moradorId',
                                      isEqualTo: usuario?.uid ?? ''),
                              where: (data) =>
                                  effectiveVisitorStatus(data) ==
                                  'Aguardando autorização',
                              icon: Icons.door_front_door,
                              title: 'Visitantes',
                              subtitleBuilder: (quantidade) =>
                                  '$quantidade aguardando autorização',
                              onTap: () =>
                                  _goTo(context, const VisitantesScreen()),
                            ),
                            LiveHomeCard(
                              query: FirebaseFirestore.instance
                                  .collection('reservas')
                                  .where('moradorId',
                                      isEqualTo: usuario?.uid ?? ''),
                              where: (data) => ['Em análise', 'Aprovada']
                                  .contains(data['status']),
                              icon: Icons.calendar_month,
                              title: 'Reservas',
                              subtitleBuilder: (quantidade) =>
                                  '$quantidade reservas ativas',
                              onTap: () =>
                                  _goTo(context, const ReservasScreen()),
                            ),
                            LiveHomeCard(
                              query: FirebaseFirestore.instance
                                  .collection('encomendas')
                                  .where('moradorId',
                                      isEqualTo: usuario?.uid ?? ''),
                              where: (data) =>
                                  data['status'] == 'Disponível para retirada',
                              icon: Icons.inventory_2,
                              title: 'Encomendas',
                              subtitleBuilder: (quantidade) =>
                                  '$quantidade disponíveis para retirada',
                              onTap: () =>
                                  _goTo(context, const EncomendasScreen()),
                            ),
                            LiveHomeCard(
                              query: FirebaseFirestore.instance
                                  .collection('documentos'),
                              icon: Icons.description,
                              title: 'Documentos',
                              subtitleBuilder: (quantidade) => quantidade == 1
                                  ? '1 documento disponível'
                                  : '$quantidade documentos disponíveis',
                              onTap: () => _goTo(
                                  context, const DocumentosNormasScreen()),
                            ),
                            LiveHomeCard(
                              query: FirebaseFirestore.instance
                                  .collection('solicitacoes_atendimento')
                                  .where('moradorId',
                                      isEqualTo: usuario?.uid ?? ''),
                              where: (data) => data['status'] == 'Em análise',
                              icon: Icons.support_agent,
                              title: 'Atendimento',
                              subtitleBuilder: (quantidade) =>
                                  '$quantidade solicitações em análise',
                              onTap: () =>
                                  _goTo(context, const AtendimentoScreen()),
                            ),
                          ],
                        ),
                      ),
                      const Center(
                        child: Text(
                          'CondoHub • Gestão condominial',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF9CA3AF),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
