import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

/// [chipMode] = false (default): full-width card rows with check icon
/// [chipMode] = true: pill chips in a Wrap (for multi-select tag style)
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
          Text(
            question,
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.gray900,
              letterSpacing: -0.3,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              style: AppTypography.body.copyWith(color: AppColors.gray500),
            ),
          ],
          const SizedBox(height: 24),
          if (chipMode) _buildChips() else _buildCards(),
        ],
      ),
    );
  }

  // ── Pill chips (multi-select tags) ──────────────────────────────
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

  // ── Full-width cards with check icon ────────────────────────────
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

// ─── Pill chip ────────────────────────────────────────────────────

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
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: widget.isSelected ? AppColors.orange500 : AppColors.stone,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            widget.label,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color:
                  widget.isSelected ? Colors.white : AppColors.gray700,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Full-width card ─────────────────────────────────────────────

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
          duration: const Duration(milliseconds: 150),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: widget.isSelected ? AppColors.orange50 : Colors.white,
            border: Border.all(
              color: widget.isSelected
                  ? AppColors.orange500
                  : AppColors.gray200,
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.label,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: widget.isSelected
                        ? AppColors.orange500
                        : AppColors.gray800,
                  ),
                ),
              ),
              AnimatedOpacity(
                opacity: widget.isSelected ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 150),
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(
                    color: AppColors.orange500,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check,
                      color: Colors.white, size: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
