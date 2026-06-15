import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'core/app_colors.dart';
import 'firebase_options.dart';
import 'screens/auth/auth_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const CondoHubApp());
}

class CondoHubApp extends StatelessWidget {
  const CondoHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CondoHub',
      theme: ThemeData(
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
        ),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}
