import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../screens/notificacoes/notificacoes_screen.dart';

class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context) {
    final usuario = FirebaseAuth.instance.currentUser;
    if (usuario == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('notificacoes')
          .where('destinatarioId', isEqualTo: usuario.uid)
          .snapshots(),
      builder: (context, snapshot) {
        final quantidade = (snapshot.data?.docs ?? [])
            .where((doc) => doc.data()['lida'] != true)
            .length;

        return IconButton(
          tooltip: quantidade == 0
              ? 'Notificações'
              : 'Notificações: $quantidade não lidas',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const NotificacoesScreen(),
            ),
          ),
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.notifications_outlined,
                  color: AppColors.primary),
              if (quantidade > 0)
                Positioned(
                  right: -8,
                  top: -7,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 19),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD64545),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Text(
                      quantidade > 99 ? '99+' : '$quantidade',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
