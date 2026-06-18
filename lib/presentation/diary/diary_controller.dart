import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/gemini_service.dart';
import '../../data/models/diary_entry.dart';
import '../../data/repositories/diary_repository.dart';

/// 일기 상세 화면 상태
class DiaryDetailState {
  final DiaryEntry? entry;
  final DiaryGenerationResult? generationResult;
  final bool isLoading;
  final bool isSaving;
  final bool isRegenerating;
  final bool isDeleting;
  final String? error;

  DiaryDetailState({
    this.entry,
    this.generationResult,
    this.isLoading = false,
    this.isSaving = false,
    this.isRegenerating = false,
    this.isDeleting = false,
    this.error,
  });

  DiaryDetailState copyWith({
    DiaryEntry? entry,
    DiaryGenerationResult? generationResult,
    bool? isLoading,
    bool? isSaving,
    bool? isRegenerating,
    bool? isDeleting,
    String? error,
  }) {
    return DiaryDetailState(
      entry: entry ?? this.entry,
      generationResult: generationResult ?? this.generationResult,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      isRegenerating: isRegenerating ?? this.isRegenerating,
      isDeleting: isDeleting ?? this.isDeleting,
      error: error,
    );
  }
}

class DiaryController extends StateNotifier<DiaryDetailState> {
  final Ref _ref;
  final DiaryRepository _diaryRepository;
  final GeminiService _geminiService;
  final int _childAgeMonths;

  DiaryController(
    this._ref,
    this._diaryRepository,
    this._geminiService,
    this._childAgeMonths,
  ) : super(DiaryDetailState());

  /// 일기 로드
  Future<void> loadEntry(String id) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final entry = await _diaryRepository.getDiaryEntry(id);
      state = state.copyWith(entry: entry, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// 일기 저장 (final_text 업데이트)
  Future<void> saveEntry(String id, String finalText) async {
    state = state.copyWith(isSaving: true, error: null);
    try {
      final updated = await _diaryRepository.updateDiaryEntry(
        id,
        {'final_text': finalText, 'is_edited': true},
      );
      // 관련 provider 새로고침
      _invalidateAll(updated.childId);
      state = state.copyWith(entry: updated, isSaving: false);
    } catch (e) {
      state = state.copyWith(isSaving: false, error: e.toString());
    }
  }

  /// 일기 삭제
  /// 반환: true 성공, false 실패
  Future<bool> deleteEntry(String id) async {
    final entry = state.entry;
    state = state.copyWith(isDeleting: true, error: null);
    try {
      await _diaryRepository.deleteDiaryEntry(id);
      if (entry != null) {
        _invalidateAll(entry.childId);
      }
      state = state.copyWith(isDeleting: false);
      return true;
    } catch (e) {
      state = state.copyWith(isDeleting: false, error: e.toString());
      return false;
    }
  }

  /// 일기 재생성
  Future<void> regenerateEntry(String id) async {
    final entry = state.entry;
    if (entry == null) return;

    state = state.copyWith(isRegenerating: true, error: null);
    try {
      final result = await _geminiService.generateDiary(
        visionData: entry.visionData ?? {},
        childAgeMonths: _childAgeMonths,
        existingTranscript: entry.sttTranscript,
      );

      final updated = await _diaryRepository.updateDiaryEntry(
        id,
        {
          'llm_draft': result.diaryDraft,
          'final_text': result.diaryDraft,
          // AI 재생성은 사용자 편집이 아니므로 is_edited 초기화
          'is_edited': false,
        },
      );

      _invalidateAll(updated.childId);

      state = state.copyWith(
        entry: updated,
        generationResult: result,
        isRegenerating: false,
      );
    } catch (e) {
      state = state.copyWith(isRegenerating: false, error: e.toString());
    }
  }

  void _invalidateAll(String childId) {
    _ref.invalidate(diaryListProvider(childId));
    _ref.invalidate(currentChildDiaryListProvider);
    _ref.invalidate(diaryEntryProvider);
  }
}

final diaryControllerProvider =
    StateNotifierProvider<DiaryController, DiaryDetailState>((ref) {
  final child = ref.watch(currentChildProvider);
  return DiaryController(
    ref,
    ref.watch(diaryRepositoryProvider),
    ref.watch(geminiServiceProvider),
    child?.ageInMonths ?? 12,
  );
});
