import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/audio_service.dart';
import '../../core/services/camera_service.dart';
import '../../core/services/gemini_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/supabase_service.dart';
import '../../core/services/vision_service.dart';
import '../../core/services/yolo_behavior_service.dart';
import '../../core/services/yolo_video_behavior_service.dart';
import '../../data/models/diary_entry.dart';
import '../../data/repositories/diary_repository.dart';

/// 기록 화면 상태
enum RecordingMode { photo, video }

/// AI 처리 단계
enum ProcessingStep {
  none,
  analyzingFace, // 얼굴 분석 중...
  uploadingMedia, // 미디어 업로드 중...
  convertingSpeech, // 음성 변환 중...
  writingDiary, // 일기 작성 중...
  saving, // 저장 중...
  complete, // 완료!
}

class RecordState {
  final RecordingMode mode;
  final bool isRecordingVideo;
  final bool isRecordingAudio;
  final bool isProcessing;
  final ProcessingStep processingStep;
  final double processingProgress; // 0.0 ~ 1.0
  final String? capturedMediaPath;
  final String? audioPath;
  final DiaryEntry? generatedEntry;
  final String? error;
  final bool isCameraReady;
  final bool isSwitchingCamera;
  final int audioRecordingSeconds;

  RecordState({
    this.mode = RecordingMode.photo,
    this.isRecordingVideo = false,
    this.isRecordingAudio = false,
    this.isProcessing = false,
    this.processingStep = ProcessingStep.none,
    this.processingProgress = 0.0,
    this.capturedMediaPath,
    this.audioPath,
    this.generatedEntry,
    this.error,
    this.isCameraReady = false,
    this.isSwitchingCamera = false,
    this.audioRecordingSeconds = 0,
  });

  String get processingStepLabel {
    switch (processingStep) {
      case ProcessingStep.none:
        return '';
      case ProcessingStep.analyzingFace:
        return '얼굴 분석 중...';
      case ProcessingStep.uploadingMedia:
        return '미디어 업로드 중...';
      case ProcessingStep.convertingSpeech:
        return '음성 변환 중...';
      case ProcessingStep.writingDiary:
        return 'AI가 일기를 작성하고 있어요...';
      case ProcessingStep.saving:
        return '저장 중...';
      case ProcessingStep.complete:
        return '완료!';
    }
  }

  String get processingStepEmoji {
    switch (processingStep) {
      case ProcessingStep.none:
        return '';
      case ProcessingStep.analyzingFace:
        return '👶';
      case ProcessingStep.uploadingMedia:
        return '☁️';
      case ProcessingStep.convertingSpeech:
        return '🎤';
      case ProcessingStep.writingDiary:
        return '✨';
      case ProcessingStep.saving:
        return '💾';
      case ProcessingStep.complete:
        return '🎉';
    }
  }

  int get processingStepIndex {
    switch (processingStep) {
      case ProcessingStep.none:
        return 0;
      case ProcessingStep.analyzingFace:
        return 1;
      case ProcessingStep.uploadingMedia:
        return 2;
      case ProcessingStep.convertingSpeech:
        return 3;
      case ProcessingStep.writingDiary:
        return 4;
      case ProcessingStep.saving:
        return 5;
      case ProcessingStep.complete:
        return 6;
    }
  }

  static const int totalProcessingSteps = 5;

  String get userFriendlyError {
    if (error == null) return '';
    final e = error!.toLowerCase();
    if (e.contains('camera') || e.contains('카메라')) {
      return '카메라에 접근할 수 없어요.\n설정에서 카메라 권한을 확인해주세요.';
    }
    if (e.contains('microphone') ||
        e.contains('마이크') ||
        e.contains('permission')) {
      return '마이크에 접근할 수 없어요.\n설정에서 마이크 권한을 확인해주세요.';
    }
    if (e.contains('network') ||
        e.contains('socket') ||
        e.contains('connection')) {
      return '네트워크 연결이 불안정해요.\n인터넷 연결을 확인해주세요.';
    }
    if (e.contains('timeout')) {
      return '서버 응답이 지연되고 있어요.\n잠시 후 다시 시도해주세요.';
    }
    // 기기 저장 공간 부족 (디스크)
    if (e.contains('no space') ||
        e.contains('insufficient') ||
        e.contains('enospc') ||
        e.contains('disk full')) {
      return '저장 공간이 부족해요.\n불필요한 파일을 삭제해주세요.';
    }
    // Supabase Storage 업로드 실패 (버킷/MIME/권한 등)
    if (e.contains('storage') ||
        e.contains('bucket') ||
        e.contains('mime') ||
        e.contains('415')) {
      return '사진·음성 업로드에 실패했어요.\n잠시 후 다시 시도해주세요.';
    }
    return '일시적인 오류가 발생했어요.\n잠시 후 다시 시도해주세요.';
  }

