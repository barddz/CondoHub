import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_helpers.dart';
import '../../core/in_app_notifications_repository.dart';
import '../../widgets/admin_form_section.dart';
import '../../widgets/base_screen.dart';
import '../../widgets/info_card.dart';
import '../../widgets/list_category_filter.dart';
import '../../widgets/resident_selector.dart';
import '../../widgets/status_chip.dart';

class AdminEncomendasScreen extends StatefulWidget {
  const AdminEncomendasScreen({super.key});

  @override
  State<AdminEncomendasScreen> createState() => _AdminEncomendasScreenState();
}

class _AdminEncomendasScreenState extends State<AdminEncomendasScreen> {
  final origemController = TextEditingController();
  final observacaoController = TextEditingController();
  ResidentOption? moradorSelecionado;
  int seletorVersion = 0;

  bool enviando = false;
  String statusSelecionado = 'Todos';

  @override
  void dispose() {
    origemController.dispose();
    observacaoController.dispose();
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

  Future<void> _cadastrarEncomenda() async {
    final origem = origemController.text.trim();
    final observacao = observacaoController.text.trim();

    if (moradorSelecionado == null || origem.isEmpty) {
      showWarning(
          context, 'Selecione o morador e informe a origem da encomenda.');
      return;
    }

    setState(() {
      enviando = true;
    });

    try {
      final morador = moradorSelecionado!;

      final encomendaRef =
          await FirebaseFirestore.instance.collection('encomendas').add({
        'moradorId': morador.id,
        'moradorNome': morador.nome,
        'moradorEmail': morador.email,
        'origem': origem,
        'observacao': observacao,
        'status': 'Disponível para retirada',
        'recebidoEm': FieldValue.serverTimestamp(),
        'retiradoEm': null,
        'criadoEm': FieldValue.serverTimestamp(),
        'atualizadoEm': FieldValue.serverTimestamp(),
      });

      await InAppNotificationsRepository.notificarMorador(
        moradorId: morador.id,
        titulo: 'Nova encomenda na portaria',
        mensagem: 'Uma encomenda de $origem está disponível para retirada.',
        tipo: 'encomenda',
        referenciaId: encomendaRef.id,
      );

      origemController.clear();
      observacaoController.clear();
      setState(() {
        moradorSelecionado = null;
        seletorVersion++;
      });

      if (mounted) {
        showSuccess(context, 'Encomenda cadastrada com sucesso.');
      }
    } catch (_) {
      if (mounted) {
        showError(context, 'Erro ao cadastrar encomenda. Tente novamente.');
      }
    } finally {
      if (mounted) {
        setState(() {
          enviando = false;
        });
      }
    }
  }

  Future<void> _atualizarStatus(
    DocumentReference<Map<String, dynamic>> referencia,
    String novoStatus,
  ) async {
    try {
      await referencia.update({
        'status': novoStatus,
        'retiradoEm': novoStatus == 'Retirada concluída'
            ? FieldValue.serverTimestamp()
            : null,
        'atualizadoEm': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        showSuccess(context, 'Status da encomenda atualizado.');
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao atualizar encomenda.'),
          ),
        );
      }
    }
  }

