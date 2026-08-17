import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/push_notifications_service.dart';
import '../../core/reservation_areas_repository.dart';
import '../../core/visitor_access.dart';
import '../../widgets/live_home_card.dart';
import '../../widgets/notification_bell.dart';
import 'admin_avisos_screen.dart';
import 'admin_documentos_screen.dart';
import 'admin_encomendas_screen.dart';
import 'admin_moradores_screen.dart';
import 'admin_reservas_screen.dart';
import 'admin_solicitacoes_screen.dart';
import 'admin_visitantes_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  @override
  void initState() {
    super.initState();
    _prepararAreas();
  }

  Future<void> _prepararAreas() async {
    try {
      await ReservationAreasRepository.garantirAreasPadrao();
    } catch (_) {
      // A tela de reservas permite tentar novamente se houver falha.
    }
  }

  void _goTo(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  String _contador(int valor, String singular, String plural) {
    return '$valor ${valor == 1 ? singular : plural}';
  }

  Future<void> _sair() async {
    final usuario = FirebaseAuth.instance.currentUser;
    if (usuario != null) {
      await PushNotificationsService.desregistrarDispositivoAtual(usuario.uid);
    }
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
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
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Painel administrativo',
                                  style: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  'Indicadores atualizados em tempo real.',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const NotificationBell(),
                          IconButton(
                            tooltip: 'Sair',
                            onPressed: _sair,
                            icon: const Icon(
                              Icons.logout,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
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
                                  .collection('solicitacoes_atendimento')
                                  .where('status', isEqualTo: 'Em análise'),
                              icon: Icons.support_agent,
                              title: 'Solicitações',
                              subtitleBuilder: (quantidade) => _contador(
                                  quantidade, 'em análise', 'em análise'),
                              onTap: () =>
                                  _goTo(const AdminSolicitacoesScreen()),
                            ),
                            LiveHomeCard(
                              query: FirebaseFirestore.instance
                                  .collection('reservas')
                                  .where('status', isEqualTo: 'Em análise'),
                              icon: Icons.calendar_month,
                              title: 'Reservas',
                              subtitleBuilder: (quantidade) => _contador(
                                  quantidade, 'em análise', 'em análise'),
                              onTap: () => _goTo(const AdminReservasScreen()),
                            ),
                            LiveHomeCard(
                              query: FirebaseFirestore.instance
                                  .collection('avisos'),
                              icon: Icons.campaign,
                              title: 'Avisos',
                              subtitleBuilder: (quantidade) => _contador(
                                quantidade,
                                'aviso publicado',
                                'avisos publicados',
                              ),
                              onTap: () => _goTo(const AdminAvisosScreen()),
                            ),
                            LiveHomeCard(
                              query: FirebaseFirestore.instance
                                  .collection('encomendas')
                                  .where(
                                    'status',
                                    isEqualTo: 'Disponível para retirada',
                                  ),
                              icon: Icons.inventory_2,
                              title: 'Encomendas',
                              subtitleBuilder: (quantidade) =>
                                  '$quantidade para retirada',
                              onTap: () => _goTo(const AdminEncomendasScreen()),
                            ),
                            LiveHomeCard(
                              query: FirebaseFirestore.instance
                                  .collection('acessos_visitantes')
                                  .where(
                                    'status',
                                    isEqualTo: 'Aguardando autorização',
                                  ),
                              where: (data) =>
                                  effectiveVisitorStatus(data) ==
                                  'Aguardando autorização',
                              icon: Icons.badge,
                              title: 'Visitantes',
                              subtitleBuilder: (quantidade) =>
                                  '$quantidade aguardando autorização',
                              onTap: () => _goTo(const AdminVisitantesScreen()),
                            ),
                            LiveHomeCard(
                              query: FirebaseFirestore.instance
                                  .collection('documentos'),
                              icon: Icons.description,
                              title: 'Documentos',
                              subtitleBuilder: (quantidade) => _contador(
                                quantidade,
                                'documento cadastrado',
                                'documentos cadastrados',
                              ),
                              onTap: () => _goTo(const AdminDocumentosScreen()),
                            ),
                            LiveHomeCard(
                              query: FirebaseFirestore.instance
                                  .collection('usuarios')
                                  .where(
                                    'tipoUsuario',
                                    isEqualTo: 'morador',
                                  ),
                              icon: Icons.people,
                              title: 'Moradores',
                              subtitleBuilder: (quantidade) => _contador(
                                quantidade,
                                'morador cadastrado',
                                'moradores cadastrados',
                              ),
                              onTap: () => _goTo(const AdminMoradoresScreen()),
                            ),
                          ],
                        ),
                      ),
                      const Center(
                        child: Text(
                          'CondoHub • Administração condominial',
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
