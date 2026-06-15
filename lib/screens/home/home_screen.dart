import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../widgets/home_card.dart';
import '../atendimento/atendimento_screen.dart';
import '../avisos/avisos_screen.dart';
import '../documentos/documentos_normas_screen.dart';
import '../encomendas/encomendas_screen.dart';
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
        child: Padding(
          padding: const EdgeInsets.all(24),
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
                  String nomeUsuario = _nomePeloEmailOuDisplayName(usuario);

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
                      IconButton(
                        tooltip: 'Sair',
                        onPressed: () async {
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
                'O que você deseja acessar?',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 32),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  children: [
                    HomeCard(
                      icon: Icons.campaign,
                      title: 'Avisos',
                      onTap: () => _goTo(context, const AvisosScreen()),
                    ),
                    HomeCard(
                      icon: Icons.door_front_door,
                      title: 'Visitantes',
                      onTap: () => _goTo(context, const VisitantesScreen()),
                    ),
                    HomeCard(
                      icon: Icons.calendar_month,
                      title: 'Reservas',
                      onTap: () => _goTo(context, const ReservasScreen()),
                    ),
                    HomeCard(
                      icon: Icons.inventory_2,
                      title: 'Encomendas',
                      onTap: () => _goTo(context, const EncomendasScreen()),
                    ),
                    HomeCard(
                      icon: Icons.description,
                      title: 'Documentos',
                      onTap: () =>
                          _goTo(context, const DocumentosNormasScreen()),
                    ),
                    HomeCard(
                      icon: Icons.support_agent,
                      title: 'Atendimento',
                      onTap: () => _goTo(context, const AtendimentoScreen()),
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
  }
}
