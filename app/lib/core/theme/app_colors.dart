import 'package:flutter/material.dart';

/// Sugatai — "Midnight Masala" palette.
/// Saffron heat × neon Gen Z × global streetwear. Works in Mumbai and Manhattan.
class AppColors {
  AppColors._();

  // Surfaces — warm cream light, deep cosmic dark
  static const bg = Color(0xFFFDF6EE);
  static const bgWarm = Color(0xFFF5EBE0);
  static const card = Color(0xFFFFFFFF);
  static const border = Color(0xFFE8DDD0);
  static const borderStrong = Color(0xFFD4C4B4);

  static const stone = Color(0xFFEDE4D8);
  static const stoneMid = Color(0xFFD9CFC2);

  // Ink
  static const ink = Color(0xFF0C0A14);
  static const ink2 = Color(0xFF4A4458);
  static const ink3 = Color(0xFF8A8299);
  static const ink4 = Color(0xFFC4BCC8);

  static const gray900 = ink;
  static const gray800 = Color(0xFF1E1A28);
  static const gray700 = Color(0xFF2E2838);
  static const gray500 = ink2;
  static const gray400 = ink3;
  static const gray300 = Color(0xFFD4C4B4);
  static const gray200 = border;
  static const gray100 = Color(0xFFF0E8DE);
  static const gray50 = Color(0xFFFAF4EC);

  // Primary accent — saffron blaze (India energy)
  static const orange = Color(0xFFFF5C00);
  static const orangeSoft = Color(0xFFFFEDE3);
  static const orange500 = orange;
  static const orange400 = Color(0xFFFF7A33);
  static const orange600 = Color(0xFFE04E00);
  static const orange50 = orangeSoft;

  // Gen Z pops
  static const pink = Color(0xFFFF006E);
  static const pinkSoft = Color(0xFFFFE8F2);
  static const lime = Color(0xFF00E5A0);
  static const limeSoft = Color(0xFFE0FFF5);
  static const lavender = Color(0xFF7B2FF7);
  static const lavenderSoft = Color(0xFFF0E8FF);
  static const gold = Color(0xFFFFC947);
  static const goldSoft = Color(0xFFFFF5D6);
  static const teal = Color(0xFF00C9B7);
  static const tealSoft = Color(0xFFE0FAF7);

  // Semantic
  static const red = Color(0xFFFF2D55);
  static const red500 = red;
  static const red50 = Color(0xFFFFE8EC);
  static const green500 = Color(0xFF00E5A0);
  static const green50 = Color(0xFFE0FFF5);
  static const amber500 = Color(0xFFFFC947);
  static const amber50 = Color(0xFFFFF5D6);

  static const indigo500 = lavender;
  static const indigo50 = lavenderSoft;

  /// Theme-aware surface helpers
  static Color surface(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? AppColorsDark.card
          : card;

  static Color textPrimary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? AppColorsDark.ink
          : ink;

  static Color textMuted(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? AppColorsDark.ink3
          : ink3;
}

class AppColorsDark {
  AppColorsDark._();

  static const bg = Color(0xFF0C0A14);
  static const bgWarm = Color(0xFF12101C);
  static const card = Color(0xFF16131F);
  static const border = Color(0xFF2A2535);
  static const borderStrong = Color(0xFF3D3648);

  static const ink = Color(0xFFF8F4FF);
  static const ink2 = Color(0xFFB8B0C8);
  static const ink3 = Color(0xFF6E6680);
  static const ink4 = Color(0xFF3D3848);

  static const orange = Color(0xFFFF6B2C);
  static const orangeSoft = Color(0xFF2A1408);

  static const pinkSoft = Color(0xFF2A0818);
  static const limeSoft = Color(0xFF082A1E);
  static const lavenderSoft = Color(0xFF1A0E30);
  static const goldSoft = Color(0xFF2A2008);
  static const tealSoft = Color(0xFF082A26);

  static const red = Color(0xFFFF4D6D);
  static const red50 = Color(0xFF2A0A12);
  static const green500 = Color(0xFF00E5A0);
  static const green50 = Color(0xFF082A1E);
  static const amber500 = Color(0xFFFFD060);
  static const amber50 = Color(0xFF2A2008);

  static const gray900 = ink;
  static const gray100 = Color(0xFF1E1A28);
  static const gray50 = Color(0xFF12101C);
}
