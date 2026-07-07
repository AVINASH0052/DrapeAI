import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/environment.dart';
import '../../../core/widgets/drape_ui.dart';
import '../providers/calendar_provider.dart';
import '../widgets/calendar_assign_sheet.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  int? _selectedDay;

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  void _changeMonth(int delta) {
    final current = ref.read(calendarMonthProvider);
    final parts = current.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final newDate = DateTime(year, month + delta, 1);
    ref.read(calendarMonthProvider.notifier).state =
        '${newDate.year}-${newDate.month.toString().padLeft(2, '0')}';
    setState(() => _selectedDay = null);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final monthStr = ref.watch(calendarMonthProvider);
    final entriesAsync = ref.watch(calendarEntriesProvider(monthStr));

    final parts = monthStr.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final monthName = _monthName(month);

    return Scaffold(
      extendBody: true,
      body: DrapeMeshBackground(
        showOrbs: false,
        child: SafeArea(
          child: Column(
            children: [
              DrapeScreenHeader(
                title: 'Calendar',
                subtitle: 'plan your fits',
                gradientTitle: true,
                actions: [
                  DrapeIconButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: () => context.pop(),
                  ),
                ],
              ),
            const SizedBox(height: 8),

            // Month navigation
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _NavArrow(
                    icon: Icons.chevron_left,
                    onTap: () => _changeMonth(-1),
                    isDark: isDark,
                  ),
                  Column(
                    children: [
                      Text(monthName,
                          style: GoogleFonts.instrumentSerif(
                            fontSize: 22,
                            color: isDark ? AppColorsDark.ink : AppColors.ink,
                          )),
                      Text('$year',
                          style: AppTypography.caption.copyWith(
                              color: isDark
                                  ? AppColorsDark.ink3
                                  : AppColors.ink3)),
                    ],
                  ),
                  _NavArrow(
                    icon: Icons.chevron_right,
                    onTap: () => _changeMonth(1),
                    isDark: isDark,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Weekday headers
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: _weekdays
                    .map((d) => Expanded(
                          child: Center(
                            child: Text(d,
                                style: AppTypography.mono.copyWith(
                                    fontSize: 10,
                                    letterSpacing: 0.4,
                                    color: isDark
                                        ? AppColorsDark.ink3
                                        : AppColors.ink3)),
                          ),
                        ))
                    .toList(),
              ),
            ),
            const SizedBox(height: 8),

            // Calendar grid
            Expanded(
              child: entriesAsync.when(
                loading: () => _buildShimmerGrid(isDark),
                error: (e, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Could not load calendar',
                          style: AppTypography.body),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () => ref.invalidate(
                            calendarEntriesProvider(monthStr)),
                        child: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
                data: (data) {
                  final entries = List<Map<String, dynamic>>.from(
                      data['entries'] ?? const []);
                  final totalStyled = data['total_days_styled'] ?? 0;

                  // Build lookup: day → entry
                  final dayMap = <int, Map<String, dynamic>>{};
                  for (final e in entries) {
                    final dateStr = e['date']?.toString() ?? '';
                    if (dateStr.length >= 10) {
                      final day = int.tryParse(dateStr.substring(8, 10));
                      if (day != null) dayMap[day] = e;
                    }
                  }

                  return _buildCalendarContent(
                    year: year,
                    month: month,
                    dayMap: dayMap,
                    totalStyled: totalStyled as int,
                    isDark: isDark,
                  );
                },
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildCalendarContent({
    required int year,
    required int month,
    required Map<int, Map<String, dynamic>> dayMap,
    required int totalStyled,
    required bool isDark,
  }) {
    final firstDay = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    // Monday = 1, Sunday = 7
    final startWeekday = firstDay.weekday; // 1-based, Monday=1
    final leadingBlanks = startWeekday - 1;
    final totalCells = leadingBlanks + daysInMonth;
    final rows = (totalCells / 7).ceil();
    final today = DateTime.now();

    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: List.generate(rows, (row) {
                return Expanded(
                  child: Row(
                    children: List.generate(7, (col) {
                      final cellIndex = row * 7 + col;
                      final dayNum = cellIndex - leadingBlanks + 1;

                      if (dayNum < 1 || dayNum > daysInMonth) {
                        return const Expanded(child: SizedBox.shrink());
                      }

                      final hasOutfit = dayMap.containsKey(dayNum);
                      final isToday = today.year == year &&
                          today.month == month &&
                          today.day == dayNum;
                      final isSelected = _selectedDay == dayNum;

                      return Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() => _selectedDay = dayNum);
                            if (hasOutfit) {
                              _showOutfitDetail(dayMap[dayNum]!, isDark);
                            } else {
                              _showAssignPrompt(year, month, dayNum, isDark);
                            }
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            margin: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? (isDark
                                      ? AppColorsDark.orangeSoft
                                      : AppColors.orangeSoft)
                                  : isToday
                                      ? (isDark
                                          ? AppColorsDark.card
                                          : const Color(0xFFF1EFEB))
                                      : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              border: isToday && !isSelected
                                  ? Border.all(
                                      color: isDark
                                          ? AppColorsDark.orange
                                          : AppColors.orange,
                                      width: 1.5)
                                  : null,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '$dayNum',
                                  style: AppTypography.label.copyWith(
                                    fontSize: 14,
                                    fontWeight: isToday
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? (isDark
                                            ? AppColorsDark.orange
                                            : AppColors.orange)
                                        : (isDark
                                            ? AppColorsDark.ink
                                            : AppColors.ink),
                                  ),
                                ),
                                if (hasOutfit)
                                  Container(
                                    margin: const EdgeInsets.only(top: 3),
                                    width: 5,
                                    height: 5,
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? AppColorsDark.orange
                                          : AppColors.orange,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                );
              }),
            ),
          ),
        ),

        // Stats bar
        Container(
          margin: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isDark ? AppColorsDark.card : AppColors.card,
            border: Border.all(
                color: isDark ? AppColorsDark.border : AppColors.border),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color:
                      isDark ? AppColorsDark.orangeSoft : AppColors.orangeSoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.checkroom_outlined,
                    size: 20,
                    color: isDark ? AppColorsDark.orange : AppColors.orange),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: RichText(
                  text: TextSpan(children: [
                    TextSpan(
                      text: '$totalStyled',
                      style: GoogleFonts.instrumentSerif(
                          fontSize: 22,
                          color: isDark ? AppColorsDark.ink : AppColors.ink),
                    ),
                    TextSpan(
                      text: ' days styled this month',
                      style: AppTypography.body.copyWith(
                          color:
                              isDark ? AppColorsDark.ink2 : AppColors.ink2),
                    ),
                  ]),
                ),
              ),
              _MiniProgress(
                value: daysInMonth > 0 ? totalStyled / daysInMonth : 0,
                isDark: isDark,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildShimmerGrid(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Shimmer.fromColors(
        baseColor: isDark ? AppColorsDark.border : AppColors.border,
        highlightColor: isDark ? AppColorsDark.bgWarm : AppColors.bgWarm,
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            crossAxisSpacing: 6,
            mainAxisSpacing: 6,
          ),
          itemCount: 35,
          itemBuilder: (_, __) => Container(
            decoration: BoxDecoration(
              color: isDark ? AppColorsDark.card : AppColors.card,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ),
    );
  }

  void _showOutfitDetail(Map<String, dynamic> entry, bool isDark) {
    final itemIds =
        List<String>.from(entry['item_ids'] ?? const []);
    final occasion = entry['occasion'] ?? '';

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColorsDark.bg : AppColors.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? AppColorsDark.border : AppColors.borderStrong,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text('Outfit for the day',
                      style: GoogleFonts.instrumentSerif(
                          fontSize: 22,
                          color: isDark ? AppColorsDark.ink : AppColors.ink)),
                ),
                if (occasion.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColorsDark.orangeSoft
                          : AppColors.orangeSoft,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(occasion,
                        style: AppTypography.mono.copyWith(
                            fontSize: 10,
                            color: isDark
                                ? AppColorsDark.orange
                                : AppColors.orange)),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (itemIds.isEmpty)
              Text('No items in this outfit.',
                  style: AppTypography.body)
            else
              SizedBox(
                height: 100,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: itemIds.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (_, i) => GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      context.pushNamed('item_detail',
                          pathParameters: {'id': itemIds[i]});
                    },
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: isDark ? AppColorsDark.bgWarm : AppColors.bgWarm,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: isDark
                                ? AppColorsDark.border
                                : AppColors.border),
                      ),
                      child: Center(
                        child: Icon(Icons.checkroom_outlined,
                            color: isDark
                                ? AppColorsDark.ink3
                                : AppColors.ink3,
                            size: 28),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showAssignPrompt(int year, int month, int day, bool isDark) {
    final dateStr =
        '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColorsDark.bg : AppColors.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? AppColorsDark.border : AppColors.borderStrong,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color:
                    isDark ? AppColorsDark.orangeSoft : AppColors.orangeSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.calendar_today_outlined,
                  size: 28,
                  color: isDark ? AppColorsDark.orange : AppColors.orange),
            ),
            const SizedBox(height: 14),
            Text('No outfit planned',
                style: GoogleFonts.instrumentSerif(
                    fontSize: 22,
                    color: isDark ? AppColorsDark.ink : AppColors.ink)),
            const SizedBox(height: 6),
            Text('${_monthName(month)} $day, $year',
                style: AppTypography.caption.copyWith(
                    color: isDark ? AppColorsDark.ink3 : AppColors.ink3)),
            const SizedBox(height: 20),
            SizedBox(
              width: 220,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  final dateIso =
                      '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
                  showCalendarAssignSheet(context, dateIso);
                },
                child: const Text('Pick an outfit'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _monthName(int month) {
    const names = [
      '', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return names[month];
  }
}

class _NavArrow extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isDark;

  const _NavArrow({
    required this.icon,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
              color: isDark ? AppColorsDark.border : AppColors.border),
        ),
        child: Icon(icon,
            size: 20, color: isDark ? AppColorsDark.ink : AppColors.ink),
      ),
    );
  }
}

class _MiniProgress extends StatelessWidget {
  final double value;
  final bool isDark;

  const _MiniProgress({required this.value, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 36,
      child: CustomPaint(
        painter: _CircleProgressPainter(
          progress: value.clamp(0.0, 1.0),
          trackColor: isDark ? AppColorsDark.border : AppColors.border,
          progressColor: isDark ? AppColorsDark.orange : AppColors.orange,
        ),
        child: Center(
          child: Text(
            '${(value * 100).round()}%',
            style: AppTypography.mono.copyWith(
                fontSize: 8,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColorsDark.ink : AppColors.ink),
          ),
        ),
      ),
    );
  }
}

class _CircleProgressPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color progressColor;

  _CircleProgressPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CircleProgressPainter old) =>
      old.progress != progress;
}
