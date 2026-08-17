import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_helpers.dart';
import 'cadastro_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final senhaController = TextEditingController();

  bool carregando = false;

  @override
  void dispose() {
    emailController.dispose();
    senhaController.dispose();
    super.dispose();
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
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

  Future<void> entrar() async {
    final email = emailController.text.trim().toLowerCase();
    final senha = senhaController.text.trim();

    if (email.isEmpty || senha.isEmpty) {
      showWarning(context, 'Preencha e-mail e senha.');
      return;
    }

    setState(() {
      carregando = true;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: senha,
      );
    } on FirebaseAuthException catch (e) {
      String mensagem = 'Erro ao fazer login.';

      if (e.code == 'user-not-found') {
        mensagem = 'Usuário não encontrado.';
      } else if (e.code == 'wrong-password') {
        mensagem = 'Senha incorreta.';
      } else if (e.code == 'invalid-email') {
        mensagem = 'E-mail inválido.';
      } else if (e.code == 'invalid-credential') {
        mensagem = 'E-mail ou senha inválidos.';
      }

      if (mounted) {
        showError(context, mensagem);
      }
    } finally {
      if (mounted) {
        setState(() {
          carregando = false;
        });
      }
    }
  }

  Future<void> recuperarSenha() async {
    final recuperacaoEmailController = TextEditingController(
      text: emailController.text.trim().toLowerCase(),
    );
    var enviando = false;
    String? mensagemErro;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> enviarLink() async {
              final email =
                  recuperacaoEmailController.text.trim().toLowerCase();

              if (email.isEmpty) {
                setDialogState(() {
                  mensagemErro = 'Informe seu e-mail.';
                });
                return;
              }

              setDialogState(() {
                enviando = true;
                mensagemErro = null;
              });

              var envioConcluido = false;

              try {
                await FirebaseAuth.instance.sendPasswordResetEmail(
                  email: email,
                );
                envioConcluido = true;
              } on FirebaseAuthException catch (e) {
                if (e.code == 'user-not-found') {
                  envioConcluido = true;
                } else {
                  final mensagem = switch (e.code) {
                    'invalid-email' => 'Informe um e-mail válido.',
                    'too-many-requests' =>
                      'Muitas tentativas. Aguarde alguns minutos e tente novamente.',
                    'network-request-failed' =>
                      'Não foi possível conectar. Verifique sua internet.',
                    _ => 'Não foi possível enviar o link. Tente novamente.',
                  };

                  if (dialogContext.mounted) {
                    setDialogState(() {
                      enviando = false;
                      mensagemErro = mensagem;
                    });
                  }
                }
              }

              if (!envioConcluido || !dialogContext.mounted || !mounted) {
                return;
              }

              Navigator.of(dialogContext).pop();
              showSuccess(
                this.context,
                'Se houver uma conta cadastrada com esse e-mail, enviaremos '
                'as instruções de recuperação.',
              );
            }

            return AlertDialog(
              title: const Text('Recuperar senha'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Informe seu e-mail para receber um link de redefinição de senha.',
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: recuperacaoEmailController,
                    autofocus: true,
                    enabled: !enviando,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) {
                      if (!enviando) {
                        enviarLink();
                      }
                    },
                    decoration: _inputDecoration(
                      label: 'E-mail',
                      icon: Icons.email_outlined,
                    ).copyWith(errorText: mensagemErro),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed:
                      enviando ? null : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: enviando ? null : enviarLink,
                  child: enviando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Enviar link'),
                ),
              ],
            );
          },
        );
      },
    );

    recuperacaoEmailController.dispose();
  }

  void abrirCadastro() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CadastroScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: const Icon(
                        Icons.apartment,
                        size: 40,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'CondoHub',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Gestão condominial digital',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 32),
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
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) {
                        if (!carregando) {
                          entrar();
                        }
                      },
                      decoration: _inputDecoration(
                        label: 'Senha',
                        icon: Icons.lock_outline,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: carregando ? null : recuperarSenha,
                        child: const Text(
                          'Esqueci minha senha',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
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
                        onPressed: carregando ? null : entrar,
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
                                'Entrar',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text(
                          'Ainda não tem conta?',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        TextButton(
                          onPressed: carregando ? null : abrirCadastro,
                          child: const Text(
                            'Criar conta',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
