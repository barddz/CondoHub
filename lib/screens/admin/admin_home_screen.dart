import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_helpers.dart';
import '../../widgets/home_card.dart';
import 'admin_solicitacoes_screen.dart';

class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  void _goTo(BuildContext context, Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  void _moduloFuturo(BuildContext context) {
    showSuccess(
      context,
      'Módulo administrativo previsto para uma próxima etapa.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(
                    child: Text(
                      'Painel administrativo',
                      style: TextStyle(
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
              ),
              const SizedBox(height: 8),
              const Text(
                'Gerencie informações e solicitações do condomínio.',
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
                      icon: Icons.support_agent,
                      title: 'Solicitações',
                      onTap: () => _goTo(
                        context,
                        const AdminSolicitacoesScreen(),
                      ),
                    ),
                    HomeCard(
                      icon: Icons.calendar_month,
                      title: 'Reservas',
                      onTap: () => _moduloFuturo(context),
                    ),
                    HomeCard(
                      icon: Icons.campaign,
                      title: 'Avisos',
                      onTap: () => _moduloFuturo(context),
                    ),
                    HomeCard(
                      icon: Icons.inventory_2,
                      title: 'Encomendas',
                      onTap: () => _moduloFuturo(context),
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
  }
}
