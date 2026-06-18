import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/app_providers.dart';
import '../../data/models/child_profile.dart';
import '../../data/models/diary_entry.dart';
import '../../data/repositories/diary_repository.dart';

/// 홈 화면 상태
class HomeState {
  final DateTime selectedDate;
  final DateTime focusedMonth;
  final List<DiaryEntry> selectedDateEntries;
  final List<DateTime> datesWithEntries;
  final Map<String, int> dateEntryCounts;
  final Map<String, String> dateEmotions;
  final bool isLoading;
  final bool isRefreshing;
  final String? error;
  final List<ChildProfile> childProfiles;
  final ChildProfile? selectedChild;
  final bool isWeekView;
  final DiaryEntry? timeCapsuleEntry;

  HomeState({
    required this.selectedDate,
    required this.focusedMonth,
    this.selectedDateEntries = const [],
    this.datesWithEntries = const [],
    this.dateEntryCounts = const {},
    this.dateEmotions = const {},
    this.isLoading = false,
    this.isRefreshing = false,
    this.error,
    this.childProfiles = const [],
    this.selectedChild,
    this.isWeekView = false,
    this.timeCapsuleEntry,
  });

  HomeState copyWith({
    DateTime? selectedDate,
    DateTime? focusedMonth,
    List<DiaryEntry>? selectedDateEntries,
    List<DateTime>? datesWithEntries,
    Map<String, int>? dateEntryCounts,
    Map<String, String>? dateEmotions,
    bool? isLoading,
    bool? isRefreshing,
    String? error,
    List<ChildProfile>? childProfiles,
    ChildProfile? selectedChild,
    bool? isWeekView,
    DiaryEntry? timeCapsuleEntry,
    bool clearTimeCapsule = false,
  }) {
    return HomeState(
      selectedDate: selectedDate ?? this.selectedDate,
      focusedMonth: focusedMonth ?? this.focusedMonth,
      selectedDateEntries: selectedDateEntries ?? this.selectedDateEntries,
      datesWithEntries: datesWithEntries ?? this.datesWithEntries,
      dateEntryCounts: dateEntryCounts ?? this.dateEntryCounts,
      dateEmotions: dateEmotions ?? this.dateEmotions,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      error: error,
      childProfiles: childProfiles ?? this.childProfiles,
      selectedChild: selectedChild ?? this.selectedChild,
      isWeekView: isWeekView ?? this.isWeekView,
      timeCapsuleEntry:
          clearTimeCapsule ? null : (timeCapsuleEntry ?? this.timeCapsuleEntry),
    );
  }

  /// Helper to get date key string for maps
  static String dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  /// Get entry count for a specific date
  int entryCountForDate(DateTime date) => dateEntryCounts[dateKey(date)] ?? 0;

  /// Get primary emotion for a specific date
  String? emotionForDate(DateTime date) => dateEmotions[dateKey(date)];

  /// Check if a date has entries
  bool hasEntriesForDate(DateTime date) => datesWithEntries.any(
      (d) => d.year == date.year && d.month == date.month && d.day == date.day);
}

class HomeController extends StateNotifier<HomeState> {
  final DiaryRepository _diaryRepository;
  String? _childId;

  HomeController(this._diaryRepository, this._childId)
      : super(HomeState(
          selectedDate: DateTime.now(),
          focusedMonth: DateTime.now(),
        )) {
    if (_childId != null) {
      _init();
    }
  }

  void _init() {
    loadMonth(DateTime.now());
    loadEntriesForDate(DateTime.now());
    _loadTimeCapsuleEntry();
  }

  /// 1년 전 오늘의 일기 로드
  Future<void> _loadTimeCapsuleEntry() async {
    if (_childId == null) return;
    try {
      final now = DateTime.now();
      final oneYearAgo = DateTime(now.year - 1, now.month, now.day);
      final entries = await _diaryRepository.getDiaryEntriesByDate(
        _childId!,
        oneYearAgo,
      );
      if (entries.isNotEmpty) {
        state = state.copyWith(timeCapsuleEntry: entries.first);
      } else {
        state = state.copyWith(clearTimeCapsule: true);
      }
    } catch (_) {
      // Silently fail - time capsule is optional
    }
  }

  /// Set the selected child profile
  void selectChild(ChildProfile child) {
    _childId = child.id;
    state = state.copyWith(
      selectedChild: child,
      selectedDateEntries: [],
      datesWithEntries: [],
      dateEntryCounts: {},
      dateEmotions: {},
    );
    _init();
  }

  /// Set child profiles list
  void setChildProfiles(List<ChildProfile> profiles) {
    state = state.copyWith(childProfiles: profiles);
    if (profiles.isNotEmpty && state.selectedChild == null) {
      selectChild(profiles.first);
    }
  }

  /// 특정 월의 일기 있는 날짜 목록 로드
  Future<void> loadMonth(DateTime month) async {
    if (_childId == null) return;
    try {
      final dates = await _diaryRepository.getDatesWithEntries(
        _childId!,
        month.year,
        month.month,
      );

      // Build entry count map
      final counts = <String, int>{};
      for (final date in dates) {
        final key = HomeState.dateKey(date);
        counts[key] = (counts[key] ?? 0) + 1;
      }

      state = state.copyWith(
        focusedMonth: month,
        datesWithEntries: dates.toSet().toList(),
        dateEntryCounts: counts,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// 특정 날짜의 일기 목록 로드
  Future<void> loadEntriesForDate(DateTime date) async {
    if (_childId == null) return;
    state = state.copyWith(selectedDate: date, isLoading: true, error: null);
    try {
      final entries = await _diaryRepository.getDiaryEntriesByDate(
        _childId!,
        date,
      );

      // Update emotion map from actual entries
      final emotions = Map<String, String>.from(state.dateEmotions);
      if (entries.isNotEmpty) {
        final primaryEmotion = entries
            .firstWhere(
              (e) => e.emotionSummary != null,
              orElse: () => entries.first,
            )
            .emotionSummary;
        if (primaryEmotion != null) {
          emotions[HomeState.dateKey(date)] = primaryEmotion;
        }
      }

      // Update entry count
      final counts = Map<String, int>.from(state.dateEntryCounts);
      counts[HomeState.dateKey(date)] = entries.length;

      state = state.copyWith(
        selectedDateEntries: entries,
        isLoading: false,
        dateEmotions: emotions,
        dateEntryCounts: counts,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Pull-to-refresh
  Future<void> refresh() async {
    state = state.copyWith(isRefreshing: true);
    await loadMonth(state.focusedMonth);
    await loadEntriesForDate(state.selectedDate);
    state = state.copyWith(isRefreshing: false);
  }

  void selectDate(DateTime date) {
    loadEntriesForDate(date);
  }

  void changeMonth(DateTime month) {
    loadMonth(month);
  }

  void toggleCalendarView() {
    state = state.copyWith(isWeekView: !state.isWeekView);
  }
}

final homeControllerProvider =
    StateNotifierProvider<HomeController, HomeState>((ref) {
  final diaryRepo = ref.watch(diaryRepositoryProvider);
  final selectedChildId = ref.watch(selectedChildIdProvider);
  return HomeController(diaryRepo, selectedChildId);
});
