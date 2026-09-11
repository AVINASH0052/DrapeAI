import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';

const tryOnRefineSuggestions = [
  'Outdoor background',
  'Studio white',
  'Walking pose',
  'Closer crop',
  'Warmer light',
];

/// Bottom composer for post-result try-on refine (freeform + chips).
class TryOnRefineComposer extends StatelessWidget {
  const TryOnRefineComposer({
    super.key,
    required this.controller,
    required this.enabled,
    required this.onSubmit,
    this.hint = 'Change pose, background, lighting…',
    /// Studio / dark panels: white chip + field text.
    this.onDark = false,
  });

  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onSubmit;
  final String hint;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final fill = onDark ? const Color(0xFF2A221C) : AppColors.bg;
    final border = onDark ? const Color(0xFF4A3F36) : AppColors.gray200;
    final textColor = onDark ? Colors.white : AppColors.ink;
    final hintColor =
        onDark ? Colors.white.withValues(alpha: 0.55) : AppColors.ink3;
    final chipFill = onDark ? const Color(0xFF3A3028) : AppColors.ink;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              for (final chip in tryOnRefineSuggestions) ...[
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    label: Text(
                      chip,
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                    labelStyle: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                    onPressed: enabled
                        ? () {
                            controller.text = chip;
                            controller.selection = TextSelection.collapsed(
                              offset: controller.text.length,
                            );
                            onSubmit();
                          }
                        : null,
                    backgroundColor: chipFill,
                    disabledColor: chipFill.withValues(alpha: 0.5),
                    side: BorderSide(
                      color: onDark
                          ? border
                          : AppColors.ink.withValues(alpha: 0.2),
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ],
          ),
        ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: enabled,
                maxLength: 500,
                cursorColor: AppColors.orange,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) {
                  if (enabled) onSubmit();
                },
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  color: textColor,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: GoogleFonts.dmSans(
                    fontSize: 14,
                    color: hintColor,
                  ),
                  counterText: '',
                  filled: true,
                  fillColor: fill,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: border),
                  ),
                  disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        BorderSide(color: border.withValues(alpha: 0.5)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.orange),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: enabled ? onSubmit : null,
              style: IconButton.styleFrom(
                backgroundColor: AppColors.orange,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.gray300,
              ),
              icon: enabled
                  ? const Icon(Icons.send_rounded)
                  : const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
            ),
          ],
        ),
      ],
    );
  }
}
