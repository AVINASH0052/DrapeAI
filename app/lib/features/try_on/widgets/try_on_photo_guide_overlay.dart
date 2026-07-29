import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/drape_ui.dart';

/// Full-body photo tips before saving the try-on reference photo.
class TryOnPhotoGuideOverlay extends StatefulWidget {
  final VoidCallback onContinue;
  final VoidCallback? onCancel;

  const TryOnPhotoGuideOverlay({
    super.key,
    required this.onContinue,
    this.onCancel,
  });

  static const prefsKey = 'try_on_photo_guide_seen_v1';

  static Future<bool> shouldShow() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(prefsKey) ?? false);
  }

  static Future<void> markSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefsKey, true);
  }

  @override
  State<TryOnPhotoGuideOverlay> createState() => _TryOnPhotoGuideOverlayState();
}

class _TryOnPhotoGuideOverlayState extends State<TryOnPhotoGuideOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    )..forward();
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    await TryOnPhotoGuideOverlay.markSeen();
    await _anim.reverse();
    widget.onContinue();
  }

  Future<void> _cancel() async {
    await _anim.reverse();
    widget.onCancel?.call();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: Material(
        color: Colors.black.withValues(alpha: 0.65),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFF1A1525).withValues(alpha: 0.95),
                        const Color(0xFF0C0A14).withValues(alpha: 0.98),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: AppColors.orange.withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Full-body photo tips',
                        style: GoogleFonts.syne(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'One good photo lets you try every outfit on yourself.',
                        style: AppTypography.caption
                            .copyWith(color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      const _TipRow(
                        icon: Icons.accessibility_new_rounded,
                        text: 'Stand full length — head to toe in frame',
                      ),
                      const SizedBox(height: 10),
                      const _TipRow(
                        icon: Icons.wb_sunny_outlined,
                        text: 'Face the camera, even lighting, plain wall',
                      ),
                      const SizedBox(height: 10),
                      const _TipRow(
                        icon: Icons.checkroom_outlined,
                        text: 'Fitted clothes help the AI place garments',
                      ),
                      const SizedBox(height: 24),
                      DrapeGradientButton(
                        label: 'Pick photo',
                        onPressed: _continue,
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: _cancel,
                        child: Text(
                          'Cancel',
                          style: AppTypography.label
                              .copyWith(color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TipRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _TipRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.orange, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: AppTypography.label.copyWith(
                color: Colors.white,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
