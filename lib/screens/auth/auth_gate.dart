import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../widgets/in_app_notifications_host.dart';
import '../admin/admin_home_screen.dart';
import '../home/home_screen.dart';
import 'login_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  String? _perfilUid;
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _perfilStream;

  Stream<DocumentSnapshot<Map<String, dynamic>>> _acompanharPerfil(
    User usuario,
  ) {
    if (_perfilUid != usuario.uid || _perfilStream == null) {
      _perfilUid = usuario.uid;
      _perfilStream = FirebaseFirestore.instance
          .collection('usuarios')
          .doc(usuario.uid)
          .snapshots();
    }

    return _perfilStream!;
  }

  void _tentarNovamente(User usuario) {
    setState(() {
      _perfilUid = usuario.uid;
      _perfilStream = FirebaseFirestore.instance
          .collection('usuarios')
          .doc(usuario.uid)
          .snapshots();
    });
  }

  Widget _telaDeEstado({
    required User usuario,
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Card(
                color: AppColors.card,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 44, color: AppColors.primary),
                      const SizedBox(height: 16),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => _tentarNovamente(usuario),
                          child: const Text('Tentar novamente'),
                        ),
                      ),
                      TextButton(
                        onPressed: FirebaseAuth.instance.signOut,
                        child: const Text('Sair da conta'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final usuario = authSnapshot.data;

        if (usuario == null) {
          _perfilUid = null;
          _perfilStream = null;
          return const LoginScreen();
        }

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _acompanharPerfil(usuario),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }

            if (userSnapshot.hasError) {
              return _telaDeEstado(
                usuario: usuario,
                icon: Icons.cloud_off_outlined,
                title: 'Não foi possível carregar seu perfil',
                message:
                    'Verifique sua conexão e tente novamente em alguns instantes.',
              );
            }

            if (userSnapshot.data?.exists != true) {
              return _telaDeEstado(
                usuario: usuario,
                icon: Icons.person_off_outlined,
                title: 'Cadastro incompleto',
                message:
                    'Não encontramos os dados desta conta. Tente novamente ou entre com outra conta.',
              );
            }

            final tipoUsuario = userSnapshot.data!.data()?['tipoUsuario'];

            if (tipoUsuario == 'admin') {
              return const InAppNotificationsHost(
                child: AdminHomeScreen(),
              );
            }

            if (tipoUsuario == 'morador') {
              return const InAppNotificationsHost(
                child: HomeScreen(),
              );
            }

            return _telaDeEstado(
              usuario: usuario,
              icon: Icons.manage_accounts_outlined,
              title: 'Perfil sem acesso definido',
              message:
                  'Procure a administração do condomínio para revisar seu cadastro.',
            );
          },
        );
      },
    );
  }
}
