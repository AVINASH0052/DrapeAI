import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

class AppTypography {
  AppTypography._();

  static TextStyle get displaySerif => GoogleFonts.syne(
        fontSize: 36,
        fontWeight: FontWeight.w800,
        color: AppColors.ink,
        height: 1.0,
        letterSpacing: -1.2,
      );

  static TextStyle get headingSerif => GoogleFonts.syne(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
        height: 1.05,
        letterSpacing: -0.8,
      );

  static TextStyle get display => GoogleFonts.plusJakartaSans(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        color: AppColors.ink,
        letterSpacing: -0.8,
      );

  static TextStyle get heading => GoogleFonts.plusJakartaSans(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
        letterSpacing: -0.6,
        height: 1.1,
      );

  static TextStyle get title => GoogleFonts.plusJakartaSans(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
        letterSpacing: -0.3,
      );

  static TextStyle get body => GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.ink2,
        height: 1.5,
      );

  static TextStyle get label => GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.ink2,
      );

  static TextStyle get caption => GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppColors.ink3,
      );

  static TextStyle get chip => GoogleFonts.plusJakartaSans(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.ink2,
      );

  static TextStyle get mono => GoogleFonts.spaceMono(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: AppColors.ink3,
        letterSpacing: 0.4,
      );

  static TextStyle get button => GoogleFonts.plusJakartaSans(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.1,
      );

  static TextStyle heroGradient(BuildContext context) => GoogleFonts.syne(
        fontSize: 38,
        fontWeight: FontWeight.w800,
        height: 1.0,
        letterSpacing: -1.2,
        foreground: Paint()..shader = _heroShader(context),
      );

  static Shader _heroShader(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return LinearGradient(
      colors: isDark
          ? [const Color(0xFFFF7A33), const Color(0xFFFF4D8F), const Color(0xFFB07CFF)]
          : [const Color(0xFFFF5C00), const Color(0xFFFF006E), const Color(0xFF7B2FF7)],
    ).createShader(const Rect.fromLTWH(0, 0, 320, 70));
  }
}
