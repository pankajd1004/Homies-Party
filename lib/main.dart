import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'logic/ludo_controller.dart';
import 'screens/home_screen.dart';
import 'screens/ludo_game_screen.dart';
import 'theme/ludo_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