  /// [clearCapturedMediaPath], [clearAudioPath], [clearGeneratedEntry] 를
  /// true로 설정하면 해당 필드를 null로 초기화합니다.
  RecordState copyWith({
    RecordingMode? mode,
    bool? isRecordingVideo,
    bool? isRecordingAudio,
    bool? isProcessing,
    ProcessingStep? processingStep,
    double? processingProgress,
    String? capturedMediaPath,
    String? audioPath,
    DiaryEntry? generatedEntry,
    String? error,
    bool? isCameraReady,
    bool? isSwitchingCamera,
    int? audioRecordingSeconds,
    bool clearCapturedMediaPath = false,
    bool clearAudioPath = false,
    bool clearGeneratedEntry = false,
  }) {
    return RecordState(
      mode: mode ?? this.mode,
      isRecordingVideo: isRecordingVideo ?? this.isRecordingVideo,
      isRecordingAudio: isRecordingAudio ?? this.isRecordingAudio,
      isProcessing: isProcessing ?? this.isProcessing,
      processingStep: processingStep ?? this.processingStep,
      processingProgress: processingProgress ?? this.processingProgress,
      capturedMediaPath: clearCapturedMediaPath
          ? null
          : (capturedMediaPath ?? this.capturedMediaPath),
      audioPath: clearAudioPath ? null : (audioPath ?? this.audioPath),
      generatedEntry:
          clearGeneratedEntry ? null : (generatedEntry ?? this.generatedEntry),
      error: error,
      isCameraReady: isCameraReady ?? this.isCameraReady,
      isSwitchingCamera: isSwitchingCamera ?? this.isSwitchingCamera,
      audioRecordingSeconds:
          audioRecordingSeconds ?? this.audioRecordingSeconds,
    );
  }
}

class RecordController extends StateNotifier<RecordState> {
  final Ref _ref;
  final CameraService _cameraService;
  final AudioService _audioService;
  final VisionService _visionService;
  final YoloBehaviorService _yoloBehaviorService;
  final YoloVideoBehaviorService _yoloVideoBehaviorService;
  final StorageService _storageService;
  final GeminiService _geminiService;
  final DiaryRepository _diaryRepository;

  RecordController(
    this._ref,
    this._cameraService,
    this._audioService,
    this._visionService,
    this._yoloBehaviorService,
    this._yoloVideoBehaviorService,
    this._storageService,
    this._geminiService,
    this._diaryRepository,
  ) : super(RecordState());

