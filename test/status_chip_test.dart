import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/widgets/status_chip.dart';

void main() {
  testWidgets('exibe o status informado com semântica', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StatusChip(status: 'Aprovada'),
        ),
      ),
    );

    expect(find.text('Aprovada'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
  });
}
