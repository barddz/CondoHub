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
  final emailController = TextEditingController();
  final senhaController = TextEditingController();

  bool carregando = false;

  @override
  void dispose() {
    nomeController.dispose();
    sobrenomeController.dispose();
    emailController.dispose();
    senhaController.dispose();
    super.dispose();
  }

  Future<void> criarConta() async {
    final nome = nomeController.text.trim();
    final sobrenome = sobrenomeController.text.trim();
    final email = emailController.text.trim();
    final senha = senhaController.text.trim();

    if (nome.isEmpty || sobrenome.isEmpty || email.isEmpty || senha.isEmpty) {
      showSuccess(context, 'Preencha todos os campos.');
      return;
    }

    if (senha.length < 6) {
      showSuccess(context, 'A senha deve ter pelo menos 6 caracteres.');
      return;
    }

    setState(() {
      carregando = true;
    });

    try {
      final credencial =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: senha,
      );

      final usuario = credencial.user;
      final nomeCompleto = '$nome $sobrenome';

      await usuario?.updateDisplayName(nomeCompleto);
      await usuario?.reload();

      if (usuario != null) {
        await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(usuario.uid)
            .set({
          'uid': usuario.uid,
          'nome': nome,
          'sobrenome': sobrenome,
          'nomeCompleto': nomeCompleto,
          'email': email,
          'tipoUsuario': 'morador',
          'criadoEm': FieldValue.serverTimestamp(),
        });
      }

      if (mounted) {
        showSuccess(context, 'Conta criada com sucesso.');
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      String mensagem = 'Erro ao criar conta.';

      if (e.code == 'email-already-in-use') {
        mensagem = 'Este email já está cadastrado.';
      } else if (e.code == 'invalid-email') {
        mensagem = 'Email inválido.';
      } else if (e.code == 'weak-password') {
        mensagem = 'Senha muito fraca.';
      }

      if (mounted) {
        showSuccess(context, mensagem);
      }
    } on FirebaseException catch (e) {
      String mensagem = 'Erro ao salvar dados no banco.';

      if (e.code == 'permission-denied') {
        mensagem =
            'Permissão negada no Firestore. Verifique as regras do banco.';
      }

      if (mounted) {
        showSuccess(context, mensagem);
      }
    } catch (_) {
      if (mounted) {
        showSuccess(context, 'Erro inesperado ao criar conta.');
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
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ListView(
            children: [
              IconButton(
                alignment: Alignment.centerLeft,
                onPressed: () => Navigator.pop(context),
                icon: const Icon(
                  Icons.arrow_back,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 24),
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
                'Cadastre seus dados para acessar o CondoHub.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: nomeController,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  hintText: 'Nome',
                  filled: true,
                  fillColor: const Color(0xFFE5E7EB),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: sobrenomeController,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  hintText: 'Sobrenome',
                  filled: true,
                  fillColor: const Color(0xFFE5E7EB),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  hintText: 'Email',
                  filled: true,
                  fillColor: const Color(0xFFE5E7EB),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: senhaController,
                obscureText: true,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  hintText: 'Senha',
                  filled: true,
                  fillColor: const Color(0xFFE5E7EB),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
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
                      borderRadius: BorderRadius.circular(12),
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
                          'CRIAR CONTA',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
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
