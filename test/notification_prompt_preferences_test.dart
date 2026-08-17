import 'package:flutter_application_1/core/notification_prompt_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('o convite ainda nao foi respondido em um dispositivo novo', () async {
    expect(
      await NotificationPromptPreferences.wasAnswered('morador-1'),
      isFalse,
    );
  });

  test('a resposta fica salva somente para o usuario correspondente', () async {
    await NotificationPromptPreferences.markAnswered('morador-1');

    expect(
      await NotificationPromptPreferences.wasAnswered('morador-1'),
      isTrue,
    );
    expect(
      await NotificationPromptPreferences.wasAnswered('morador-2'),
      isFalse,
    );
  });
}
