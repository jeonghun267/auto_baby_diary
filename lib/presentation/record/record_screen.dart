import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/camera_service.dart';
import 'camera_preview_widget.dart';
import 'record_controller.dart';
import 'voice_memo_widget.dart';

class RecordScreen extends ConsumerStatefulWidget {
  const RecordScreen({super.key});

  @override
  ConsumerState<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends ConsumerState<RecordScreen>
    with TickerProviderStateMixin {
  late AnimationController _shutterController;
  late AnimationController _modeSlideController;
  late AnimationController _sparkleController;
  late AnimationController _recordPulseController;
  late AnimationController _flipController;
  late Animation<double> _shutterAnimation;
  late Animation<double> _sparkleAnimation;
  late Animation<double> _recordPulseAnimation;
  Timer? _audioTimer;

  @override
  void initState() {
    super.initState();

    _shutterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _shutterAnimation = Tween<double>(begin: 1.0, end: 0.85).animate(
      CurvedAnimation(parent: _shutterController, curve: Curves.easeInOut),
    );

    _modeSlideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _sparkleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _sparkleAnimation = CurvedAnimation(
      parent: _sparkleController,
      curve: Curves.easeInOut,
    );

    _recordPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _recordPulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _recordPulseController, curve: Curves.easeInOut),
    );

    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(recordControllerProvider.notifier).initCamera();
    });
  }

  @override
  void dispose() {
    _shutterController.dispose();
    _modeSlideController.dispose();
    _sparkleController.dispose();
    _recordPulseController.dispose();
    _flipController.dispose();
    _audioTimer?.cancel();
    super.dispose();
  }

  void _startAudioTimer() {
    _audioTimer?.cancel();
    _audioTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      ref
          .read(recordControllerProvider.notifier)
          .updateAudioDuration(timer.tick);
    });
  }

  void _stopAudioTimer() {
    _audioTimer?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(recordControllerProvider);
    final controller = ref.read(recordControllerProvider.notifier);

    // 녹화 중 펄스 제어
    if (state.isRecordingVideo && !_recordPulseController.isAnimating) {
      _recordPulseController.repeat(reverse: true);
    } else if (!state.isRecordingVideo && _recordPulseController.isAnimating) {
      _recordPulseController.stop();
      _recordPulseController.reset();
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: Stack(
        children: [
          // 카메라 프리뷰 (화면 전체)
          Column(
            children: [
              // 상단 바
              _buildTopBar(state, controller),

              // 카메라 영역
              Expanded(
                child: CameraPreviewWidget(
                  controller: ref.read(cameraServiceProvider).controller,
                  isSwitching: state.isSwitchingCamera,
                ),
              ),

              // 하단 컨트롤 패널 (글래스모피즘)
              _buildBottomPanel(state, controller),
            ],
          ),

          // 음성 메모 위젯
          Positioned(
            right: 16,
            bottom: 200,
            child: VoiceMemoWidget(
              isRecording: state.isRecordingAudio,
              recordingSeconds: state.audioRecordingSeconds,
              onToggle: () {
                controller.toggleAudioRecording();
                if (!state.isRecordingAudio) {
                  _startAudioTimer();
                } else {
                  _stopAudioTimer();
                }
              },
            ),
          ),

          // 캡처된 미디어 썸네일
          if (state.capturedMediaPath != null)
            Positioned(
              left: 16,
              bottom: 200,
              child: _buildMediaThumbnail(state.capturedMediaPath!),
            ),

          // AI 처리 프로그레스 오버레이
          if (state.isProcessing) _buildProcessingOverlay(state),

          // 에러 메시지 (사용자 친화적)
          if (state.error != null)
            Positioned(
              bottom: 210,
              left: 24,
              right: 24,
              child: _buildErrorBanner(state, controller),
            ),
        ],
      ),
    );
  }

  // ── 상단 바 ──
  Widget _buildTopBar(RecordState state, RecordController controller) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            // 닫기 버튼
            IconButton(
              onPressed: () => context.go('/home'),
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
            const Spacer(),

            // 녹화 중 인디케이터
            if (state.isRecordingVideo) _buildRecordingIndicator(),

            const Spacer(),

            // 카메라 전환 버튼
            IconButton(
              onPressed: () {
                _flipController.forward(from: 0.0);
                controller.switchCamera();
              },
              icon: AnimatedBuilder(
                animation: _flipController,
                builder: (context, child) {
                  return Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.001)
                      ..rotateY(_flipController.value * math.pi),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.3),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.flip_camera_ios_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 녹화 중 인디케이터 (빨간 점 펄스) ──
  Widget _buildRecordingIndicator() {
    return AnimatedBuilder(
      animation: _recordPulseAnimation,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Transform.scale(
                scale: _recordPulseAnimation.value,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'REC',
                style: TextStyle(
                  color: AppColors.error,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── 하단 컨트롤 패널 (글래스모피즘) ──
  Widget _buildBottomPanel(RecordState state, RecordController controller) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.only(
            top: 20,
            bottom: MediaQuery.of(context).padding.bottom + 16,
            left: 24,
            right: 24,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.2),
                Colors.black.withValues(alpha: 0.5),
              ],
            ),
            border: Border(
              top: BorderSide(
                color: Colors.white.withValues(alpha: 0.1),
                width: 0.5,
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 모드 전환 탭 (사진/동영상) with 슬라이드 인디케이터
              _buildModeSelector(state, controller),
              const SizedBox(height: 24),

              // 메인 컨트롤 Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // 좌측: 음성 메모 인디케이터 or 미디어 상태
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: state.audioPath != null
                        ? Container(
                            decoration: BoxDecoration(
                              color: AppColors.secondary.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color:
                                    AppColors.secondary.withValues(alpha: 0.5),
                              ),
                            ),
                            child: const Icon(
                              Icons.mic_rounded,
                              color: AppColors.secondary,
                              size: 22,
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),

                  // 메인 촬영 버튼
                  _buildMainShutterButton(state, controller),

                  // 우측: AI 일기 생성 버튼
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: state.capturedMediaPath != null
                        ? _buildAIGenerateButton(state, controller)
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 모드 선택 (사진/동영상) ──
  Widget _buildModeSelector(RecordState state, RecordController controller) {
    final isPhoto = state.mode == RecordingMode.photo;

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity != null) {
          if (details.primaryVelocity! > 0 && !isPhoto) {
            controller.toggleMode();
          } else if (details.primaryVelocity! < 0 && isPhoto) {
            controller.toggleMode();
          }
        }
      },
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildModeTab('사진', isPhoto, () {
              if (!isPhoto) controller.toggleMode();
            }),
            _buildModeTab('동영상', !isPhoto, () {
              if (isPhoto) controller.toggleMode();
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildModeTab(String label, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primary.withValues(alpha: 0.9)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color:
                isActive ? Colors.white : Colors.white.withValues(alpha: 0.5),
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            fontSize: 14,
            letterSpacing: -0.3,
          ),
        ),
      ),
    );
  }

  // ── 메인 셔터 버튼 ──
  Widget _buildMainShutterButton(
      RecordState state, RecordController controller) {
    final isVideo = state.mode == RecordingMode.video;
    final isRecording = state.isRecordingVideo;

    return GestureDetector(
      onTapDown: (_) => _shutterController.forward(),
      onTapUp: (_) {
        _shutterController.reverse();
        if (isVideo) {
          controller.toggleVideoRecording();
        } else {
          controller.takePhoto();
        }
      },
      onTapCancel: () => _shutterController.reverse(),
      child: AnimatedBuilder(
        animation: _shutterAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _shutterAnimation.value,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: 4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isRecording ? AppColors.error : Colors.white)
                        .withValues(alpha: 0.3),
                    blurRadius: 20,
                    spreadRadius: isRecording ? 4 : 0,
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    shape: isRecording ? BoxShape.rectangle : BoxShape.circle,
                    borderRadius: isRecording ? BorderRadius.circular(8) : null,
                    color: isVideo
                        ? AppColors.error
                        : Colors.white.withValues(alpha: 0.9),
                  ),
                  margin: EdgeInsets.all(isRecording ? 14 : 2),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── AI 일기 생성 버튼 (스파클 애니메이션) ──
  Widget _buildAIGenerateButton(
      RecordState state, RecordController controller) {
    return GestureDetector(
      onTap: () async {
        final currentChild = ref.read(currentChildProvider);
        if (currentChild == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('먼저 아이 프로필을 등록해주세요.')),
          );
          return;
        }
        final entry = await controller.processAndGenerate(
          childId: currentChild.id,
          childAgeMonths: currentChild.ageInMonths,
          childName: currentChild.name,
          childGender: currentChild.gender,
        );
        if (entry != null && mounted) {
          context.push('/celebration', extra: {
            'diaryId': entry.id,
            'diaryText': entry.finalText ?? entry.llmDraft ?? '',
            'emotionSummary': entry.emotionSummary ?? 'neutral',
          });
        }
      },
      child: AnimatedBuilder(
        animation: _sparkleAnimation,
        builder: (context, child) {
          return Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary,
                  AppColors.primary.withValues(alpha: 0.8),
                  Color.lerp(AppColors.primary, AppColors.emotionHappy,
                      _sparkleAnimation.value * 0.3)!,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(
                    alpha: 0.3 + _sparkleAnimation.value * 0.3,
                  ),
                  blurRadius: 12 + _sparkleAnimation.value * 8,
                  spreadRadius: _sparkleAnimation.value * 2,
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(
                  Icons.auto_awesome,
                  color: Colors.white,
                  size: 22,
                ),
                // 작은 스파클 파티클들
                ..._buildSparkleParticles(_sparkleAnimation.value),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildSparkleParticles(double progress) {
    return List.generate(4, (i) {
      final angle = (i * math.pi / 2) + progress * math.pi * 2;
      final radius = 18.0 + math.sin(progress * math.pi * 2 + i) * 4;
      return Positioned(
        left: 24 + math.cos(angle) * radius - 2,
        top: 24 + math.sin(angle) * radius - 2,
        child: Container(
          width: 4,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.white.withValues(
              alpha: (math.sin(progress * math.pi * 2 + i * 1.5) * 0.5 + 0.5)
                  .clamp(0.0, 0.8),
            ),
            shape: BoxShape.circle,
          ),
        ),
      );
    });
  }

  // ── 캡처된 미디어 썸네일 ──
  Widget _buildMediaThumbnail(String path) {
    return GestureDetector(
      onTap: () {
        ref.read(recordControllerProvider.notifier).clearCapturedMedia();
      },
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 400),
        curve: Curves.elasticOut,
        builder: (context, value, child) {
          return Transform.scale(
            scale: value,
            child: child,
          );
        },
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.file(
                  File(path),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: Colors.grey[800],
                    child: const Icon(Icons.image, color: Colors.white54),
                  ),
                ),
                // 다시 찍기 오버레이
                Container(
                  color: Colors.black.withValues(alpha: 0.3),
                  child: const Icon(
                    Icons.refresh_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── AI 처리 프로그레스 오버레이 ──
  Widget _buildProcessingOverlay(RecordState state) {
    return Container(
      color: Colors.black.withValues(alpha: 0.7),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 40),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  blurRadius: 40,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 이모지 아이콘
                TweenAnimationBuilder<double>(
                  key: ValueKey(state.processingStep),
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.elasticOut,
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: Text(
                        state.processingStepEmoji,
                        style: const TextStyle(fontSize: 48),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),

                // 단계 레이블
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    state.processingStepLabel,
                    key: ValueKey(state.processingStep),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // 단계 인디케이터 dots
                _buildStepIndicators(state),
                const SizedBox(height: 20),

                // 프로그레스 바
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(
                      begin: 0.0,
                      end: state.processingProgress,
                    ),
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) {
                      return LinearProgressIndicator(
                        value: value,
                        minHeight: 6,
                        backgroundColor:
                            AppColors.primaryLight.withValues(alpha: 0.2),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.primary,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicators(RecordState state) {
    final steps = [
      ProcessingStep.analyzingFace,
      ProcessingStep.uploadingMedia,
      ProcessingStep.convertingSpeech,
      ProcessingStep.writingDiary,
      ProcessingStep.saving,
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: steps.map((step) {
        final isActive = state.processingStep == step;
        final isCompleted = state.processingStepIndex > step.index;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isCompleted
                ? AppColors.primary
                : isActive
                    ? AppColors.primary
                    : AppColors.primaryLight.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }).toList(),
    );
  }

  // ── 에러 배너 (사용자 친화적) ──
  Widget _buildErrorBanner(RecordState state, RecordController controller) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.error.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: AppColors.error,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                state.userFriendlyError,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),
            IconButton(
              onPressed: () => controller.clearError(),
              icon: Icon(
                Icons.close_rounded,
                color: AppColors.textHint,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
