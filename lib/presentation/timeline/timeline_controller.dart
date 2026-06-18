import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/app_providers.dart';
import '../../data/models/diary_entry.dart';
import '../../data/repositories/diary_repository.dart';

/// 타임라인 화면 상태
class TimelineState {
  final List<DiaryEntry> entries;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final int loadedPages;
  final String? error;

  const TimelineState({
    this.entries = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.loadedPages = 0,
    this.error,
  });

  TimelineState copyWith({
    List<DiaryEntry>? entries,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    int? loadedPages,
    String? error,
  }) {
    return TimelineState(
      entries: entries ?? this.entries,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      loadedPages: loadedPages ?? this.loadedPages,
      error: error,
    );
  }
}

class TimelineController extends StateNotifier<TimelineState> {
  final DiaryRepository _diaryRepository;
  final String? _childId;

  static const int pageSize = 20;

  TimelineController(this._diaryRepository, this._childId)
      : super(const TimelineState()) {
    if (_childId != null) {
      loadInitial();
    }
  }

  /// 초기 로드 (첫 페이지)
  Future<void> loadInitial() async {
    if (_childId == null) return;
    state = state.copyWith(
      isLoading: true,
      error: null,
      entries: [],
      loadedPages: 0,
      hasMore: true,
    );
    try {
      final page = await _diaryRepository.getDiaryEntriesPaged(
        _childId,
        offset: 0,
        limit: pageSize,
      );
      state = state.copyWith(
        entries: page,
        isLoading: false,
        hasMore: page.length == pageSize,
        loadedPages: 1,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// 다음 페이지 로드 (무한 스크롤)
  Future<void> loadMore() async {
    if (_childId == null ||
        state.isLoadingMore ||
        state.isLoading ||
        !state.hasMore) {
      return;
    }
    state = state.copyWith(isLoadingMore: true);
    try {
      final offset = state.loadedPages * pageSize;
      final page = await _diaryRepository.getDiaryEntriesPaged(
        _childId,
        offset: offset,
        limit: pageSize,
      );
      state = state.copyWith(
        entries: [...state.entries, ...page],
        isLoadingMore: false,
        hasMore: page.length == pageSize,
        loadedPages: state.loadedPages + 1,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false, error: e.toString());
    }
  }

  /// 새로고침 (풀 투 리프레시)
  Future<void> refresh() => loadInitial();

  /// 월별로 그룹핑된 엔트리
  Map<String, List<DiaryEntry>> get groupedByMonth {
    final map = <String, List<DiaryEntry>>{};
    for (final entry in state.entries) {
      final key = '${entry.recordedAt.year}년 ${entry.recordedAt.month}월';
      map.putIfAbsent(key, () => []).add(entry);
    }
    return map;
  }
}

final timelineControllerProvider =
    StateNotifierProvider.autoDispose<TimelineController, TimelineState>((ref) {
  final diaryRepo = ref.watch(diaryRepositoryProvider);
  final child = ref.watch(currentChildProvider);
  return TimelineController(diaryRepo, child?.id);
});
