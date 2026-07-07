import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_gradients.dart';
import '../../../core/theme/app_typography.dart';

/// Quiz option picker — gradient chips or glass cards.
class QuizStep extends StatelessWidget {
  final String question;
  final String? subtitle;
  final List<String> options;
  final List<String> values;
  final List<String> selected;
  final bool multiSelect;
  final int? maxSelections;
  final ValueChanged<List<String>> onChanged;
  final bool chipMode;

  const QuizStep({
    required this.question,
    this.subtitle,
    required this.options,
    required this.values,
    required this.selected,
    required this.multiSelect,
    this.maxSelections,
    required this.onChanged,
    this.chipMode = false,
    super.key,
  });

  void _toggle(int i) {
    if (multiSelect) {
      final newList = List<String>.from(selected);
      if (newList.contains(values[i])) {
        newList.remove(values[i]);
      } else if (maxSelections == null || newList.length < maxSelections!) {
        newList.add(values[i]);
      }
      onChanged(newList);
    } else {
      onChanged([values[i]]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShaderMask(
            shaderCallback: (_) =>
                AppGradients.hero.createShader(const Rect.fromLTWH(0, 0, 280, 40)),
            child: Text(
              question,
              style: GoogleFonts.syne(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1.1,
              ),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(subtitle!, style: AppTypography.body),
          ],
          const SizedBox(height: 24),
          if (chipMode) _buildChips() else _buildCards(),
        ],
      ),
    );
  }

  Widget _buildChips() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: List.generate(options.length, (i) {
        final isSelected = selected.contains(values[i]);
        return _PressableChip(
          label: options[i],
          isSelected: isSelected,
          onTap: () => _toggle(i),
        );
      }),
    );
  }

  Widget _buildCards() {
    return Column(
      children: List.generate(options.length, (i) {
        final isSelected = selected.contains(values[i]);
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _PressableCard(
            label: options[i],
            isSelected: isSelected,
            onTap: () => _toggle(i),
          ),
        );
      }),
    );
  }
}

class _PressableChip extends StatefulWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _PressableChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_PressableChip> createState() => _PressableChipState();
}

class _PressableChipState extends State<_PressableChip> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            gradient: widget.isSelected ? AppGradients.cta : null,
            color: widget.isSelected
                ? null
                : (isDark ? AppColorsDark.card : AppColors.gray100),
            borderRadius: BorderRadius.circular(999),
            border: widget.isSelected
                ? null
                : Border.all(
                    color: isDark ? AppColorsDark.border : AppColors.border,
                  ),
            boxShadow: widget.isSelected
                ? [
                    BoxShadow(
                      color: AppColors.orange.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Text(
            widget.label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: widget.isSelected
                  ? Colors.white
                  : AppColors.textPrimary(context),
            ),
          ),
        ),
      ),
    );
  }
}

class _PressableCard extends StatefulWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _PressableCard({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_PressableCard> createState() => _PressableCardState();
}

class _PressableCardState extends State<_PressableCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          decoration: BoxDecoration(
            gradient: widget.isSelected ? AppGradients.heroSoft : null,
            color: widget.isSelected
                ? null
                : (isDark ? AppColorsDark.card : AppColors.card),
            border: Border.all(
              color: widget.isSelected
                  ? AppColors.orange
                  : (isDark ? AppColorsDark.border : AppColors.border),
              width: widget.isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: widget.isSelected
                ? [
                    BoxShadow(
                      color: AppColors.orange.withValues(alpha: 0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: widget.isSelected
                        ? AppColors.orange
                        : AppColors.textPrimary(context),
                  ),
                ),
              ),
              AnimatedOpacity(
                opacity: widget.isSelected ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 150),
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: const BoxDecoration(
                    gradient: AppGradients.cta,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_rounded,
                      color: Colors.white, size: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
