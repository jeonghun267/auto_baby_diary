import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/camera_service.dart';
import 'camera_preview_widget.dart';
import 'record_controller.dart';

class QuickRecordScreen extends ConsumerStatefulWidget {
  const QuickRecordScreen({super.key});

  @override
  ConsumerState<QuickRecordScreen> createState() => _QuickRecordScreenState();
}

class _QuickRecordScreenState extends ConsumerState<QuickRecordScreen>
    with TickerProviderStateMixin {
  int _countdown = 0;
  bool _isCountingDown = false;
  bool _hasCaptured = false;
  Timer? _countdownTimer;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(recordControllerProvider.notifier).initCamera();
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _onCaptureTapped() async {
    if (_hasCaptured || _isCountingDown) return;

    final controller = ref.read(recordControllerProvider.notifier);

    // Take photo
    await controller.takePhoto();

    setState(() {
      _hasCaptured = true;
      _isCountingDown = true;
      _countdown = 5;
    });

    // Start audio recording
    await controller.toggleAudioRecording();

    // Start countdown pulse
    _pulseController.repeat(reverse: true);

    // Start countdown timer
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _countdown--;
      });

      controller.updateAudioDuration(5 - _countdown);

      if (_countdown <= 0) {
        timer.cancel();
        _onCountdownComplete();
      }
    });
  }

  Future<void> _onCountdownComplete() async {
    if (!mounted) return;

    _pulseController.stop();
    _pulseController.reset();

    setState(() {
      _isCountingDown = false;
    });

    final controller = ref.read(recordControllerProvider.notifier);

    // Stop audio recording
    await controller.toggleAudioRecording();

    // Start AI processing
    final currentChild = ref.read(currentChildProvider);
    if (currentChild == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('먼저 아이 프로필을 등록해주세요.')),
        );
        context.go('/home');
      }
      return;
    }

    final entry = await controller.processAndGenerate(
      childId: currentChild.id,
      childAgeMonths: currentChild.ageInMonths,
      childName: currentChild.name,
      childGender: currentChild.gender,
    );

    if (!mounted) return;

    if (entry != null) {
      context.push('/celebration', extra: {
        'diaryId': entry.id,
        'diaryText': entry.finalText ?? entry.llmDraft ?? '',
        'emotionSummary': entry.emotionSummary ?? 'neutral',
      });
    } else {
      // AI 처리 실패: 사용자에게 명확히 알리고 재시도/돌아가기 제공
      final retry = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          final state = ref.read(recordControllerProvider);
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text('일기 생성 실패'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    state.userFriendlyError.isNotEmpty
                        ? state.userFriendlyError
                        : '일시적인 오류가 발생했어요.\n다시 시도해주세요.',
                  ),
                  if (state.error != null && state.error!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text(
                      '오류 상세',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      state.error!,
                      style: const TextStyle(fontSize: 11, height: 1.3),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('돌아가기'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('다시 시도'),
              ),
            ],
          );
        },
      );

      if (!mounted) return;
      if (retry == true) {
        // 다시 카메라 화면으로 돌리기 (캡처 상태 초기화)
        controller.clearCapturedMedia();
        controller.clearError();
        setState(() {
          _hasCaptured = false;
          _isCountingDown = false;
        });
      } else {
        context.go('/home');
      }
    }
  }

  void _onCancel() {
    _countdownTimer?.cancel();
    final state = ref.read(recordControllerProvider);
    final controller = ref.read(recordControllerProvider.notifier);

    // Stop audio if recording
    if (state.isRecordingAudio) {
      controller.toggleAudioRecording();
    }

    controller.clearCapturedMedia();
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(recordControllerProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: Stack(
        children: [
          // Camera preview (full screen)
          Column(
            children: [
              Expanded(
                child: CameraPreviewWidget(
                  controller: ref.read(cameraServiceProvider).controller,
                  isSwitching: state.isSwitchingCamera,
                  showFaceGuide: !_hasCaptured,
                ),
              ),
            ],
          ),

          // Cancel button (top-left)
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            child: IconButton(
              onPressed: state.isProcessing ? null : _onCancel,
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ),

          // Countdown overlay
          if (_isCountingDown)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 0,
              right: 0,
              child: Center(
                child: AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _pulseAnimation.value,
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.85),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.error.withValues(alpha: 0.4),
                              blurRadius: 20,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            '$_countdown',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

          // Recording indicator text
          if (_isCountingDown)
            Positioned(
              top: MediaQuery.of(context).padding.top + 88,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.error,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        '음성 녹음 중...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Capture button (bottom center) - only before capture
          if (!_hasCaptured)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 40,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: state.isCameraReady ? _onCaptureTapped : null,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.3),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Container(
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                        margin: const EdgeInsets.all(2),
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Quick mode hint
          if (!_hasCaptured && !state.isProcessing)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 132,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    '탭하면 사진 촬영 + 5초 음성 녹음',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),

          // Processing overlay
          if (state.isProcessing) _buildProcessingOverlay(state),
        ],
      ),
    );
  }

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
                // Emoji icon
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

                // Step label
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

                // Step indicators
                _buildStepIndicators(state),
                const SizedBox(height: 20),

                // Progress bar
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
}
