import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_helpers.dart';
import '../../core/in_app_notifications_repository.dart';
import '../../widgets/base_screen.dart';
import '../../widgets/admin_form_section.dart';
import '../../widgets/info_card.dart';

class AdminAvisosScreen extends StatefulWidget {
  const AdminAvisosScreen({super.key});

  @override
  State<AdminAvisosScreen> createState() => _AdminAvisosScreenState();
}

class _AdminAvisosScreenState extends State<AdminAvisosScreen> {
  final tituloController = TextEditingController();
  final mensagemController = TextEditingController();

  bool enviando = false;

  @override
  void dispose() {
    tituloController.dispose();
    mensagemController.dispose();
    super.dispose();
  }

  String _formatarData(dynamic valor) {
    if (valor is! Timestamp) {
      return 'Data não informada';
    }

    final data = valor.toDate();

    final dia = data.day.toString().padLeft(2, '0');
    final mes = data.month.toString().padLeft(2, '0');
    final ano = data.year.toString();
    final hora = data.hour.toString().padLeft(2, '0');
    final minuto = data.minute.toString().padLeft(2, '0');

    return '$dia/$mes/$ano às $hora:$minuto';
  }

  Future<void> _criarAviso() async {
    final titulo = tituloController.text.trim();
    final mensagem = mensagemController.text.trim();

    if (titulo.isEmpty || mensagem.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preencha o título e a mensagem.'),
        ),
      );
      return;
    }

    final usuario = FirebaseAuth.instance.currentUser;

    if (usuario == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Usuário não autenticado.'),
        ),
      );
      return;
    }

    setState(() {
      enviando = true;
    });

    try {
      final avisoRef =
          await FirebaseFirestore.instance.collection('avisos').add({
        'titulo': titulo,
        'mensagem': mensagem,
        'autorId': usuario.uid,
        'autorEmail': usuario.email,
        'criadoEm': FieldValue.serverTimestamp(),
        'atualizadoEm': FieldValue.serverTimestamp(),
      });

      await InAppNotificationsRepository.notificarTodosMoradores(
        titulo: titulo,
        mensagem: mensagem,
        tipo: 'aviso',
        referenciaId: avisoRef.id,
      );

      tituloController.clear();
      mensagemController.clear();

      if (mounted) {
        showSuccess(context, 'Aviso publicado com sucesso.');
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao publicar aviso. Tente novamente.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          enviando = false;
        });
      }
    }
  }

  Future<void> _excluirAviso(String id) async {
    try {
      await FirebaseFirestore.instance.collection('avisos').doc(id).delete();

      if (mounted) {
        showSuccess(context, 'Aviso removido.');
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao remover aviso.'),
          ),
        );
      }
    }
  }

  Future<void> _confirmarExclusao(String id) async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Remover aviso'),
          content: const Text('Tem certeza que deseja remover este aviso?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
              ),
              child: const Text(
                'Remover',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );

    if (confirmou == true) {
      await _excluirAviso(id);
    }
  }

  Widget _formularioAviso({bool compacto = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: defaultCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!compacto) ...[
            const Text(
              'Novo aviso',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
          ],
          TextField(
            controller: tituloController,
            decoration: const InputDecoration(
              labelText: 'Título',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: mensagemController,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Mensagem',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: enviando ? null : _criarAviso,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              child: enviando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : const Text(
                      'Publicar aviso',
                      style: TextStyle(color: Colors.white),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _listaAvisos() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('avisos').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return const InfoCard(
            title: 'Erro ao carregar avisos',
            description: 'Não foi possível carregar os avisos publicados.',
            footer: 'Tente novamente mais tarde',
            footerColor: Color(0xFFDC2626),
          );
        }

        final documentos = [...(snapshot.data?.docs ?? [])];

        documentos.sort((a, b) {
          final dataA = a.data()['criadoEm'];
          final dataB = b.data()['criadoEm'];

          if (dataA is Timestamp && dataB is Timestamp) {
            return dataB.toDate().compareTo(dataA.toDate());
          }

          if (dataA is Timestamp) {
            return -1;
          }

          if (dataB is Timestamp) {
            return 1;
          }

          return 0;
        });

        if (documentos.isEmpty) {
          return const InfoCard(
            title: 'Nenhum aviso publicado',
            description:
                'Os avisos criados pela administração aparecerão nesta lista.',
            footer: 'Aguardando novos comunicados',
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Avisos publicados',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 12),
            ...documentos.map((doc) {
              final dados = doc.data();

              final titulo = dados['titulo'] ?? 'Aviso sem título';
              final mensagem = dados['mensagem'] ?? 'Sem mensagem';
              final criadoEm = dados['criadoEm'];

              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: defaultCardDecoration(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titulo,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        mensagem,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Publicado em: ${_formatarData(criadoEm)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => _confirmarExclusao(doc.id),
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Color(0xFFDC2626),
                          ),
                          label: const Text(
                            'Remover',
                            style: TextStyle(
                              color: Color(0xFFDC2626),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BaseScreen(
      title: 'Avisos',
      subtitle: 'Publique comunicados para os moradores',
      children: [
        AdminFormSection(
          title: 'Publicar novo aviso',
          subtitle: 'Envie um comunicado aos moradores',
          icon: Icons.add_alert_outlined,
          child: _formularioAviso(compacto: true),
        ),
        _listaAvisos(),
      ],
    );
  }
}