  /// 카메라 초기화
  Future<void> initCamera() async {
    try {
      await _cameraService.initialize();
      state = state.copyWith(isCameraReady: true);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// 모드 전환 (사진/동영상)
  void toggleMode() {
    state = state.copyWith(
      mode: state.mode == RecordingMode.photo
          ? RecordingMode.video
          : RecordingMode.photo,
    );
  }

  /// 카메라 전환 (전면/후면)
  Future<void> switchCamera() async {
    try {
      state = state.copyWith(isSwitchingCamera: true);
      await _cameraService.switchCamera();
      state = state.copyWith(isSwitchingCamera: false);
    } catch (e) {
      state = state.copyWith(isSwitchingCamera: false, error: e.toString());
    }
  }

  /// 사진 촬영
  Future<void> takePhoto() async {
    try {
      final path = await _cameraService.takePhoto();
      state = state.copyWith(capturedMediaPath: path);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// 동영상 녹화 시작/중지
  Future<void> toggleVideoRecording() async {
    try {
      if (state.isRecordingVideo) {
        final path = await _cameraService.stopVideoRecording();
        state = state.copyWith(
          isRecordingVideo: false,
          capturedMediaPath: path,
        );
      } else {
        await _cameraService.startVideoRecording();
        state = state.copyWith(isRecordingVideo: true);
      }
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// 음성 메모 녹음 시작/중지
  Future<void> toggleAudioRecording() async {
    try {
      if (state.isRecordingAudio) {
        final path = await _audioService.stopRecording();
        state = state.copyWith(
          isRecordingAudio: false,
          audioPath: path,
          audioRecordingSeconds: 0,
        );
      } else {
        await _audioService.startRecording();
        state =
            state.copyWith(isRecordingAudio: true, audioRecordingSeconds: 0);
      }
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// 오디오 녹음 시간 업데이트
  void updateAudioDuration(int seconds) {
    state = state.copyWith(audioRecordingSeconds: seconds);
  }

  /// 미디어 초기화 (다시 촬영)
  void clearCapturedMedia() {
    state = state.copyWith(
      clearCapturedMediaPath: true,
      clearAudioPath: true,
      clearGeneratedEntry: true,
    );
  }

  /// 에러 지우기
  void clearError() {
    state = state.copyWith(error: null);
  }

  /// AI 처리: Vision 분석 -> 미디어/음성 업로드 -> Gemini(멀티모달 STT+일기) -> DB 저장
  Future<DiaryEntry?> processAndGenerate({
    required String childId,
    required int childAgeMonths,
    String? childName,
    String? childGender,
  }) async {
    state = state.copyWith(
      isProcessing: true,
      error: null,
      processingStep: ProcessingStep.analyzingFace,
      processingProgress: 0.0,
    );

    try {
      final user = SupabaseService.auth.currentUser;
      if (user == null) throw Exception('로그인이 필요합니다.');
      final userId = user.id;

      // 1. Vision 분석 (온디바이스 ML Kit)
      state = state.copyWith(
        processingStep: ProcessingStep.analyzingFace,
        processingProgress: 0.15,
      );
      Map<String, dynamic> visionData = {};
      final isPhotoCapture =
          state.mode == RecordingMode.photo && state.capturedMediaPath != null;
      final isVideoCapture =
          state.mode == RecordingMode.video && state.capturedMediaPath != null;
      if (isPhotoCapture) {
        final visionResult =
            await _visionService.analyzeImage(state.capturedMediaPath!);
        visionData = visionResult.toJson();

        try {
          final behaviorResult =
              await _yoloBehaviorService.analyzeImage(state.capturedMediaPath!);
          visionData['baby_behavior'] = behaviorResult.toJson();
        } catch (e, st) {
          debugPrint('[YOLO] behavior analysis failed: $e');
          debugPrint('$st');
          visionData['baby_behavior_error'] = e.toString();
        }
      } else if (isVideoCapture) {
        try {
          final videoBehaviorResult = await _yoloVideoBehaviorService
              .analyzeVideo(state.capturedMediaPath!);
          visionData['video_behavior'] = videoBehaviorResult.toJson();
        } catch (e, st) {
          debugPrint('[YOLO Video] behavior analysis failed: $e');
          debugPrint('$st');
          visionData['video_behavior_error'] = e.toString();
        }
      }

      // 2. 미디어 업로드 (Supabase Storage)
      state = state.copyWith(
        processingStep: ProcessingStep.uploadingMedia,
        processingProgress: 0.3,
      );
      final List<String> mediaUrls = [];
      if (state.capturedMediaPath != null) {
        final mediaUrl = await _storageService.uploadMedia(
          state.capturedMediaPath!,
          userId,
        );
        mediaUrls.add(mediaUrl);
      }
      String? audioUrl;
      if (state.audioPath != null) {
        audioUrl = await _storageService.uploadAudio(
          state.audioPath!,
          userId,
        );
      }

      // 3. AI 일기 작성 — 음성 메모가 있을 때만 STT 단계를 표시한다.
      final hasAudioMemo = state.audioPath != null;
      if (hasAudioMemo) {
        state = state.copyWith(
          processingStep: ProcessingStep.convertingSpeech,
          processingProgress: 0.5,
        );
      }
      // 누적 흐름을 위해 최근 일기 3개의 최종 텍스트를 발췌(각 120자)
      List<String> recentExcerpts = const [];
      try {
        final recents = await _diaryRepository.getDiaryEntriesPaged(
          childId,
          offset: 0,
          limit: 3,
        );
        recentExcerpts = recents
            .map((e) => (e.finalText ?? e.llmDraft ?? '').trim())
            .where((s) => s.isNotEmpty)
            .map((s) => s.length > 120 ? '${s.substring(0, 120)}…' : s)
            .toList();
      } catch (_) {
        // 컨텍스트 조회 실패는 무시하고 빈 리스트로 진행
      }

      state = state.copyWith(
        processingStep: ProcessingStep.writingDiary,
        processingProgress: hasAudioMemo ? 0.7 : 0.55,
      );
      // 사진 모드일 때만 이미지를 직접 전달(동영상은 제외)
      final imagePath =
          (state.mode == RecordingMode.photo) ? state.capturedMediaPath : null;
      final geminiResult = await _geminiService.generateDiary(
        visionData: visionData,
        childAgeMonths: childAgeMonths,
        audioPath: state.audioPath,
        imagePath: imagePath,
        childName: childName,
        childGender: childGender,
        recentDiaryExcerpts: recentExcerpts,
      );
      final sttTranscript = geminiResult.sttTranscript;

      // 5. DB 저장 (Supabase diary_entries 테이블)
      state = state.copyWith(
        processingStep: ProcessingStep.saving,
        processingProgress: 0.9,
      );
      final now = DateTime.now();
      final entry = await _diaryRepository.createDiaryEntry({
        'id': const Uuid().v4(),
        'user_id': userId,
        'child_id': childId,
        'recorded_at': now.toIso8601String(),
        'vision_data': visionData,
        'stt_transcript': sttTranscript,
        'llm_draft': geminiResult.diaryDraft,
        'final_text': geminiResult.diaryDraft,
        'media_urls': mediaUrls,
        'audio_url': audioUrl,
        'emotion_summary': visionData['emotion'] as String? ?? 'neutral',
        'milestone_detected': geminiResult.milestoneDetected,
        'development_report': geminiResult.developmentReport,
        'parenting_tips': geminiResult.parentingTips,
      });

      // 일기 생성 후 관련 provider 새로고침 (timeline / home 즉시 반영)
      _ref.invalidate(diaryListProvider(childId));
      _ref.invalidate(currentChildDiaryListProvider);

      state = state.copyWith(
        isProcessing: false,
        processingStep: ProcessingStep.complete,
        processingProgress: 1.0,
        generatedEntry: entry,
      );
      return entry;
    } catch (e, st) {
      debugPrint('[Diary] processAndGenerate FAILED: $e');
      debugPrint('$st');
      state = state.copyWith(
        isProcessing: false,
        processingStep: ProcessingStep.none,
        processingProgress: 0.0,
        error: e.toString(),
      );
      return null;
    }
  }

  @override
  void dispose() {
    _cameraService.dispose();
    _audioService.dispose();
    _visionService.dispose();
    _yoloBehaviorService.dispose();
    super.dispose();
  }
}

final recordControllerProvider =
    StateNotifierProvider<RecordController, RecordState>((ref) {
  final controller = RecordController(
    ref,
    ref.watch(cameraServiceProvider),
    ref.watch(audioServiceProvider),
    ref.watch(visionServiceProvider),
    ref.watch(yoloBehaviorServiceProvider),
    ref.watch(yoloVideoBehaviorServiceProvider),
    ref.watch(storageServiceProvider),
    ref.watch(geminiServiceProvider),
    ref.watch(diaryRepositoryProvider),
  );
  ref.onDispose(() => controller.dispose());
  return controller;
});
