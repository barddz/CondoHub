import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_colors.dart';
import '../../core/app_helpers.dart';
import '../../core/document_file_service.dart';
import '../../core/in_app_notifications_repository.dart';
import '../../widgets/base_screen.dart';
import '../../widgets/admin_form_section.dart';
import '../../widgets/info_card.dart';

class AdminDocumentosScreen extends StatefulWidget {
  const AdminDocumentosScreen({super.key});

  @override
  State<AdminDocumentosScreen> createState() => _AdminDocumentosScreenState();
}

class _AdminDocumentosScreenState extends State<AdminDocumentosScreen> {
  final tituloController = TextEditingController();
  final descricaoController = TextEditingController();
  final conteudoController = TextEditingController();

  String categoriaSelecionada = 'Regulamento';
  bool enviando = false;
  bool selecionandoArquivo = false;
  SelectedDocumentPdf? arquivoSelecionado;

  @override
  void dispose() {
    tituloController.dispose();
    descricaoController.dispose();
    conteudoController.dispose();
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

  Future<void> _selecionarPdf() async {
    setState(() {
      selecionandoArquivo = true;
    });

    try {
      final arquivo = await DocumentFileService.selectPdf();
      if (arquivo != null && mounted) {
        setState(() {
          arquivoSelecionado = arquivo;
        });
      }
    } on MissingPluginException {
      if (mounted) {
        showWarning(
          context,
          'Reinicie completamente o aplicativo para ativar o seletor de PDF.',
        );
      }
    } on DocumentFileException catch (error) {
      if (mounted) {
        showWarning(context, error.message);
      }
    } catch (_) {
      if (mounted) {
        showError(context, 'Não foi possível selecionar o PDF.');
      }
    } finally {
      if (mounted) {
        setState(() {
          selecionandoArquivo = false;
        });
      }
    }
  }

  Widget _pdfSelecionadoCard({
    required String nome,
    required dynamic tamanho,
    required String textoAcao,
    required VoidCallback? onPressed,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7F7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.picture_as_pdf_outlined,
            color: Color(0xFFB91C1C),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nome,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  DocumentFileService.formatSize(tamanho),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onPressed,
            child: Text(textoAcao),
          ),
        ],
      ),
    );
  }

  Future<void> _salvarDocumento() async {
    final titulo = tituloController.text.trim();
    final descricao = descricaoController.text.trim();
    final conteudo = conteudoController.text.trim();

    if (titulo.isEmpty || descricao.isEmpty) {
      showWarning(context, 'Preencha o título e a descrição.');
      return;
    }

    if (conteudo.isEmpty && arquivoSelecionado == null) {
      showWarning(context, 'Adicione um conteúdo em texto ou um arquivo PDF.');
      return;
    }

    setState(() {
      enviando = true;
    });

    final documentoRef =
        FirebaseFirestore.instance.collection('documentos').doc();
    UploadedDocumentPdf? arquivoEnviado;

    try {
      if (arquivoSelecionado != null) {
        arquivoEnviado = await DocumentFileService.uploadPdf(
          documentId: documentoRef.id,
          file: arquivoSelecionado!,
        );
      }

      await documentoRef.set({
        'titulo': titulo,
        'descricao': descricao,
        'categoria': categoriaSelecionada,
        'conteudo': conteudo,
        if (arquivoEnviado != null) ...arquivoEnviado.toFirestore(),
        'criadoEm': FieldValue.serverTimestamp(),
        'atualizadoEm': FieldValue.serverTimestamp(),
      });

      await InAppNotificationsRepository.notificarTodosMoradores(
        titulo: 'Novo documento disponível',
        mensagem: '$titulo foi publicado pela administração.',
        tipo: 'documento',
        referenciaId: documentoRef.id,
      );

      tituloController.clear();
      descricaoController.clear();
      conteudoController.clear();

      if (mounted) {
        setState(() {
          arquivoSelecionado = null;
        });
        showSuccess(context, 'Documento cadastrado com sucesso.');
      }
    } catch (_) {
      if (arquivoEnviado != null) {
        try {
          await DocumentFileService.deletePdf(arquivoEnviado.path);
        } catch (_) {
          // A tentativa de compensação não altera a mensagem da ação principal.
        }
      }

      if (mounted) {
        showError(context, 'Erro ao cadastrar documento.');
      }
    } finally {
      if (mounted) {
        setState(() {
          enviando = false;
        });
      }
    }
  }

  Future<void> _editarDocumento(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final dados = doc.data();

    final tituloEditController =
        TextEditingController(text: dados['titulo']?.toString() ?? '');
    final descricaoEditController =
        TextEditingController(text: dados['descricao']?.toString() ?? '');
    final conteudoEditController =
        TextEditingController(text: dados['conteudo']?.toString() ?? '');

    String categoriaEditada = dados['categoria']?.toString() ?? 'Regulamento';
    final arquivoAtualCaminho =
        dados['arquivoCaminho']?.toString().trim() ?? '';
    final arquivoAtualNome =
        dados['arquivoNome']?.toString().trim() ?? 'documento.pdf';
    final arquivoAtualTamanho = dados['arquivoTamanho'];
    SelectedDocumentPdf? novoArquivo;
    bool removerArquivoAtual = false;
    bool selecionando = false;
    bool salvando = false;

    try {
      await showDialog(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              return AlertDialog(
                title: const Text('Editar documento'),
                content: SizedBox(
                  width: 560,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: tituloEditController,
                          decoration: const InputDecoration(
                            labelText: 'Título',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: descricaoEditController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Descrição',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: [
                            'Regulamento',
                            'Convenção',
                            'Ata',
                            'Comunicado',
                            'Outro',
                          ].contains(categoriaEditada)
                              ? categoriaEditada
                              : 'Outro',
                          decoration: const InputDecoration(
                            labelText: 'Categoria',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'Regulamento',
                              child: Text('Regulamento'),
                            ),
                            DropdownMenuItem(
                              value: 'Convenção',
                              child: Text('Convenção'),
                            ),
                            DropdownMenuItem(
                              value: 'Ata',
                              child: Text('Ata'),
                            ),
                            DropdownMenuItem(
                              value: 'Comunicado',
                              child: Text('Comunicado'),
                            ),
                            DropdownMenuItem(
                              value: 'Outro',
                              child: Text('Outro'),
                            ),
                          ],
                          onChanged: (valor) {
                            if (valor == null) {
                              return;
                            }

                            setDialogState(() {
                              categoriaEditada = valor;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: conteudoEditController,
                          maxLines: 8,
                          decoration: const InputDecoration(
                            labelText: 'Conteúdo em texto (opcional)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (novoArquivo != null)
                          _pdfSelecionadoCard(
                            nome: novoArquivo!.name,
                            tamanho: novoArquivo!.size,
                            textoAcao: 'Remover',
                            onPressed: salvando
                                ? null
                                : () {
                                    setDialogState(() {
                                      novoArquivo = null;
                                    });
                                  },
                          )
                        else if (arquivoAtualCaminho.isNotEmpty &&
                            !removerArquivoAtual)
                          _pdfSelecionadoCard(
                            nome: arquivoAtualNome,
                            tamanho: arquivoAtualTamanho,
                            textoAcao: 'Remover',
                            onPressed: salvando
                                ? null
                                : () {
                                    setDialogState(() {
                                      removerArquivoAtual = true;
                                    });
                                  },
                          )
                        else
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border:
                                  Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Text(
                              removerArquivoAtual
                                  ? 'O PDF atual será removido ao salvar.'
                                  : 'Nenhum PDF anexado.',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: salvando || selecionando
                                ? null
                                : () async {
                                    setDialogState(() {
                                      selecionando = true;
                                    });

                                    try {
                                      final selecionado =
                                          await DocumentFileService.selectPdf();
                                      if (selecionado != null &&
                                          dialogContext.mounted) {
                                        setDialogState(() {
                                          novoArquivo = selecionado;
                                        });
                                      }
                                    } on MissingPluginException {
                                      if (mounted) {
                                        showWarning(
                                          context,
                                          'Reinicie completamente o aplicativo para ativar o seletor de PDF.',
                                        );
                                      }
                                    } on DocumentFileException catch (error) {
                                      if (mounted) {
                                        showWarning(context, error.message);
                                      }
                                    } catch (_) {
                                      if (mounted) {
                                        showError(
                                          context,
                                          'Não foi possível selecionar o PDF.',
                                        );
                                      }
                                    } finally {
                                      if (dialogContext.mounted) {
                                        setDialogState(() {
                                          selecionando = false;
                                        });
                                      }
                                    }
                                  },
                            icon: selecionando
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : const Icon(Icons.picture_as_pdf_outlined),
                            label: Text(
                              novoArquivo != null ||
                                      (arquivoAtualCaminho.isNotEmpty &&
                                          !removerArquivoAtual)
                                  ? 'Substituir PDF'
                                  : 'Selecionar PDF',
                            ),
                          ),
                        ),
                      ],
                    ),
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
                            final titulo = tituloEditController.text.trim();
                            final descricao =
                                descricaoEditController.text.trim();
                            final conteudo = conteudoEditController.text.trim();
                            final teraArquivo = novoArquivo != null ||
                                (arquivoAtualCaminho.isNotEmpty &&
                                    !removerArquivoAtual);

                            if (titulo.isEmpty || descricao.isEmpty) {
                              showWarning(
                                context,
                                'Preencha o título e a descrição.',
                              );
                              return;
                            }

                            if (conteudo.isEmpty && !teraArquivo) {
                              showWarning(
                                context,
                                'Adicione um conteúdo em texto ou um PDF.',
                              );
                              return;
                            }

                            setDialogState(() {
                              salvando = true;
                            });

                            UploadedDocumentPdf? arquivoEnviado;
                            bool atualizouDocumento = false;

                            try {
                              if (novoArquivo != null) {
                                arquivoEnviado =
                                    await DocumentFileService.uploadPdf(
                                  documentId: doc.id,
                                  file: novoArquivo!,
                                );
                              }

                              await doc.reference.update({
                                'titulo': titulo,
                                'descricao': descricao,
                                'categoria': categoriaEditada,
                                'conteudo': conteudo,
                                if (arquivoEnviado != null)
                                  ...arquivoEnviado.toFirestore(),
                                if (removerArquivoAtual &&
                                    arquivoEnviado == null) ...{
                                  'arquivoCaminho': FieldValue.delete(),
                                  'arquivoNome': FieldValue.delete(),
                                  'arquivoTamanho': FieldValue.delete(),
                                  'arquivoContentType': FieldValue.delete(),
                                },
                                'atualizadoEm': FieldValue.serverTimestamp(),
                              });
                              atualizouDocumento = true;

                              var arquivoAntigoRemovido = true;
                              if ((removerArquivoAtual ||
                                      arquivoEnviado != null) &&
                                  arquivoAtualCaminho.isNotEmpty) {
                                try {
                                  await DocumentFileService.deletePdf(
                                    arquivoAtualCaminho,
                                  );
                                } catch (_) {
                                  arquivoAntigoRemovido = false;
                                }
                              }

                              if (!mounted || !dialogContext.mounted) {
                                return;
                              }

                              Navigator.pop(dialogContext);
                              if (arquivoAntigoRemovido) {
                                showSuccess(context, 'Documento atualizado.');
                              } else {
                                showWarning(
                                  context,
                                  'Documento atualizado, mas o PDF antigo não pôde ser removido.',
                                );
                              }
                            } catch (_) {
                              if (!atualizouDocumento &&
                                  arquivoEnviado != null) {
                                try {
                                  await DocumentFileService.deletePdf(
                                    arquivoEnviado.path,
                                  );
                                } catch (_) {
                                  // Evita esconder o erro principal da edição.
                                }
                              }

                              if (mounted) {
                                showError(
                                  context,
                                  'Erro ao atualizar documento.',
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
      tituloEditController.dispose();
      descricaoEditController.dispose();
      conteudoEditController.dispose();
    }
  }

  Future<void> _excluirDocumento(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final arquivoCaminho =
        doc.data()['arquivoCaminho']?.toString().trim() ?? '';

    try {
      await doc.reference.delete();

      var arquivoRemovido = true;
      if (arquivoCaminho.isNotEmpty) {
        try {
          await DocumentFileService.deletePdf(arquivoCaminho);
        } catch (_) {
          arquivoRemovido = false;
        }
      }

      if (mounted) {
        if (arquivoRemovido) {
          showSuccess(context, 'Documento excluído.');
        } else {
          showWarning(
            context,
            'Documento excluído, mas o PDF não pôde ser removido.',
          );
        }
      }
    } catch (_) {
      if (mounted) {
        showError(context, 'Erro ao excluir documento.');
      }
    }
  }

  Future<void> _confirmarExclusao(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Excluir documento'),
          content: const Text('Tem certeza que deseja excluir este documento?'),
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
      await _excluirDocumento(doc);
    }
  }

  Widget _formularioDocumento({bool compacto = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: defaultCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!compacto) ...[
            const Text(
              'Novo documento',
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
            controller: descricaoController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Descrição',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: categoriaSelecionada,
            decoration: const InputDecoration(
              labelText: 'Categoria',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                value: 'Regulamento',
                child: Text('Regulamento'),
              ),
              DropdownMenuItem(
                value: 'Convenção',
                child: Text('Convenção'),
              ),
              DropdownMenuItem(
                value: 'Ata',
                child: Text('Ata'),
              ),
              DropdownMenuItem(
                value: 'Comunicado',
                child: Text('Comunicado'),
              ),
              DropdownMenuItem(
                value: 'Outro',
                child: Text('Outro'),
              ),
            ],
            onChanged: (valor) {
              if (valor == null) {
                return;
              }

              setState(() {
                categoriaSelecionada = valor;
              });
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: conteudoController,
            maxLines: 8,
            decoration: const InputDecoration(
              labelText: 'Conteúdo em texto (opcional)',
              hintText:
                  'Digite o texto do regulamento, ata, comunicado ou documento.',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          if (arquivoSelecionado != null) ...[
            _pdfSelecionadoCard(
              nome: arquivoSelecionado!.name,
              tamanho: arquivoSelecionado!.size,
              textoAcao: 'Remover',
              onPressed: enviando
                  ? null
                  : () {
                      setState(() {
                        arquivoSelecionado = null;
                      });
                    },
            ),
            const SizedBox(height: 10),
          ],
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed:
                  enviando || selecionandoArquivo ? null : _selecionarPdf,
              icon: selecionandoArquivo
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : const Icon(Icons.attach_file),
              label: Text(
                arquivoSelecionado == null
                    ? 'Anexar PDF'
                    : 'Substituir PDF selecionado',
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Arquivo opcional em formato PDF, com no máximo 10 MB.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: enviando ? null : _salvarDocumento,
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
                      'Cadastrar documento',
                      style: TextStyle(color: Colors.white),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _listaDocumentos() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('documentos').snapshots(),
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
            title: 'Erro ao carregar documentos',
            description: 'Não foi possível carregar os documentos cadastrados.',
            footer: 'Tente novamente mais tarde',
            footerColor: Color(0xFFDC2626),
          );
        }

        final List<QueryDocumentSnapshot<Map<String, dynamic>>> documentos = [
          ...(snapshot.data?.docs ?? [])
        ];

        documentos.sort((a, b) {
          final dataA = a.data()['atualizadoEm'];
          final dataB = b.data()['atualizadoEm'];

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
            title: 'Nenhum documento cadastrado',
            description:
                'Os documentos cadastrados pela administração aparecerão nesta lista.',
            footer: 'Aguardando novos documentos',
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Documentos cadastrados',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 12),
            ...documentos.map((doc) {
              final dados = doc.data();

              final titulo = dados['titulo']?.toString() ?? 'Documento';
              final descricao =
                  dados['descricao']?.toString() ?? 'Sem descrição';
              final categoria = dados['categoria']?.toString() ?? 'Documento';
              final atualizadoEm = dados['atualizadoEm'];
              final arquivoNome = dados['arquivoNome']?.toString().trim() ?? '';
              final arquivoTamanho = dados['arquivoTamanho'];

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
                        descricao,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '$categoria • Atualizado em ${_formatarData(atualizadoEm)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (arquivoNome.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(
                              Icons.picture_as_pdf_outlined,
                              size: 18,
                              color: Color(0xFFB91C1C),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '$arquivoNome • ${DocumentFileService.formatSize(arquivoTamanho)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _editarDocumento(doc),
                              icon: const Icon(Icons.edit_outlined),
                              label: const Text('Editar'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _confirmarExclusao(doc),
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Color(0xFFDC2626),
                              ),
                              label: const Text(
                                'Excluir',
                                style: TextStyle(
                                  color: Color(0xFFDC2626),
                                ),
                              ),
                            ),
                          ),
                        ],
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
      title: 'Documentos',
      subtitle: 'Cadastre normas e documentos do condomínio',
      children: [
        AdminFormSection(
          title: 'Cadastrar novo documento',
          subtitle: 'Adicione normas, atas ou comunicados',
          icon: Icons.note_add_outlined,
          child: _formularioDocumento(compacto: true),
        ),
        _listaDocumentos(),
      ],
    );
  }
}
