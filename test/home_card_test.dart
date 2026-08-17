import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/widgets/home_card.dart';

void main() {
  testWidgets('exibe subtítulo e responde ao toque', (tester) async {
    var tocado = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 240,
            height: 200,
            child: HomeCard(
              icon: Icons.calendar_month,
              title: 'Reservas',
              subtitle: '3 reservas ativas',
              onTap: () => tocado = true,
            ),
          ),
        ),
      ),
    );

    expect(find.text('3 reservas ativas'), findsOneWidget);

    await tester.tap(find.text('Reservas'));
    expect(tocado, isTrue);
  });
}
