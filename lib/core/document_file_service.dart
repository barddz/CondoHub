import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

const int maxDocumentPdfBytes = 10 * 1024 * 1024;

class DocumentFileException implements Exception {
  final String message;

  const DocumentFileException(this.message);

  @override
  String toString() => message;
}

class SelectedDocumentPdf {
  final String name;
  final Uint8List bytes;

  const SelectedDocumentPdf({
    required this.name,
    required this.bytes,
  });

  int get size => bytes.lengthInBytes;
}

class UploadedDocumentPdf {
  final String path;
  final String name;
  final int size;

  const UploadedDocumentPdf({
    required this.path,
    required this.name,
    required this.size,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'arquivoCaminho': path,
      'arquivoNome': name,
      'arquivoTamanho': size,
      'arquivoContentType': 'application/pdf',
    };
  }
}

class DocumentFileService {
  static Future<SelectedDocumentPdf?> selectPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      allowMultiple: false,
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      return null;
    }

    final file = result.files.single;
    final bytes = file.bytes;
    final name = file.name.trim().isEmpty ? 'documento.pdf' : file.name.trim();

    if (bytes == null) {
      throw const DocumentFileException(
        'Não foi possível ler o PDF selecionado. Reinicie o aplicativo e tente novamente.',
      );
    }

    if (!name.toLowerCase().endsWith('.pdf') || !_hasPdfSignature(bytes)) {
      throw const DocumentFileException(
        'Selecione um arquivo PDF válido.',
      );
    }

    if (bytes.isEmpty) {
      throw const DocumentFileException('O PDF selecionado está vazio.');
    }

    if (bytes.lengthInBytes > maxDocumentPdfBytes) {
      throw const DocumentFileException(
        'O PDF deve ter no máximo 10 MB.',
      );
    }

    return SelectedDocumentPdf(name: name, bytes: bytes);
  }

  static Future<UploadedDocumentPdf> uploadPdf({
    required String documentId,
    required SelectedDocumentPdf file,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path = 'documentos/$documentId/$timestamp.pdf';
    final reference = FirebaseStorage.instance.ref(path);

    await reference.putData(
      file.bytes,
      SettableMetadata(
        contentType: 'application/pdf',
        contentDisposition: 'inline; filename="${_safeFileName(file.name)}"',
        customMetadata: {'nomeOriginal': file.name},
      ),
    );

    return UploadedDocumentPdf(
      path: path,
      name: file.name,
      size: file.size,
    );
  }

  static Future<void> deletePdf(String? path) async {
    final normalizedPath = path?.trim() ?? '';
    if (normalizedPath.isEmpty) {
      return;
    }

    try {
      await FirebaseStorage.instance.ref(normalizedPath).delete();
    } on FirebaseException catch (error) {
      if (error.code != 'object-not-found') {
        rethrow;
      }
    }
  }

  static Future<void> openPdf(String path) async {
    final url = await FirebaseStorage.instance.ref(path).getDownloadURL();
    final opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );

    if (!opened) {
      throw const DocumentFileException(
        'Não foi possível abrir o visualizador de PDF.',
      );
    }
  }

  static Future<bool> downloadPdf({
    required String path,
    required String fileName,
  }) async {
    final bytes =
        await FirebaseStorage.instance.ref(path).getData(maxDocumentPdfBytes);

    if (bytes == null) {
      throw const DocumentFileException(
        'Não foi possível baixar o PDF.',
      );
    }

    final baseName = _baseFileName(fileName);
    final savedPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Salvar PDF',
      fileName: '$baseName.pdf',
      bytes: bytes,
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      lockParentWindow: true,
    );
    return kIsWeb || savedPath != null;
  }

  static String formatSize(dynamic rawSize) {
    final size = rawSize is num ? rawSize.toInt() : 0;
    if (size <= 0) {
      return 'Tamanho não informado';
    }

    if (size < 1024 * 1024) {
      return '${(size / 1024).toStringAsFixed(0)} KB';
    }

    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  static bool _hasPdfSignature(Uint8List bytes) {
    return bytes.length >= 5 &&
        bytes[0] == 0x25 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x44 &&
        bytes[3] == 0x46 &&
        bytes[4] == 0x2D;
  }

  static String _safeFileName(String name) {
    return name.replaceAll(RegExp(r'[^a-zA-Z0-9._ -]'), '_');
  }

  static String _baseFileName(String name) {
    final normalized = _safeFileName(name.trim());
    final withoutExtension = normalized.toLowerCase().endsWith('.pdf')
        ? normalized.substring(0, normalized.length - 4)
        : normalized;
    return withoutExtension.trim().isEmpty ? 'documento' : withoutExtension;
  }
}
