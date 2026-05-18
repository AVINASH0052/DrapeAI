import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Surfaces
  static const bg = Color(0xFFFAFAF9);
  static const bgWarm = Color(0xFFF5F4F0);
  static const card = Color(0xFFFFFFFF);
  static const border = Color(0xFFE7E5E0);
  static const borderStrong = Color(0xFFD6D3CC);

  // Legacy surface aliases
  static const stone = Color(0xFFE8E4DF);
  static const stoneMid = Color(0xFFD5CFC8);

  // Ink (text)
  static const ink = Color(0xFF181715);
  static const ink2 = Color(0xFF5F5C57);
  static const ink3 = Color(0xFF9A958C);
  static const ink4 = Color(0xFFC9C5BD);

  // Legacy gray aliases
  static const gray900 = ink;
  static const gray800 = Color(0xFF2D2D2D);
  static const gray700 = Color(0xFF3D3D3D);
  static const gray500 = ink2;
  static const gray400 = ink3;
  static const gray300 = Color(0xFFD1D5DB);
  static const gray200 = border;
  static const gray100 = Color(0xFFF3F4F6);
  static const gray50 = Color(0xFFF9FAFB);

  // Orange accent
  static const orange = Color(0xFFF97316);
  static const orangeSoft = Color(0xFFFFF1E6);
  static const orange500 = orange;
  static const orange400 = Color(0xFFFB923C);
  static const orange600 = Color(0xFFEA580C);
  static const orange50 = orangeSoft;

  // Additional accents
  static const pink = Color(0xFFEC4899);
  static const pinkSoft = Color(0xFFFCE7F3);
  static const lime = Color(0xFF84CC16);
  static const limeSoft = Color(0xFFECFCCB);
  static const lavender = Color(0xFFA78BFA);
  static const lavenderSoft = Color(0xFFEDE9FE);

  // Semantic
  static const red = Color(0xFFE11D48);
  static const red500 = red;
  static const red50 = Color(0xFFFEF2F2);
  static const green500 = Color(0xFF22C55E);
  static const green50 = Color(0xFFF0FDF4);
  static const amber500 = Color(0xFFF59E0B);
  static const amber50 = Color(0xFFFFFBEB);

  // Backward-compatible aliases
  static const indigo500 = orange;
  static const indigo50 = orangeSoft;
}
