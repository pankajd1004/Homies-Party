import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'logic/ludo_controller.dart';
import 'network/auth_service.dart';
import 'screens/home_screen.dart';
import 'screens/ludo_game_screen.dart';
import 'theme/ludo_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
  } catch (e) {
    AuthService().setInitError(e.toString());
  }

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const ClassicBoardGamesApp());
}

/// Root widget for the app — shows the home screen by default.
/// [ClassicLudoApp] is kept as a named export so existing Ludo widget tests
/// continue to work without any modification.
class ClassicBoardGamesApp extends StatelessWidget {
  const ClassicBoardGamesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Classic Board Games',
      debugShowCheckedModeBanner: false,
      theme: LudoTheme.darkTheme,
      home: const HomeScreen(),
    );
  }
}

/// Kept for backward-compatibility with existing Ludo widget tests.
/// Do NOT modify this class.
class ClassicLudoApp extends StatelessWidget {
  final LudoController? controller;

  const ClassicLudoApp({super.key, this.controller});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Classic Ludo',
      debugShowCheckedModeBanner: false,
      theme: LudoTheme.darkTheme,
      home: LudoGameScreen(controller: controller),
    );
  }
}
