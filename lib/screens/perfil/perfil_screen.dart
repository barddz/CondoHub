import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_helpers.dart';
import '../../core/push_notifications_service.dart';
import '../../widgets/base_screen.dart';

class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  final PushNotificationsService _pushNotifications =
      PushNotificationsService();
  AuthorizationStatus? _statusNotificacoes;
  bool _carregandoNotificacoes = true;

  @override
  void initState() {
    super.initState();
    _carregarStatusNotificacoes();
  }

  Future<void> _carregarStatusNotificacoes() async {
    final usuario = FirebaseAuth.instance.currentUser;
    final status = usuario == null
        ? null
        : await _pushNotifications.inicializar(usuario.uid);
    if (mounted) {
      setState(() {
        _statusNotificacoes = status;
        _carregandoNotificacoes = false;
      });
    }
  }

  Future<void> _ativarNotificacoes() async {
    setState(() => _carregandoNotificacoes = true);
    final status = await _pushNotifications.solicitarPermissao();
    if (!mounted) return;
    setState(() {
      _statusNotificacoes = status;
      _carregandoNotificacoes = false;
    });

    if (status == AuthorizationStatus.authorized ||
        status == AuthorizationStatus.provisional) {
      showSuccess(context, 'Notificações ativadas neste dispositivo.');
    } else if (status == AuthorizationStatus.denied) {
      showWarning(
        context,
        'A permissão está bloqueada. Ative-a nas configurações do navegador ou do celular.',
      );
    } else {
      showError(context, 'Não foi possível ativar as notificações.');
    }
  }

  @override
  void dispose() {
    _pushNotifications.dispose();
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

  Future<void> _abrirEdicaoPerfil({
    required Map<String, dynamic> dados,
    required User usuario,
  }) async {
    final nomeController = TextEditingController(
      text: _texto(dados['nome'], ''),
    );
    final sobrenomeController = TextEditingController(
      text: _texto(dados['sobrenome'], ''),
    );
    final telefoneController = TextEditingController(
      text: _texto(dados['telefone'], ''),
    );
    final blocoController = TextEditingController(
      text: _texto(dados['bloco'], ''),
    );
    final apartamentoController = TextEditingController(
      text: _texto(dados['apartamento'], ''),
    );
    final idadeController = TextEditingController(
      text: dados['idade'] == null ? '' : dados['idade'].toString(),
    );

    try {
      await showDialog(
        context: context,
        builder: (dialogContext) {
          bool salvando = false;

          return StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              return AlertDialog(
                title: const Text('Editar perfil'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nomeController,
                        decoration: const InputDecoration(
                          labelText: 'Nome',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: sobrenomeController,
                        decoration: const InputDecoration(
                          labelText: 'Sobrenome',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: telefoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Telefone',
                          hintText: 'Ex: (19) 99999-9999',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: blocoController,
                              decoration: const InputDecoration(
                                labelText: 'Bloco',
                                hintText: 'Ex: A',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: apartamentoController,
                              decoration: const InputDecoration(
                                labelText: 'Apartamento',
                                hintText: 'Ex: 101',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: idadeController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Idade',
                          hintText: 'Opcional',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: salvando
                        ? null
                        : () {
                            Navigator.pop(dialogContext);
                          },
                    child: const Text('Cancelar'),
                  ),
                  ElevatedButton(
                    onPressed: salvando
                        ? null
                        : () async {
                            final nome = nomeController.text.trim();
                            final sobrenome = sobrenomeController.text.trim();
                            final telefone = telefoneController.text.trim();
                            final bloco = blocoController.text.trim();
                            final apartamento =
                                apartamentoController.text.trim();
                            final idadeTexto = idadeController.text.trim();

                            if (nome.isEmpty || sobrenome.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Preencha nome e sobrenome.',
                                  ),
                                ),
                              );
                              return;
                            }

                            int? idade;

                            if (idadeTexto.isNotEmpty) {
                              idade = int.tryParse(idadeTexto);

                              if (idade == null || idade <= 0 || idade > 130) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Informe uma idade válida.',
                                    ),
                                  ),
                                );
                                return;
                              }
                            }

                            setDialogState(() {
                              salvando = true;
                            });

                            final nomeCompleto = '$nome $sobrenome';

                            final dadosAtualizados = <String, dynamic>{
                              'nome': nome,
                              'sobrenome': sobrenome,
                              'nomeCompleto': nomeCompleto,
                              'telefone': telefone,
                              'bloco': bloco,
                              'apartamento': apartamento,
                              'atualizadoEm': FieldValue.serverTimestamp(),
                            };

                            if (idade != null) {
                              dadosAtualizados['idade'] = idade;
                            } else {
                              dadosAtualizados['idade'] = FieldValue.delete();
                            }

                            try {
                              await FirebaseFirestore.instance
                                  .collection('usuarios')
                                  .doc(usuario.uid)
                                  .set(
                                    dadosAtualizados,
                                    SetOptions(merge: true),
                                  );

                              await usuario.updateDisplayName(nomeCompleto);

                              if (!mounted || !dialogContext.mounted) {
                                return;
                              }

                              Navigator.pop(dialogContext);

                              showSuccess(
                                context,
                                'Perfil atualizado com sucesso.',
                              );
                            } catch (_) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Erro ao atualizar perfil.',
                                    ),
                                  ),
                                );
                              }

                              if (dialogContext.mounted) {
                                setDialogState(() {
                                  salvando = false;
                                });
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                    ),
                    child: salvando
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Text(
                            'Salvar',
                            style: TextStyle(color: Colors.white),
                          ),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      nomeController.dispose();
      sobrenomeController.dispose();
      telefoneController.dispose();
      blocoController.dispose();
      apartamentoController.dispose();
      idadeController.dispose();
    }
  }

  Widget _linhaPerfil(String label, String valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 105,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              valor,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardPerfil({
    required Map<String, dynamic> dados,
    required User usuario,
  }) {
    final nome = _texto(dados['nome'], '');
    final sobrenome = _texto(dados['sobrenome'], '');
    final nomeCompleto = _texto(
      dados['nomeCompleto'],
      '$nome $sobrenome'.trim().isEmpty ? 'Morador' : '$nome $sobrenome',
    );

    final email = _texto(
      dados['email'],
      usuario.email ?? 'Não informado',
    );

    final telefone = _texto(dados['telefone'], 'Não informado');
    final bloco = _texto(dados['bloco'], 'Não informado');
    final apartamento = _texto(dados['apartamento'], 'Não informado');
    final idade = _texto(dados['idade'], 'Não informada');

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: defaultCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.primary,
                child: Icon(
                  Icons.person,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nomeCompleto,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          _linhaPerfil('Telefone', telefone),
          _linhaPerfil('Bloco', bloco),
          _linhaPerfil('Apartamento', apartamento),
          _linhaPerfil('Idade', idade),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _abrirEdicaoPerfil(
                dados: dados,
                usuario: usuario,
              ),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Editar perfil'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardNotificacoes() {
    final ativa = _statusNotificacoes == AuthorizationStatus.authorized ||
        _statusNotificacoes == AuthorizationStatus.provisional;
    final descricao = _carregandoNotificacoes
        ? 'Verificando este dispositivo...'
        : ativa
            ? 'Ativadas neste dispositivo. Você recebe avisos mesmo fora do CondoHub.'
            : _statusNotificacoes == AuthorizationStatus.denied
                ? 'Bloqueadas neste dispositivo. Os avisos continuam disponíveis na central.'
                : 'Ative para receber avisos mesmo com o CondoHub em segundo plano.';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: defaultCardDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              ativa
                  ? Icons.notifications_active_outlined
                  : Icons.notifications_off_outlined,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Notificações push',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  descricao,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                if (!ativa) ...[
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed:
                        _carregandoNotificacoes ? null : _ativarNotificacoes,
                    icon: const Icon(Icons.notifications_outlined),
                    label: Text(
                      _statusNotificacoes == AuthorizationStatus.denied
                          ? 'Tentar ativar novamente'
                          : 'Ativar notificações',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final usuario = FirebaseAuth.instance.currentUser;

    if (usuario == null) {
      return BaseScreen(
        title: 'Meu perfil',
        subtitle: 'Dados do usuário',
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: defaultCardDecoration(),
            child: const Text(
              'Faça login novamente para visualizar seu perfil.',
              style: TextStyle(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      );
    }

    return BaseScreen(
      title: 'Meu perfil',
      subtitle: 'Dados pessoais e informações do imóvel',
      children: [
        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('usuarios')
              .doc(usuario.uid)
              .snapshots(),
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
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: defaultCardDecoration(),
                child: const Text(
                  'Não foi possível carregar os dados do perfil.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                  ),
                ),
              );
            }

            final dados = snapshot.data?.data() ?? <String, dynamic>{};

            return _cardPerfil(
              dados: dados,
              usuario: usuario,
            );
          },
        ),
        _cardNotificacoes(),
      ],
    );
  }
}
