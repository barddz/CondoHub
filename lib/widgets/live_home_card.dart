import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'home_card.dart';

class LiveHomeCard extends StatelessWidget {
  final Query<Map<String, dynamic>> query;
  final bool Function(Map<String, dynamic> data)? where;
  final IconData icon;
  final String title;
  final String Function(int count) subtitleBuilder;
  final VoidCallback onTap;

  const LiveHomeCard({
    super.key,
    required this.query,
    this.where,
    required this.icon,
    required this.title,
    required this.subtitleBuilder,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        final count = where == null
            ? docs.length
            : docs.where((doc) => where!(doc.data())).length;
        final subtitle = snapshot.hasError
            ? 'Não foi possível atualizar'
            : snapshot.connectionState == ConnectionState.waiting
                ? 'Carregando...'
                : subtitleBuilder(count);

        return HomeCard(
          icon: icon,
          title: title,
          subtitle: subtitle,
          onTap: onTap,
        );
      },
    );
  }
}
