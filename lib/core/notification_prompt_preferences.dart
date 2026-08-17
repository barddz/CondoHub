import 'package:shared_preferences/shared_preferences.dart';

class NotificationPromptPreferences {
  static const String _keyPrefix = 'condohub_push_prompt_answered_v1_';

  static String _key(String userId) => '$_keyPrefix$userId';

  static Future<bool> wasAnswered(String userId) async {
    if (userId.trim().isEmpty) {
      return false;
    }

    try {
      final preferences = await SharedPreferences.getInstance();
      return preferences.getBool(_key(userId)) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> markAnswered(String userId) async {
    if (userId.trim().isEmpty) {
      return;
    }

    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(_key(userId), true);
    } catch (_) {
      // O convite continua protegido pela sessão se o armazenamento local falhar.
    }
  }
}
