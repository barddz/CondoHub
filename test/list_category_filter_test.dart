import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/widgets/list_category_filter.dart';

void main() {
  testWidgets('filtro permite selecionar uma categoria', (tester) async {
    String? selecionado;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListCategoryFilter(
            selectedValue: 'Todos',
            options: const ['Todos', 'Em análise', 'Aprovada', 'Recusada'],
            onChanged: (value) {
              selecionado = value;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Todos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aprovada').last);
    await tester.pumpAndSettle();

    expect(selecionado, 'Aprovada');
  });
}
