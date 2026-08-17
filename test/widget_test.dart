import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/screens/auth/login_screen.dart';
import 'package:flutter_application_1/screens/documentos/documento_detalhe_screen.dart';

void main() {
  testWidgets('Tela de login aparece corretamente',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LoginScreen(),
      ),
    );

    expect(find.text('CondoHub'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
    expect(find.text('Esqueci minha senha'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
  });

  testWidgets('Documento com PDF exibe ações de visualizar e baixar',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: DocumentoDetalheScreen(
          titulo: 'Convenção do condomínio',
          descricao: 'Documento oficial',
          categoria: 'Convenção',
          conteudo: '',
          atualizadoEm: null,
          arquivoCaminho: 'documentos/abc/documento.pdf',
          arquivoNome: 'convencao.pdf',
          arquivoTamanho: 1024,
        ),
      ),
    );

    expect(find.text('Arquivo PDF'), findsOneWidget);
    expect(find.text('convencao.pdf'), findsOneWidget);
    expect(find.text('Visualizar PDF'), findsOneWidget);
    expect(find.text('Baixar PDF'), findsOneWidget);
    expect(find.text('Documento sem conteúdo'), findsNothing);
  });

  testWidgets('Documento textual continua funcionando sem anexo',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: DocumentoDetalheScreen(
          titulo: 'Regulamento',
          descricao: 'Regras gerais',
          categoria: 'Regulamento',
          conteudo: 'Conteúdo mantido para documentos antigos.',
          atualizadoEm: null,
          arquivoCaminho: '',
          arquivoNome: '',
          arquivoTamanho: null,
        ),
      ),
    );

    expect(find.text('Conteúdo do documento'), findsOneWidget);
    expect(
      find.text('Conteúdo mantido para documentos antigos.'),
      findsOneWidget,
    );
    expect(find.text('Arquivo PDF'), findsNothing);
  });
}
