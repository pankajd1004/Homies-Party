import 'package:flutter/material.dart';

/// Centralized design palette for the Classic Board Games suite.
/// Provides cohesive gradients, game-specific accents, semantic colors,
/// and surface/glass tokens.
class AppPalette {
  AppPalette._();

  // --- Background & Canvas ---
  static const Color backgroundTop = Color(0xFF0F172A);
  static const Color backgroundBottom = Color(0xFF070B18);
  static const Color backgroundElevated = Color(0xFF131D33);

  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [backgroundTop, backgroundBottom],
  );

  // --- Glass & Surfaces ---
  static const Color glassSurface = Color(0x1AFFFFFF);
  static const Color glassSurfaceHover = Color(0x28FFFFFF);
  static const Color glassBorder = Color(0x2EFFFFFF);
  static const Color glassBorderLight = Color(0x40FFFFFF);
  static const Color cardSurface = Color(0x14FFFFFF);

  // --- 4 Game Accent Colors ---
  // Ludo — Electric Royal Blue
  static const Color ludo = Color(0xFF3B82F6);
  static const Color ludoDark = Color(0xFF1D4ED8);
  static const Color ludoLight = Color(0xFF60A5FA);
  static const Color ludoGlow = Color(0x403B82F6);
  static const List<Color> ludoGradient = [
    Color(0xFF1E3A8A),
    Color(0xFF2563EB),
  ];

  // Snakes & Ladders — Emerald Jade
  static const Color snl = Color(0xFF10B981);
  static const Color snlDark = Color(0xFF047857);
  static const Color snlLight = Color(0xFF34D399);
  static const Color snlGlow = Color(0x4010B981);
  static const List<Color> snlGradient = [
    Color(0xFF064E3B),
    Color(0xFF059669),
  ];

  // Carrom — Warm Amber & Rich Mahogany
  static const Color carrom = Color(0xFFF59E0B);
  static const Color carromDark = Color(0xFFB45309);
  static const Color carromLight = Color(0xFFFBBF24);
  static const Color carromGlow = Color(0x40F59E0B);
  static const List<Color> carromGradient = [
    Color(0xFF78350F),
    Color(0xFFD97706),
  ];

  // Battleship — Naval Cyan & Radar Blue
  static const Color battleship = Color(0xFF06B6D4);
  static const Color battleshipDark = Color(0xFF0284C7);
  static const Color battleshipLight = Color(0xFF38BDF8);
  static const Color battleshipGlow = Color(0x4006B6D4);
  static const List<Color> battleshipGradient = [
    Color(0xFF0C4A6E),
    Color(0xFF0284C7),
  ];

  // --- Semantic Feedback ---
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);
  static const Color dangerDark = Color(0xFFB91C1C);
  static const Color dangerGlow = Color(0x40EF4444);
  static const List<Color> dangerGradient = [
    Color(0xFFB91C1C),
    Color(0xFFEF4444),
  ];

  // --- Text Colors ---
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);
  static const Color textOnAccent = Color(0xFFFFFFFF);
}
