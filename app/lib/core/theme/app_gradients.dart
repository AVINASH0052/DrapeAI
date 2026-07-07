import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Brand gradients — saffron × magenta × teal fusion.
class AppGradients {
  AppGradients._();

  static const hero = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFFF5C00),
      Color(0xFFFF006E),
      Color(0xFF7B2FF7),
    ],
    stops: [0.0, 0.55, 1.0],
  );

  static const heroSoft = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFFFEDE3),
      Color(0xFFFFE8F2),
      Color(0xFFF0E8FF),
    ],
  );

  static const meshLight = LinearGradient(
    begin: Alignment(-1.2, -0.8),
    end: Alignment(1.2, 1.2),
    colors: [
      Color(0xFFFFF0E6),
      Color(0xFFFDF6EE),
      Color(0xFFFFE8F2),
      Color(0xFFE8FFF8),
    ],
    stops: [0.0, 0.35, 0.65, 1.0],
  );

  static const meshDark = LinearGradient(
    begin: Alignment(-1.0, -0.6),
    end: Alignment(1.0, 1.0),
    colors: [
      Color(0xFF1A0820),
      Color(0xFF0C0A14),
      Color(0xFF0A1420),
      Color(0xFF140A08),
    ],
    stops: [0.0, 0.4, 0.7, 1.0],
  );

  static const cta = LinearGradient(
    colors: [AppColors.orange, AppColors.pink],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const cardShine = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0x20FFFFFF),
      Color(0x00FFFFFF),
    ],
  );

  static const ethnic = LinearGradient(
    colors: [AppColors.gold, AppColors.orange, AppColors.pink],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient mesh(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? meshDark : meshLight;

  static Shader textHero(BuildContext context) =>
      hero.createShader(const Rect.fromLTWH(0, 0, 300, 60));
}