  Future<void> _excluirEncomenda(String id) async {
    try {
      await FirebaseFirestore.instance
          .collection('encomendas')
          .doc(id)
          .delete();

      if (mounted) {
        showSuccess(context, 'Encomenda excluída.');
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao excluir encomenda.'),
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
          title: const Text('Excluir encomenda'),
          content: const Text(
            'Tem certeza que deseja excluir esta encomenda retirada?',
          ),
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
                'Excluir',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );

    if (confirmou == true) {
      await _excluirEncomenda(id);
    }
  }

  Widget _formularioEncomenda({bool compacto = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: defaultCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!compacto) ...[
            const Text(
              'Nova encomenda',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
          ],
          ResidentSelector(
            key: ValueKey(seletorVersion),
            value: moradorSelecionado,
            onChanged: (morador) =>
                setState(() => moradorSelecionado = morador),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: origemController,
            decoration: const InputDecoration(
              labelText: 'Origem / Loja',
              hintText: 'Ex: Amazon, Mercado Livre, Shopee',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: observacaoController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Observação',
              hintText: 'Ex: pacote pequeno, caixa grande, envelope...',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: enviando ? null : _cadastrarEncomenda,
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
                      'Cadastrar encomenda',
                      style: TextStyle(color: Colors.white),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _listaEncomendas() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('encomendas').snapshots(),
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
            title: 'Erro ao carregar encomendas',
            description: 'Não foi possível carregar as encomendas cadastradas.',
            footer: 'Tente novamente mais tarde',
            footerColor: Color(0xFFDC2626),
          );
        }

        final documentos = [...(snapshot.data?.docs ?? [])];

        documentos.sort((a, b) {
          final dataA = a.data()['recebidoEm'];
          final dataB = b.data()['recebidoEm'];

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
            title: 'Nenhuma encomenda cadastrada',
            description:
                'As encomendas cadastradas pela portaria aparecerão nesta lista.',
            footer: 'Aguardando novas entregas',
          );
        }

        final encomendasFiltradas = documentos.where((doc) {
          final dados = doc.data();
          final status =
              dados['status']?.toString() ?? 'Disponível para retirada';
          final correspondeStatus =
              statusSelecionado == 'Todos' || status == statusSelecionado;

          return correspondeStatus;
        }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListCategoryFilter(
              selectedValue: statusSelecionado,
              options: const [
                'Todos',
                'Disponível para retirada',
                'Retirada concluída',
              ],
              onChanged: (value) {
                setState(() {
                  statusSelecionado = value ?? 'Todos';
                });
              },
            ),
            const SizedBox(height: 16),
            if (encomendasFiltradas.isEmpty)
              const InfoCard(
                title: 'Nenhum resultado encontrado',
                description: 'Não há encomendas com o status selecionado.',
                footer: 'Selecione outra categoria para continuar',
              ),
            if (encomendasFiltradas.isNotEmpty)
              Text(
                'Encomendas cadastradas (${encomendasFiltradas.length})',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            if (encomendasFiltradas.isNotEmpty) const SizedBox(height: 12),
            ...encomendasFiltradas.map((doc) {
              final dados = doc.data();

              final origem = dados['origem'] ?? 'Origem não informada';
              final observacao = dados['observacao'] ?? '';
              final status = dados['status'] ?? 'Disponível para retirada';
              final moradorNome =
                  dados['moradorNome'] ?? 'Morador não informado';
              final moradorEmail =
                  dados['moradorEmail'] ?? 'E-mail não informado';
              final recebidoEm = dados['recebidoEm'];
              final retiradoEm = dados['retiradoEm'];

              final descricaoRetirada = status == 'Retirada concluída'
                  ? '\nRetirada em: ${_formatarData(retiradoEm)}'
                  : '';

              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: defaultCardDecoration(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.inventory_2_outlined,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              origem.toString(),
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Morador: $moradorNome\n'
                        'E-mail: $moradorEmail\n'
                        'Recebida em: ${_formatarData(recebidoEm)}'
                        '$descricaoRetirada'
                        '${observacao.toString().trim().isEmpty ? '' : '\n\nObservação: $observacao'}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      StatusChip(status: status),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: [
                          'Disponível para retirada',
                          'Retirada concluída',
                        ].contains(status)
                            ? status
                            : 'Disponível para retirada',
                        decoration: const InputDecoration(
                          labelText: 'Alterar status',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'Disponível para retirada',
                            child: Text('Disponível para retirada'),
                          ),
                          DropdownMenuItem(
                            value: 'Retirada concluída',
                            child: Text('Retirada concluída'),
                          ),
                        ],
                        onChanged: (novoStatus) {
                          if (novoStatus == null || novoStatus == status) {
                            return;
                          }

                          _atualizarStatus(doc.reference, novoStatus);
                        },
                      ),
                      if (status == 'Retirada concluída') ...[
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
                              'Excluir encomenda',
                              style: TextStyle(
                                color: Color(0xFFDC2626),
                              ),
                            ),
                          ),
                        ),
                      ],
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
      title: 'Encomendas',
      subtitle: 'Cadastre entregas recebidas na portaria',
      children: [
        AdminFormSection(
          title: 'Cadastrar nova encomenda',
          subtitle: 'Registre uma entrega recebida na portaria',
          icon: Icons.add_box_outlined,
          child: _formularioEncomenda(compacto: true),
        ),
        _listaEncomendas(),
      ],
    );
  }
}
