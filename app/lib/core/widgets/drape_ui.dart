import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';
import '../theme/app_gradients.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';

/// Animated mesh gradient backdrop for hero screens.
class DrapeMeshBackground extends StatelessWidget {
  final Widget child;
  final bool showOrbs;

  const DrapeMeshBackground({
    required this.child,
    this.showOrbs = true,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(gradient: AppGradients.mesh(context)),
        ),
        if (showOrbs) ...[
          Positioned(
            top: -80,
            right: -40,
            child: _GlowOrb(
              size: 220,
              color: AppColors.orange.withValues(alpha: isDark ? 0.25 : 0.18),
            ),
          ),
          Positioned(
            top: 120,
            left: -60,
            child: _GlowOrb(
              size: 180,
              color: AppColors.pink.withValues(alpha: isDark ? 0.2 : 0.12),
            ),
          ),
          Positioned(
            bottom: 80,
            right: -20,
            child: _GlowOrb(
              size: 160,
              color: AppColors.lime.withValues(alpha: isDark ? 0.15 : 0.1),
            ),
          ),
        ],
        child,
      ],
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowOrb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(color: color, blurRadius: 80, spreadRadius: 20),
        ],
      ),
    );
  }
}

/// Drape wordmark with gradient dot.
class DrapeWordmark extends StatelessWidget {
  final double size;

  const DrapeWordmark({this.size = 36, super.key});

  @override
  Widget build(BuildContext context) {
    final ink = AppColors.textPrimary(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        ShaderMask(
          shaderCallback: (_) => AppGradients.hero.createShader(
            Rect.fromLTWH(0, 0, size * 2.5, size),
          ),
          child: Text(
            'drape',
            style: GoogleFonts.syne(
              fontSize: size,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -1,
            ),
          ),
        ),
        Text(
          '.',
          style: GoogleFonts.syne(
            fontSize: size,
            fontWeight: FontWeight.w800,
            foreground: Paint()
              ..shader = AppGradients.cta.createShader(
                Rect.fromLTWH(0, 0, size, size),
              ),
          ),
        ),
        Text(
          'ai',
          style: GoogleFonts.spaceMono(
            fontSize: size * 0.55,
            fontWeight: FontWeight.w700,
            color: ink,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }
}

/// Screen title with optional subtitle and trailing actions.
class DrapeScreenHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final bool gradientTitle;

  const DrapeScreenHeader({
    required this.title,
    this.subtitle,
    this.actions,
    this.gradientTitle = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final ink = AppColors.textPrimary(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                gradientTitle
                    ? ShaderMask(
                        shaderCallback: (_) =>
                            AppGradients.hero.createShader(
                          const Rect.fromLTWH(0, 0, 240, 40),
                        ),
                        child: Text(
                          title,
                          style: GoogleFonts.syne(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 1.0,
                            letterSpacing: -0.8,
                          ),
                        ),
                      )
                    : Text(
                        title,
                        style: GoogleFonts.syne(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: ink,
                          height: 1.0,
                          letterSpacing: -0.8,
                        ),
                      ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(subtitle!, style: AppTypography.caption),
                ],
              ],
            ),
          ),
          if (actions != null) ...actions!,
        ],
      ),
    );
  }
}

/// Horizontal filter chip with gradient active state.
class DrapeChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  final IconData? icon;

  const DrapeChip({
    required this.label,
    required this.active,
    required this.onTap,
    this.icon,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          gradient: active ? AppGradients.cta : null,
          color: active
              ? null
              : (isDark ? AppColorsDark.card : AppColors.gray100),
          borderRadius: BorderRadius.circular(999),
          border: active
              ? null
              : Border.all(
                  color: isDark ? AppColorsDark.border : AppColors.border,
                ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: AppColors.orange.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: active ? Colors.white : AppColors.ink3),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: AppTypography.chip.copyWith(
                color: active
                    ? Colors.white
                    : AppColors.textMuted(context),
                fontWeight: active ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Glassmorphism card with optional gradient border.
class DrapeGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool gradientBorder;
  final VoidCallback? onTap;

  const DrapeGlassCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.gradientBorder = false,
    this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inner = ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: (isDark ? AppColorsDark.card : AppColors.card)
                .withValues(alpha: isDark ? 0.85 : 0.92),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? AppColorsDark.border : AppColors.border,
            ),
          ),
          child: child,
        ),
      ),
    );

    if (!gradientBorder) {
      return onTap != null
          ? GestureDetector(onTap: onTap, child: inner)
          : inner;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(21),
          gradient: AppGradients.hero,
        ),
        padding: const EdgeInsets.all(1.5),
        child: inner,
      ),
    );
  }
}

/// Circular icon button with glass style.
class DrapeIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final int? badge;

  const DrapeIconButton({
    required this.icon,
    required this.onTap,
    this.badge,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: (isDark ? AppColorsDark.card : AppColors.card)
              .withValues(alpha: 0.9),
          shape: BoxShape.circle,
          border: Border.all(
            color: isDark ? AppColorsDark.border : AppColors.border,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(icon, size: 20, color: AppColors.textPrimary(context)),
            if (badge != null && badge! > 0)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: const BoxDecoration(
                    gradient: AppGradients.cta,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    badge! > 9 ? '9+' : '$badge',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Gradient CTA button.
class DrapeGradientButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;

  const DrapeGradientButton({
    required this.label,
    this.onPressed,
    this.loading = false,
    this.icon,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onPressed,
      child: AnimatedOpacity(
        opacity: onPressed == null && !loading ? 0.5 : 1,
        duration: const Duration(milliseconds: 150),
        child: Container(
          height: 54,
          width: double.infinity,
          decoration: AppTheme.gradientButton,
          child: Center(
            child: loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, size: 18, color: Colors.white),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        label,
                        style: AppTypography.button.copyWith(color: Colors.white),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// Section label in mono uppercase.
class DrapeSectionLabel extends StatelessWidget {
  final String text;

  const DrapeSectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Text(
        text.toUpperCase(),
        style: AppTypography.mono.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.orange,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

/// Offline connectivity banner.
class DrapeOfflineBanner extends StatelessWidget {
  final bool isOffline;

  const DrapeOfflineBanner({required this.isOffline, super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      offset: isOffline ? Offset.zero : const Offset(0, -1),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 250),
        opacity: isOffline ? 1 : 0,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2A2535), Color(0xFF1A1525)],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.wifi_off_rounded,
                    size: 16, color: AppColors.gold),
                const SizedBox(width: 8),
                Text(
                  'You\'re offline — browsing cached wardrobe',
                  style: AppTypography.caption.copyWith(color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
