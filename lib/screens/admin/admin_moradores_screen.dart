import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_helpers.dart';
import '../../widgets/base_screen.dart';
import '../../widgets/info_card.dart';

class AdminMoradoresScreen extends StatefulWidget {
  const AdminMoradoresScreen({super.key});

  @override
  State<AdminMoradoresScreen> createState() => _AdminMoradoresScreenState();
}

class _AdminMoradoresScreenState extends State<AdminMoradoresScreen> {
  final _buscaController = TextEditingController();
  String _busca = '';

  @override
  void dispose() {
    _buscaController.dispose();
    super.dispose();
  }

  String _texto(dynamic valor, String fallback) {
    if (valor is String && valor.trim().isNotEmpty) {
      return valor.trim();
    }

    if (valor is int) {
      return valor.toString();
    }

    return fallback;
  }

  void _abrirDetalhesMorador(
    BuildContext context,
    Map<String, dynamic> dados,
  ) {
    final nome = _texto(dados['nomeCompleto'], 'Morador');
    final email = _texto(dados['email'], 'Não informado');
    final telefone = _texto(dados['telefone'], 'Não informado');
    final bloco = _texto(dados['bloco'], 'Não informado');
    final apartamento = _texto(dados['apartamento'], 'Não informado');
    final idade = _texto(dados['idade'], 'Não informada');

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(nome),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('E-mail: $email'),
              const SizedBox(height: 8),
              Text('Telefone: $telefone'),
              const SizedBox(height: 8),
              Text('Bloco: $bloco'),
              const SizedBox(height: 8),
              Text('Apartamento: $apartamento'),
              const SizedBox(height: 8),
              Text('Idade: $idade'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Fechar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BaseScreen(
      title: 'Moradores',
      subtitle: 'Dados dos moradores cadastrados',
      children: [
        TextField(
          controller: _buscaController,
          onChanged: (valor) {
            setState(() {
              _busca = valor.trim().toLowerCase();
            });
          },
          decoration: InputDecoration(
            labelText: 'Pesquisar moradores',
            hintText: 'Nome, e-mail, bloco ou apartamento',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _busca.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Limpar pesquisa',
                    onPressed: () {
                      _buscaController.clear();
                      setState(() => _busca = '');
                    },
                    icon: const Icon(Icons.close),
                  ),
          ),
        ),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('usuarios').snapshots(),
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
                title: 'Erro ao carregar moradores',
                description:
                    'Não foi possível buscar os moradores cadastrados.',
                footer: 'Tente novamente mais tarde',
                footerColor: Color(0xFFDC2626),
              );
            }

            final documentos = [...(snapshot.data?.docs ?? [])];

            final todosMoradores = documentos.where((doc) {
              final dados = doc.data();
              return dados['tipoUsuario'] != 'admin';
            }).toList();

            final moradores = todosMoradores.where((doc) {
              if (_busca.isEmpty) {
                return true;
              }

              final dados = doc.data();
              final termos = [
                dados['nomeCompleto'],
                dados['nome'],
                dados['sobrenome'],
                dados['email'],
                dados['bloco'],
                dados['apartamento'],
              ].where((valor) => valor != null).join(' ').toLowerCase();

              return termos.contains(_busca);
            }).toList();

            moradores.sort((a, b) {
              final nomeA = _texto(a.data()['nomeCompleto'], '');
              final nomeB = _texto(b.data()['nomeCompleto'], '');
              return nomeA.compareTo(nomeB);
            });

            if (todosMoradores.isEmpty) {
              return const InfoCard(
                title: 'Nenhum morador cadastrado',
                description:
                    'Os moradores cadastrados no aplicativo aparecerão nesta tela.',
                footer: 'Aguardando cadastros',
                leadingIcon: Icons.people_outline,
              );
            }

            if (moradores.isEmpty) {
              return InfoCard(
                title: 'Nenhum morador encontrado',
                description:
                    'Não há moradores correspondentes a “${_buscaController.text.trim()}”.',
                footer: 'Tente outro nome, e-mail, bloco ou apartamento',
                leadingIcon: Icons.person_search_outlined,
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  moradores.length == 1
                      ? '1 morador encontrado'
                      : '${moradores.length} moradores encontrados',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                ...moradores.map((doc) {
                  final dados = doc.data();

                  final nome = _texto(dados['nomeCompleto'], 'Morador');
                  final email = _texto(dados['email'], 'Não informado');
                  final telefone = _texto(dados['telefone'], 'Não informado');
                  final bloco = _texto(dados['bloco'], 'Não informado');
                  final apartamento =
                      _texto(dados['apartamento'], 'Não informado');

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: defaultCardDecoration(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            nome,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'E-mail: $email\n'
                            'Telefone: $telefone\n'
                            'Bloco: $bloco • Apartamento: $apartamento',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  _abrirDetalhesMorador(context, dados),
                              icon: const Icon(Icons.visibility_outlined),
                              label: const Text('Ver detalhes'),
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
        ),
      ],
    );
  }
}
