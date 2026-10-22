import 'package:flutter/material.dart';
import '../battleship/battleship_mode_select_screen.dart';
import '../carrom/carrom_mode_select_screen.dart';
import '../pen_fight/pen_fight_mode_select_screen.dart';
import '../snl/snl_game_screen.dart';
import '../ui/app_card.dart';
import '../ui/app_palette.dart';
import '../ui/app_text_styles.dart';
import '../ui/app_transitions.dart';
import 'ludo_mode_select_screen.dart';

/// Redesigned Home Screen presenting all five classic tabletop board games:
/// Ludo, Snakes & Ladders, Carrom, Battleship, and Pen Fight.
/// Features premium gradients, responsive scaling, tactile press animations,
/// and smooth custom page transitions.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppPalette.backgroundGradient,
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxHeight < 680;
              final verticalSpacing = isCompact ? 10.0 : 14.0;
              final topSpacing = isCompact ? 12.0 : 20.0;

              return Column(
                children: [
                  SizedBox(height: topSpacing),
                  // App Header
                  const _HomeScreenHeader(),
                  SizedBox(height: verticalSpacing),

                  // Scrollable game card list
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          children: [
                            // 1. Ludo
                            _GameOptionCard(
                              key: const Key('home_ludo_card'),
                              emoji: '♟️',
                              title: 'Ludo',
                              badgeText: 'STRATEGY',
                              subtitle:
                                  '2–4 players · 4 tokens each\nRace all tokens home',
                              accentColor: AppPalette.ludo,
                              gradientColors: AppPalette.ludoGradient,
                              glowColor: AppPalette.ludoGlow,
                              onTap: () => Navigator.of(context).push(
                                appPageRoute(const LudoModeSelectScreen()),
                              ),
                            ),
                            SizedBox(height: verticalSpacing),

                            // 2. Snakes & Ladders
                            _GameOptionCard(
                              key: const Key('home_snl_card'),
                              emoji: '🐍',
                              title: 'Snakes & Ladders',
                              badgeText: 'CLASSIC',
                              subtitle:
                                  '2–4 players · 1 token each\nBe first to reach 100',
                              accentColor: AppPalette.snl,
                              gradientColors: AppPalette.snlGradient,
                              glowColor: AppPalette.snlGlow,
                              onTap: () => Navigator.of(context).push(
                                appPageRoute(const SnlGameScreen()),
                              ),
                            ),
                            SizedBox(height: verticalSpacing),

                            // 3. Carrom
                            _GameOptionCard(
                              key: const Key('home_carrom_card'),
                              emoji: '🎯',
                              title: 'Carrom',
                              badgeText: 'PHYSICS',
                              subtitle:
                                  '2 players · 9 coins each + Queen\nPocket & cover Queen to win',
                              accentColor: AppPalette.carrom,
                              gradientColors: AppPalette.carromGradient,
                              glowColor: AppPalette.carromGlow,
                              onTap: () => Navigator.of(context).push(
                                appPageRoute(const CarromModeSelectScreen()),
                              ),
                            ),
                            SizedBox(height: verticalSpacing),

                            // 4. Battleship
                            _GameOptionCard(
                              key: const Key('home_battleship_card'),
                              emoji: '🚢',
                              title: 'Battleship',
                              badgeText: 'RADAR DUEL',
                              subtitle:
                                  '2 players · 4 ships each\nLocate and sink enemy fleet',
                              accentColor: AppPalette.battleship,
                              gradientColors: AppPalette.battleshipGradient,
                              glowColor: AppPalette.battleshipGlow,
                              onTap: () => Navigator.of(context).push(
                                appPageRoute(
                                  const BattleshipModeSelectScreen(),
                                ),
                              ),
                            ),
                            SizedBox(height: verticalSpacing),

                            // 5. Pen Fight
                            _GameOptionCard(
                              key: const Key('home_pen_fight_card'),
                              emoji: '🖊️',
                              title: 'Pen Fight',
                              badgeText: 'TABLETOP',
                              subtitle:
                                  '2 players · Best of 3 rounds\nAim, flick & knock opponent off',
                              accentColor: const Color(0xFF8B5CF6),
                              gradientColors: const [
                                Color(0xFF581C87),
                                Color(0xFF7C3AED),
                              ],
                              glowColor: const Color(0x408B5CF6),
                              onTap: () => Navigator.of(context).push(
                                appPageRoute(
                                  const PenFightModeSelectScreen(),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Footer caption
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Classic 5-in-1 Board Games Suite',
                      style: AppTextStyles.caption.copyWith(
                        color: AppPalette.textMuted.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Polished header widget displaying collection badge and typography.
class _HomeScreenHeader extends StatelessWidget {
  const _HomeScreenHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          // Subtitle pill badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppPalette.glassSurface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppPalette.glassBorder,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppPalette.snlLight,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '5 GAMES IN 1 SUITE',
                  style: AppTextStyles.badge.copyWith(
                    color: AppPalette.textSecondary,
                    fontSize: 10,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Main App Title
          const Text(
            'Classic Board Games',
            style: AppTextStyles.title,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),

          // Subtitle
          Text(
            'Choose your tabletop challenge',
            style: AppTextStyles.subheading.copyWith(
              color: AppPalette.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

/// Individual stylized game card built with [AppCard].
class _GameOptionCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String badgeText;
  final String subtitle;
  final Color accentColor;
  final List<Color> gradientColors;
  final Color glowColor;
  final VoidCallback onTap;

  const _GameOptionCard({
    super.key,
    required this.emoji,
    required this.title,
    required this.badgeText,
    required this.subtitle,
    required this.accentColor,
    required this.gradientColors,
    required this.glowColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      gradientColors: gradientColors,
      glowColor: glowColor,
      padding: const EdgeInsets.all(18),
      borderRadius: 20,
      child: Row(
        children: [
          // Icon badge container
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.22),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Text(
                emoji,
                style: const TextStyle(fontSize: 28),
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Title & Description
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.heading.copyWith(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badgeText,
                        style: AppTextStyles.badge.copyWith(
                          fontSize: 9,
                          letterSpacing: 0.5,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: AppTextStyles.body.copyWith(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Forward chevron indicator in circular glass badge
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.14),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white,
              size: 13,
            ),
          ),
        ],
      ),
    );
  }
}
