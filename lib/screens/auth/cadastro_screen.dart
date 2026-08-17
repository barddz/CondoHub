import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_helpers.dart';

class CadastroScreen extends StatefulWidget {
  const CadastroScreen({super.key});

  @override
  State<CadastroScreen> createState() => _CadastroScreenState();
}

class _CadastroScreenState extends State<CadastroScreen> {
  final nomeController = TextEditingController();
  final sobrenomeController = TextEditingController();
  final telefoneController = TextEditingController();
  final blocoController = TextEditingController();
  final apartamentoController = TextEditingController();
  final idadeController = TextEditingController();
  final emailController = TextEditingController();
  final senhaController = TextEditingController();
  final confirmarSenhaController = TextEditingController();

  bool carregando = false;

  @override
  void dispose() {
    nomeController.dispose();
    sobrenomeController.dispose();
    telefoneController.dispose();
    blocoController.dispose();
    apartamentoController.dispose();
    idadeController.dispose();
    emailController.dispose();
    senhaController.dispose();
    confirmarSenhaController.dispose();
    super.dispose();
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: AppColors.primary),
      filled: true,
      fillColor: const Color(0xFFF3F4F6),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: AppColors.primary,
          width: 1.4,
        ),
      ),
    );
  }

  Future<void> _desfazerCadastro(User? usuario) async {
    if (usuario == null) {
      return;
    }

    try {
      await usuario.delete();
    } catch (_) {
      await FirebaseAuth.instance.signOut();
    }
  }

  Future<void> criarConta() async {
    final nome = nomeController.text.trim();
    final sobrenome = sobrenomeController.text.trim();
    final telefone = telefoneController.text.trim();
    final bloco = blocoController.text.trim();
    final apartamento = apartamentoController.text.trim();
    final idadeTexto = idadeController.text.trim();
    final email = emailController.text.trim().toLowerCase();
    final senha = senhaController.text.trim();
    final confirmarSenha = confirmarSenhaController.text.trim();

    if (nome.isEmpty ||
        sobrenome.isEmpty ||
        email.isEmpty ||
        senha.isEmpty ||
        confirmarSenha.isEmpty) {
      showWarning(context, 'Preencha nome, sobrenome, e-mail e senha.');
      return;
    }

    if (senha.length < 6) {
      showWarning(context, 'A senha deve ter pelo menos 6 caracteres.');
      return;
    }

    if (senha != confirmarSenha) {
      showWarning(context, 'As senhas não coincidem.');
      return;
    }

    int? idade;

    if (idadeTexto.isNotEmpty) {
      idade = int.tryParse(idadeTexto);

      if (idade == null || idade <= 0 || idade > 130) {
        showWarning(context, 'Informe uma idade válida.');
        return;
      }
    }

    setState(() {
      carregando = true;
    });

    User? usuarioCriado;
    bool perfilSalvo = false;

    try {
      final credencial =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: senha,
      );

      final usuario = credencial.user;
      usuarioCriado = usuario;
      final nomeCompleto = '$nome $sobrenome';

      if (usuario == null) {
        throw StateError('Conta criada sem usuário disponível.');
      }

      await usuario.updateDisplayName(nomeCompleto);

      final dadosUsuario = <String, dynamic>{
        'uid': usuario.uid,
        'nome': nome,
        'sobrenome': sobrenome,
        'nomeCompleto': nomeCompleto,
        'telefone': telefone,
        'bloco': bloco,
        'apartamento': apartamento,
        'email': usuario.email?.trim().toLowerCase() ?? email,
        'tipoUsuario': 'morador',
        'criadoEm': FieldValue.serverTimestamp(),
        'atualizadoEm': FieldValue.serverTimestamp(),
      };

      if (idade != null) {
        dadosUsuario['idade'] = idade;
      }

      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(usuario.uid)
          .set(dadosUsuario);
      perfilSalvo = true;

      if (mounted) {
        showSuccess(context, 'Conta criada com sucesso.');
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      if (!perfilSalvo) {
        await _desfazerCadastro(usuarioCriado);
      }

      String mensagem = 'Erro ao criar conta.';

      if (e.code == 'email-already-in-use') {
        mensagem = 'Este e-mail já está cadastrado.';
      } else if (e.code == 'invalid-email') {
        mensagem = 'E-mail inválido.';
      } else if (e.code == 'weak-password') {
        mensagem = 'Senha muito fraca.';
      }

      if (mounted) {
        showError(context, mensagem);
      }
    } on FirebaseException catch (e) {
      if (!perfilSalvo) {
        await _desfazerCadastro(usuarioCriado);
      }

      String mensagem = 'Erro ao salvar dados.';

      if (e.code == 'permission-denied') {
        mensagem = 'Permissão negada ao salvar os dados.';
      }

      if (mounted) {
        showError(context, mensagem);
      }
    } catch (_) {
      if (!perfilSalvo) {
        await _desfazerCadastro(usuarioCriado);
      }

      if (mounted) {
        showError(context, 'Erro inesperado ao criar conta.');
      }
    } finally {
      if (mounted) {
        setState(() {
          carregando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: carregando ? null : () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.arrow_back,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Criar conta',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Preencha seus dados para acessar os serviços do condomínio.',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      TextField(
                        controller: nomeController,
                        textInputAction: TextInputAction.next,
                        decoration: _inputDecoration(
                          label: 'Nome',
                          icon: Icons.person_outline,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: sobrenomeController,
                        textInputAction: TextInputAction.next,
                        decoration: _inputDecoration(
                          label: 'Sobrenome',
                          icon: Icons.person_outline,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: telefoneController,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        decoration: _inputDecoration(
                          label: 'Telefone',
                          icon: Icons.phone_outlined,
                          hint: '(19) 99999-9999',
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: blocoController,
                              textInputAction: TextInputAction.next,
                              decoration: _inputDecoration(
                                label: 'Bloco',
                                icon: Icons.business_outlined,
                                hint: 'A',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: apartamentoController,
                              textInputAction: TextInputAction.next,
                              decoration: _inputDecoration(
                                label: 'Apto',
                                icon: Icons.home_outlined,
                                hint: '101',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: idadeController,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                        decoration: _inputDecoration(
                          label: 'Idade',
                          icon: Icons.cake_outlined,
                          hint: 'Opcional',
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        decoration: _inputDecoration(
                          label: 'E-mail',
                          icon: Icons.email_outlined,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: senhaController,
                        obscureText: true,
                        textInputAction: TextInputAction.next,
                        decoration: _inputDecoration(
                          label: 'Senha',
                          icon: Icons.lock_outline,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: confirmarSenhaController,
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) {
                          if (!carregando) {
                            criarConta();
                          }
                        },
                        decoration: _inputDecoration(
                          label: 'Confirmar senha',
                          icon: Icons.lock_outline,
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: carregando ? null : criarConta,
                          child: carregando
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : const Text(
                                  'Criar conta',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
