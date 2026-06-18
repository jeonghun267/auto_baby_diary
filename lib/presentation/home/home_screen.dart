import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/providers/app_providers.dart';
import '../../core/providers/streak_provider.dart';
import '../../data/models/child_profile.dart';
import '../../core/utils/date_formatter.dart';
import '../common/child_switcher_sheet.dart';
import '../widgets/streak_badge_widget.dart';
import '../widgets/time_capsule_widget.dart';
import 'home_controller.dart';
import 'home_tour.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  // ── Tour keys ──────────────────────────────────────────
  final _calendarKey = GlobalKey();
  final _fabKey = GlobalKey();
  final _quickActions1Key = GlobalKey();
  final _quickActions2Key = GlobalKey();
  bool _tourCheckScheduled = false;
  OverlayEntry? _tourEntry;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _connectChildProfile();
    });
  }

  @override
  void dispose() {
    _tourEntry?.remove();
    super.dispose();
  }

  void _connectChildProfile() {
    final child = ref.read(currentChildProvider);
    if (child != null) {
      ref.read(homeControllerProvider.notifier).selectChild(child);
    }
  }

  // ── Tour ───────────────────────────────────────────────

  void _maybeScheduleTour() {
    if (_tourCheckScheduled) return;
    _tourCheckScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final seen = await hasSeenHomeTour();
      if (!seen && mounted) _insertTourOverlay();
    });
  }

  void _insertTourOverlay() {
    if (_tourEntry != null) return;
    _tourEntry = OverlayEntry(
      builder: (_) => HomeTourOverlay(
        steps: [
          HomeTourStep(
            targetKey: _calendarKey,
            emoji: '📅',
            title: '날짜별 일기 캘린더',
            description:
                '날짜를 탭하면 그날의 일기 목록이 아래에 펼쳐져요.\n색깔 점이 있는 날엔 일기가 기록돼 있어요.',
          ),
          HomeTourStep(
            targetKey: _fabKey,
            emoji: '📸',
            title: 'AI 일기 기록 버튼',
            description: '짧게 누르면 빠른 기록,\n길게 누르면 사진·음성 전체 기록 화면이 열려요.',
          ),
          HomeTourStep(
            targetKey: _quickActions1Key,
            emoji: '⚡',
            title: '빠른 메뉴',
            description: '앨범, 성장 기록, 마일스톤, 일상 기록, 예방접종을\n한 번에 바로 이동할 수 있어요.',
          ),
          HomeTourStep(
            targetKey: _quickActions2Key,
            emoji: '📊',
            title: '리포트 & 더보기',
            description: '월간 리포트, 통계, 가족 공유, 데이터 내보내기,\n프리미엄 기능을 여기서 이용해요.',
          ),
        ],
        onComplete: _completeTour,
      ),
    );
    Overlay.of(context).insert(_tourEntry!);
  }

  Future<void> _completeTour() async {
    _tourEntry?.remove();
    _tourEntry = null;
    await markHomeTourSeen();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(homeControllerProvider);
    final controller = ref.read(homeControllerProvider.notifier);
    final child = ref.watch(currentChildProvider);

    // 아이가 변경되면 컨트롤러에 반영
    ref.listen(currentChildProvider, (prev, next) {
      if (next != null && next.id != prev?.id) {
        controller.selectChild(next);
      }
    });

    // 투어: 아이 프로필이 로드되는 순간 첫 방문 여부 확인
    ref.listen<ChildProfile?>(currentChildProvider, (prev, next) {
      if (next != null) _maybeScheduleTour();
    });
    if (child != null) _maybeScheduleTour();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        title: child != null
            ? InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => ChildSwitcherSheet.show(context),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        AppStrings.appName,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${child.name} (${child.ageInMonths}개월)',
                            style: AppTextStyles.bodySmall,
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            Icons.expand_more_rounded,
                            size: 16,
                            color: AppColors.textSecondary,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              )
            : Text(
                AppStrings.appName,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
        centerTitle: true,
        actions: [
          if (child != null) ...[
            IconButton(
              icon: const Icon(Icons.help_outline_rounded,
                  color: AppColors.textSecondary),
              tooltip: '이용 가이드',
              onPressed: () {
                if (_tourEntry != null) return;
                _insertTourOverlay();
              },
            ),
            IconButton(
              icon: const Icon(Icons.search_rounded,
                  color: AppColors.textSecondary),
              onPressed: () => context.push('/search'),
            ),
          ],
          if (child == null)
            IconButton(
              icon: const Icon(Icons.child_care, color: AppColors.primary),
              onPressed: () => context.push('/profile/add-child'),
            ),
        ],
      ),
      body: child == null
          ? _buildNoChildState(context)
          : RefreshIndicator(
              onRefresh: () => controller.refresh(),
              color: AppColors.primary,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                      child: _buildCalendarHeader(state, controller)),
                  SliverToBoxAdapter(child: _buildWeekdayHeader()),
                  SliverToBoxAdapter(
                    child: KeyedSubtree(
                      key: _calendarKey,
                      child: _buildCalendarGrid(state, controller),
                    ),
                  ),
                  SliverToBoxAdapter(child: _buildStreakBadge()),
                  SliverToBoxAdapter(child: _buildQuickActions(context)),
                  if (state.timeCapsuleEntry != null)
                    SliverToBoxAdapter(
                      child: TimeCapsuleWidget(entry: state.timeCapsuleEntry),
                    ),
                  const SliverToBoxAdapter(child: Divider(height: 1)),
                  _buildDiarySliverList(context, state),
                ],
              ),
            ),
      floatingActionButton: child != null
          ? GestureDetector(
              key: _fabKey,
              onLongPress: () => context.go('/record'),
              child: FloatingActionButton(
                backgroundColor: AppColors.primary,
                tooltip: '짧게: 퀵 기록 / 길게: 전체 기록',
                onPressed: () => context.push('/quick-record'),
                child:
                    const Icon(Icons.add_a_photo_rounded, color: Colors.white),
              ),
            )
          : null,
    );
  }

  Widget _buildNoChildState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.primaryLight.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.child_care_rounded,
                  size: 50, color: AppColors.primary),
            ),
            const SizedBox(height: 20),
            Text('아이를 등록해주세요', style: AppTextStyles.h3),
            const SizedBox(height: 8),
            Text(
              '아이 프로필을 등록하면\n일기 기록을 시작할 수 있어요',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => context.push('/profile/add-child'),
              icon: const Icon(Icons.add),
              label: const Text('아이 등록하기'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarHeader(HomeState state, HomeController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              final prev = DateTime(
                  state.focusedMonth.year, state.focusedMonth.month - 1);
              controller.changeMonth(prev);
            },
          ),
          Expanded(
            child: Center(
              child: Text(
                DateFormatter.formatMonth(state.focusedMonth),
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              final next = DateTime(
                  state.focusedMonth.year, state.focusedMonth.month + 1);
              controller.changeMonth(next);
            },
          ),
          IconButton(
            icon: Icon(
              state.isWeekView ? Icons.calendar_month : Icons.view_week,
            ),
            tooltip: state.isWeekView ? '월간 보기' : '주간 보기',
            onPressed: () => controller.toggleCalendarView(),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekdayHeader() {
    const days = ['일', '월', '화', '수', '목', '금', '토'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: days
            .map((d) => Expanded(
                  child: Center(
                    child: Text(
                      d,
                      style: TextStyle(
                        fontSize: 12,
                        color: d == '일'
                            ? AppColors.error
                            : d == '토'
                                ? AppColors.secondary
                                : AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildCalendarGrid(HomeState state, HomeController controller) {
    final year = state.focusedMonth.year;
    final month = state.focusedMonth.month;
    final firstDay = DateTime(year, month, 1);
    final lastDay = DateTime(year, month + 1, 0);
    final startWeekday = firstDay.weekday % 7;

    final days = <Widget>[];

    for (var i = 0; i < startWeekday; i++) {
      days.add(const SizedBox());
    }

    for (var day = 1; day <= lastDay.day; day++) {
      final date = DateTime(year, month, day);
      final isSelected = state.selectedDate.year == date.year &&
          state.selectedDate.month == date.month &&
          state.selectedDate.day == date.day;
      final hasEntry = state.hasEntriesForDate(date);
      final emotion = state.emotionForDate(date);
      final isToday = DateTime.now().year == date.year &&
          DateTime.now().month == date.month &&
          DateTime.now().day == date.day;

      days.add(
        GestureDetector(
          onTap: () => controller.selectDate(date),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary
                  : isToday
                      ? AppColors.primaryLight.withValues(alpha: 0.3)
                      : null,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$day',
                  style: TextStyle(
                    fontSize: 14,
                    color: isSelected ? Colors.white : AppColors.textPrimary,
                    fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                if (hasEntry)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color:
                          isSelected ? Colors.white : _getEmotionColor(emotion),
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    final totalCells = startWeekday + lastDay.day;
    final totalRows = (totalCells / 7).ceil();

    if (state.isWeekView) {
      // Find the row index containing the selected date
      final selectedDay =
          state.selectedDate.month == month && state.selectedDate.year == year
              ? state.selectedDate.day
              : 1;
      final selectedCellIndex = startWeekday + selectedDay - 1;
      final selectedRowIndex = selectedCellIndex ~/ 7;
      final rowStart = selectedRowIndex * 7;

      final weekDays = <Widget>[];
      for (var i = rowStart; i < rowStart + 7; i++) {
        if (i < days.length) {
          weekDays.add(days[i]);
        } else {
          weekDays.add(const SizedBox());
        }
      }

      return AnimatedSize(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        child: Container(
          height: 44.0 + 8,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GridView.count(
            crossAxisCount: 7,
            physics: const NeverScrollableScrollPhysics(),
            children: weekDays,
          ),
        ),
      );
    }

    final gridHeight = totalRows * 44.0 + 8;

    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: Container(
        height: gridHeight,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: GridView.count(
          crossAxisCount: 7,
          physics: const NeverScrollableScrollPhysics(),
          children: days,
        ),
      ),
    );
  }

  Widget _buildDiarySliverList(BuildContext context, HomeState state) {
    if (state.isLoading) {
      return const SliverFillRemaining(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (state.selectedDateEntries.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.note_add_outlined,
                    size: 48, color: AppColors.textHint),
                const SizedBox(height: 12),
                Text(
                  AppStrings.noDiaryForDate,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 8),
                Text(
                  '오른쪽 아래 📷 버튼을 눌러 일기를 시작해보세요',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.caption,
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => context.push('/quick-record'),
                  icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                  label: const Text('일기 기록하기'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: BorderSide(
                      color: AppColors.primary.withValues(alpha: 0.5),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final entry = state.selectedDateEntries[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 1,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => context.push('/diary/${entry.id}'),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            DateFormatter.formatTime(entry.recordedAt),
                            style: AppTextStyles.labelMedium,
                          ),
                          const Spacer(),
                          if (entry.emotionSummary != null)
                            Text(_getEmotionEmoji(entry.emotionSummary!),
                                style: const TextStyle(fontSize: 22)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        entry.finalText ?? entry.llmDraft ?? '일기 내용이 없습니다',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyMedium.copyWith(height: 1.6),
                      ),
                      if (entry.milestoneDetected != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '🎉 ${entry.milestoneDetected}',
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.success),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
          childCount: state.selectedDateEntries.length,
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          // 1행: 앨범 · 성장 · 마일스톤 · 일상 · 접종
          SizedBox(
            key: _quickActions1Key,
            child: Row(
              children: [
                _buildQuickActionItem(
                  context,
                  icon: Icons.photo_library_outlined,
                  label: '앨범',
                  color: AppColors.secondary,
                  onTap: () => context.push('/gallery'),
                ),
                const SizedBox(width: 10),
                _buildQuickActionItem(
                  context,
                  icon: Icons.straighten_outlined,
                  label: '성장',
                  color: AppColors.success,
                  onTap: () => context.push('/growth'),
                ),
                const SizedBox(width: 10),
                _buildQuickActionItem(
                  context,
                  icon: Icons.emoji_events_outlined,
                  label: '마일스톤',
                  color: AppColors.emotionHappy,
                  onTap: () => context.push('/milestones'),
                ),
                const SizedBox(width: 10),
                _buildQuickActionItem(
                  context,
                  icon: Icons.baby_changing_station_outlined,
                  label: '일상',
                  color: AppColors.primaryDark,
                  onTap: () => context.push('/daily-records'),
                ),
                const SizedBox(width: 10),
                _buildQuickActionItem(
                  context,
                  icon: Icons.vaccines_outlined,
                  label: '접종',
                  color: AppColors.emotionSurprised,
                  onTap: () => context.push('/vaccination'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // 2행: 리포트 · 통계 · 가족 · 내보내기 · 프리미엄
          SizedBox(
            key: _quickActions2Key,
            child: Row(
              children: [
                _buildQuickActionItem(
                  context,
                  icon: Icons.auto_awesome,
                  label: '리포트',
                  color: AppColors.primaryDark,
                  onTap: () => context.push('/report'),
                ),
                const SizedBox(width: 10),
                _buildQuickActionItem(
                  context,
                  icon: Icons.bar_chart_rounded,
                  label: '통계',
                  color: AppColors.secondaryDark,
                  onTap: () => context.push('/stats'),
                ),
                const SizedBox(width: 10),
                _buildQuickActionItem(
                  context,
                  icon: Icons.group_outlined,
                  label: '가족',
                  color: AppColors.secondary,
                  onTap: () => context.push('/family'),
                ),
                const SizedBox(width: 10),
                _buildQuickActionItem(
                  context,
                  icon: Icons.description_outlined,
                  label: '내보내기',
                  color: AppColors.success,
                  onTap: () => context.push('/export'),
                ),
                const SizedBox(width: 10),
                _buildQuickActionItem(
                  context,
                  icon: Icons.star_outline_rounded,
                  label: '프리미엄',
                  color: AppColors.emotionSurprised,
                  onTap: () => context.push('/premium'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStreakBadge() {
    final streakAsync = ref.watch(streakProvider);
    return streakAsync.when(
      data: (streak) => StreakBadgeWidget(streakCount: streak),
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Color _getEmotionColor(String? emotion) {
    switch (emotion) {
      case 'happy':
        return AppColors.emotionHappy;
      case 'crying':
        return AppColors.emotionCrying;
      case 'surprised':
        return AppColors.emotionSurprised;
      default:
        return AppColors.primary;
    }
  }

  String _getEmotionEmoji(String emotion) {
    switch (emotion) {
      case 'happy':
        return '😊';
      case 'crying':
        return '😢';
      case 'surprised':
        return '😮';
      default:
        return '😐';
    }
  }
}
