import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/main.dart';

void main() {
  testWidgets('Tela de login aparece corretamente',
      (WidgetTester tester) async {
    await tester.pumpWidget(const CondoHubApp());

    expect(find.text('CondoHub'), findsOneWidget);
    expect(find.text('ENTRAR'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
  });
}
