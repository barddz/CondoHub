import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_helpers.dart';
import '../../core/document_file_service.dart';
import '../../widgets/base_screen.dart';
import '../../widgets/info_card.dart';

class DocumentoDetalheScreen extends StatefulWidget {
  final String titulo;
  final String descricao;
  final String categoria;
  final String conteudo;
  final dynamic atualizadoEm;
  final String arquivoCaminho;
  final String arquivoNome;
  final dynamic arquivoTamanho;

  const DocumentoDetalheScreen({
    super.key,
    required this.titulo,
    required this.descricao,
    required this.categoria,
    required this.conteudo,
    required this.atualizadoEm,
    required this.arquivoCaminho,
    required this.arquivoNome,
    required this.arquivoTamanho,
  });

  @override
  State<DocumentoDetalheScreen> createState() => _DocumentoDetalheScreenState();
}

class _DocumentoDetalheScreenState extends State<DocumentoDetalheScreen> {
  bool abrindo = false;
  bool baixando = false;

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

  Future<void> _visualizarPdf() async {
    setState(() {
      abrindo = true;
    });

    try {
      await DocumentFileService.openPdf(widget.arquivoCaminho);
    } catch (_) {
      if (mounted) {
        showError(context, 'Não foi possível abrir o PDF.');
      }
    } finally {
      if (mounted) {
        setState(() {
          abrindo = false;
        });
      }
    }
  }

  Future<void> _baixarPdf() async {
    setState(() {
      baixando = true;
    });

    try {
      final salvou = await DocumentFileService.downloadPdf(
        path: widget.arquivoCaminho,
        fileName: widget.arquivoNome,
      );

      if (salvou && mounted) {
        showSuccess(context, 'PDF baixado com sucesso.');
      }
    } catch (_) {
      if (mounted) {
        showError(context, 'Não foi possível baixar o PDF.');
      }
    } finally {
      if (mounted) {
        setState(() {
          baixando = false;
        });
      }
    }
  }

  Widget _anexoPdf() {
    final nome = widget.arquivoNome.trim().isEmpty
        ? 'documento.pdf'
        : widget.arquivoNome.trim();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: defaultCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.picture_as_pdf_outlined,
                color: Color(0xFFB91C1C),
              ),
              SizedBox(width: 8),
              Text(
                'Arquivo PDF',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            nome,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            DocumentFileService.formatSize(widget.arquivoTamanho),
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ElevatedButton.icon(
                onPressed: abrindo || baixando ? null : _visualizarPdf,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                icon: abrindo
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Icon(Icons.visibility_outlined),
                label: const Text('Visualizar PDF'),
              ),
              OutlinedButton.icon(
                onPressed: abrindo || baixando ? null : _baixarPdf,
                icon: baixando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : const Icon(Icons.download_outlined),
                label: const Text('Baixar PDF'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final conteudo = widget.conteudo.trim();
    final temArquivo = widget.arquivoCaminho.trim().isNotEmpty;

    return BaseScreen(
      title: widget.titulo,
      subtitle: widget.categoria,
      children: [
        InfoCard(
          title: 'Descrição',
          description: widget.descricao,
          footer: 'Atualizado em ${_formatarData(widget.atualizadoEm)}',
          footerColor: AppColors.primary,
        ),
        if (temArquivo) _anexoPdf(),
        if (conteudo.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: defaultCardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Conteúdo do documento',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  conteudo,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        if (!temArquivo && conteudo.isEmpty)
          const InfoCard(
            title: 'Documento sem conteúdo',
            description: 'Nenhum texto ou PDF foi cadastrado.',
            footer: 'Entre em contato com a administração',
          ),
      ],
    );
  }
}
