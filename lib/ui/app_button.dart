import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_palette.dart';
import 'app_text_styles.dart';

/// Style variants available for [AppButton].
enum AppButtonVariant {
  primary,
  secondary,
  danger,
}

/// Reusable premium modern button.
/// Includes quick press scale animation (<120ms), subtle layered shadow,
/// double-tap prevention debounce, optional loading spinner, and haptic feedback.
class AppButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final Widget? icon;
  final bool isLoading;
  final bool enabled;
  final double? width;
  final double height;
  final List<Color>? customGradient;
  final Color? customGlow;
  final EdgeInsetsGeometry? padding;

  const AppButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.enabled = true,
    this.width,
    this.height = 52.0,
    this.customGradient,
    this.customGlow,
    this.padding,
  });

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _scaleAnimation;
  int _lastTapTime = 0;

  bool get _isClickable =>
      widget.enabled && !widget.isLoading && widget.onPressed != null;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
      reverseDuration: const Duration(milliseconds: 90),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails _) {
    if (_isClickable) {
      _animController.forward();
    }
  }

  void _handleTapUp(TapUpDetails _) {
    if (_isClickable) {
      _animController.reverse();
    }
  }

  void _handleTapCancel() {
    if (_isClickable) {
      _animController.reverse();
    }
  }

  void _handleTap() {
    if (!_isClickable) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    // Double-tap safe throttle (500 ms)
    if (now - _lastTapTime < 500) {
      return;
    }
    _lastTapTime = now;

    HapticFeedback.lightImpact();
    widget.onPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final isClickable = _isClickable;

    // Decoration based on variant and state
    final BoxDecoration decoration = _buildDecoration(isClickable);
    final TextStyle textStyle = _buildTextStyle(isClickable);

    Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.isLoading) ...[
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(width: 10),
        ] else if (widget.icon != null) ...[
          widget.icon!,
          const SizedBox(width: 8),
        ],
        Text(
          widget.text,
          style: textStyle,
          textAlign: TextAlign.center,
        ),
      ],
    );

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        );
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        onTap: _handleTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: widget.width,
          height: widget.height,
          padding: widget.padding ?? const EdgeInsets.symmetric(horizontal: 20),
          decoration: decoration,
          alignment: Alignment.center,
          child: content,
        ),
      ),
    );
  }

  BoxDecoration _buildDecoration(bool isClickable) {
    if (!isClickable) {
      return BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1.0,
        ),
      );
    }

    switch (widget.variant) {
      case AppButtonVariant.primary:
        final gradientColors = widget.customGradient ??
            const [
              Color(0xFF2563EB),
              Color(0xFF1D4ED8),
            ];
        final glow = widget.customGlow ?? const Color(0x4D2563EB);
        return BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradientColors,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.22),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: glow,
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        );

      case AppButtonVariant.secondary:
        return BoxDecoration(
          color: AppPalette.glassSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppPalette.glassBorder,
            width: 1.2,
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        );

      case AppButtonVariant.danger:
        final gradientColors = widget.customGradient ?? AppPalette.dangerGradient;
        final glow = widget.customGlow ?? AppPalette.dangerGlow;
        return BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradientColors,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.24),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: glow,
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        );
    }
  }

  TextStyle _buildTextStyle(bool isClickable) {
    if (!isClickable) {
      return AppTextStyles.button.copyWith(
        color: AppPalette.textMuted,
      );
    }
    switch (widget.variant) {
      case AppButtonVariant.primary:
      case AppButtonVariant.danger:
        return AppTextStyles.button.copyWith(
          color: AppPalette.textOnAccent,
        );
      case AppButtonVariant.secondary:
        return AppTextStyles.button.copyWith(
          color: AppPalette.textPrimary,
        );
    }
  }
}
