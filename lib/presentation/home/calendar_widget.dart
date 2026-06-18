import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/date_formatter.dart';
import 'home_controller.dart';

/// Custom calendar widget with animated date selection, emotion-colored dots,
/// swipe gesture for month navigation, and today highlight with glow effect.
class CalendarWidget extends StatefulWidget {
  final HomeState state;
  final void Function(DateTime date) onDateSelected;
  final void Function(DateTime month) onMonthChanged;

  const CalendarWidget({
    super.key,
    required this.state,
    required this.onDateSelected,
    required this.onMonthChanged,
  });

  @override
  State<CalendarWidget> createState() => _CalendarWidgetState();
}

class _CalendarWidgetState extends State<CalendarWidget>
    with TickerProviderStateMixin {
  late AnimationController _monthSlideController;
  late Animation<Offset> _monthSlideAnimation;
  late AnimationController _todayGlowController;
  late Animation<double> _todayGlowAnimation;
  late AnimationController _selectionController;
  late Animation<double> _selectionScaleAnimation;

  bool _slideFromRight = true;

  @override
  void initState() {
    super.initState();

    _monthSlideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _updateSlideAnimation();

    _todayGlowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _todayGlowAnimation = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _todayGlowController, curve: Curves.easeInOut),
    );

    _selectionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _selectionScaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _selectionController, curve: Curves.elasticOut),
    );

    _monthSlideController.forward();
  }

  void _updateSlideAnimation() {
    _monthSlideAnimation = Tween<Offset>(
      begin: Offset(_slideFromRight ? 0.15 : -0.15, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _monthSlideController,
      curve: Curves.easeOutCubic,
    ));
  }

  @override
  void didUpdateWidget(CalendarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.focusedMonth != widget.state.focusedMonth) {
      _monthSlideController.reset();
      _updateSlideAnimation();
      _monthSlideController.forward();
    }
    if (oldWidget.state.selectedDate != widget.state.selectedDate) {
      _selectionController.reset();
      _selectionController.forward();
    }
  }

  @override
  void dispose() {
    _monthSlideController.dispose();
    _todayGlowController.dispose();
    _selectionController.dispose();
    super.dispose();
  }

  void _navigateMonth(int direction) {
    _slideFromRight = direction > 0;
    final current = widget.state.focusedMonth;
    final newMonth = DateTime(current.year, current.month + direction);
    widget.onMonthChanged(newMonth);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildMonthHeader(),
        const SizedBox(height: 12),
        _buildWeekdayHeader(),
        const SizedBox(height: 8),
        GestureDetector(
          onHorizontalDragEnd: (details) {
            if (details.primaryVelocity == null) return;
            if (details.primaryVelocity! < -100) {
              _navigateMonth(1); // Swipe left -> next month
            } else if (details.primaryVelocity! > 100) {
              _navigateMonth(-1); // Swipe right -> prev month
            }
          },
          child: SlideTransition(
            position: _monthSlideAnimation,
            child: FadeTransition(
              opacity: CurvedAnimation(
                parent: _monthSlideController,
                curve: Curves.easeOut,
              ),
              child: _buildCalendarGrid(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMonthHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildNavButton(
            icon: Icons.chevron_left_rounded,
            onTap: () => _navigateMonth(-1),
          ),
          GestureDetector(
            onTap: () {
              // Navigate to current month on tap
              final now = DateTime.now();
              widget.onMonthChanged(DateTime(now.year, now.month));
              widget.onDateSelected(now);
            },
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.2),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: Text(
                DateFormatter.formatMonth(widget.state.focusedMonth),
                key: ValueKey(
                    '${widget.state.focusedMonth.year}-${widget.state.focusedMonth.month}'),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
            ),
          ),
          _buildNavButton(
            icon: Icons.chevron_right_rounded,
            onTap: () => _navigateMonth(1),
          ),
        ],
      ),
    );
  }

  Widget _buildNavButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: AppColors.textPrimary, size: 24),
      ),
    );
  }

  Widget _buildWeekdayHeader() {
    const days = ['일', '월', '화', '수', '목', '금', '토'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: days.asMap().entries.map((entry) {
          final index = entry.key;
          final day = entry.value;
          Color color;
          if (index == 0) {
            color = AppColors.error.withValues(alpha: 0.7);
          } else if (index == 6) {
            color = AppColors.secondary;
          } else {
            color = AppColors.textHint;
          }
          return Expanded(
            child: Center(
              child: Text(
                day,
                style: TextStyle(
                  fontSize: 13,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCalendarGrid() {
    final year = widget.state.focusedMonth.year;
    final month = widget.state.focusedMonth.month;
    final firstDay = DateTime(year, month, 1);
    final lastDay = DateTime(year, month + 1, 0);
    final startWeekday = firstDay.weekday % 7; // Sunday = 0

    final cells = <Widget>[];

    // Empty cells before first day
    for (var i = 0; i < startWeekday; i++) {
      cells.add(const SizedBox());
    }

    final now = DateTime.now();

    // Day cells
    for (var day = 1; day <= lastDay.day; day++) {
      final date = DateTime(year, month, day);
      final isSelected = widget.state.selectedDate.year == date.year &&
          widget.state.selectedDate.month == date.month &&
          widget.state.selectedDate.day == date.day;
      final isToday = now.year == date.year &&
          now.month == date.month &&
          now.day == date.day;
      final hasEntry = widget.state.hasEntriesForDate(date);
      final entryCount = widget.state.entryCountForDate(date);
      final emotion = widget.state.emotionForDate(date);
      final weekday = date.weekday % 7;

      cells.add(
        GestureDetector(
          onTap: () => widget.onDateSelected(date),
          child: _buildDayCell(
            day: day,
            isSelected: isSelected,
            isToday: isToday,
            hasEntry: hasEntry,
            entryCount: entryCount,
            emotion: emotion,
            isSunday: weekday == 0,
            isSaturday: weekday == 6,
          ),
        ),
      );
    }

    // Calculate number of rows needed
    final totalCells = startWeekday + lastDay.day;
    final rows = (totalCells / 7).ceil();
    final height = rows * 52.0 + 4;

    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.count(
        crossAxisCount: 7,
        childAspectRatio: 1.0,
        physics: const NeverScrollableScrollPhysics(),
        children: cells,
      ),
    );
  }

  Widget _buildDayCell({
    required int day,
    required bool isSelected,
    required bool isToday,
    required bool hasEntry,
    required int entryCount,
    String? emotion,
    required bool isSunday,
    required bool isSaturday,
  }) {
    // Determine text color
    Color textColor;
    if (isSelected) {
      textColor = Colors.white;
    } else if (isSunday) {
      textColor = AppColors.error.withValues(alpha: 0.7);
    } else if (isSaturday) {
      textColor = AppColors.secondary;
    } else {
      textColor = AppColors.textPrimary;
    }

    // Determine emotion dot color
    Color? emotionDotColor;
    if (hasEntry && emotion != null) {
      emotionDotColor = _getEmotionColor(emotion);
    } else if (hasEntry) {
      emotionDotColor = AppColors.primary;
    }

    Widget cell = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: isSelected ? AppColors.primary : Colors.transparent,
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                  spreadRadius: -1,
                ),
              ]
            : null,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Today glow effect
          if (isToday && !isSelected)
            AnimatedBuilder(
              animation: _todayGlowAnimation,
              builder: (context, child) {
                return Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary
                          .withValues(alpha: _todayGlowAnimation.value),
                      width: 2,
                    ),
                  ),
                );
              },
            ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$day',
                style: TextStyle(
                  fontSize: 14,
                  color: textColor,
                  fontWeight:
                      isToday || isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              // Emotion-colored dots row
              if (hasEntry)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white.withValues(alpha: 0.9)
                            : emotionDotColor ?? AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    if (entryCount > 1) ...[
                      const SizedBox(width: 2),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white.withValues(alpha: 0.6)
                              : (emotionDotColor ?? AppColors.primary)
                                  .withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                    if (entryCount > 2) ...[
                      const SizedBox(width: 2),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white.withValues(alpha: 0.4)
                              : (emotionDotColor ?? AppColors.primary)
                                  .withValues(alpha: 0.3),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                )
              else
                const SizedBox(height: 6),
            ],
          ),
          // Entry count badge (top-right)
          if (entryCount > 0 && !isSelected)
            Positioned(
              top: 2,
              right: 4,
              child: Container(
                padding: const EdgeInsets.all(2),
                constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Center(
                  child: Text(
                    '$entryCount',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    // Scale animation on selection
    if (isSelected) {
      cell = ScaleTransition(
        scale: _selectionScaleAnimation,
        child: cell,
      );
    }

    return cell;
  }

  Color _getEmotionColor(String emotion) {
    switch (emotion) {
      case 'happy':
        return AppColors.emotionHappy;
      case 'crying':
        return AppColors.emotionCrying;
      case 'surprised':
        return AppColors.emotionSurprised;
      case 'neutral':
      default:
        return AppColors.emotionNeutral;
    }
  }
}
