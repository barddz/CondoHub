import 'package:flutter/material.dart';

enum AppMessageType { success, error, info, warning }

BoxDecoration defaultCardDecoration() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    boxShadow: const [
      BoxShadow(
        color: Color(0x1A000000),
        blurRadius: 8,
        offset: Offset(0, 4),
      ),
    ],
  );
}

void showAppMessage(
  BuildContext context,
  String message, {
  AppMessageType type = AppMessageType.info,
}) {
  final (color, icon) = switch (type) {
    AppMessageType.success => (const Color(0xFF15803D), Icons.check_circle),
    AppMessageType.error => (const Color(0xFFB91C1C), Icons.error_outline),
    AppMessageType.warning => (const Color(0xFFB45309), Icons.warning_amber),
    AppMessageType.info => (const Color(0xFF1D4ED8), Icons.info_outline),
  };

  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: color,
      content: Row(
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    ),
  );
}

void showSuccess(BuildContext context, String message) {
  showAppMessage(context, message, type: AppMessageType.success);
}

void showError(BuildContext context, String message) {
  showAppMessage(context, message, type: AppMessageType.error);
}

void showInfo(BuildContext context, String message) {
  showAppMessage(context, message);
}

void showWarning(BuildContext context, String message) {
  showAppMessage(context, message, type: AppMessageType.warning);
}
