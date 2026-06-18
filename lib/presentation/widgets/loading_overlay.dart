import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// AI 처리 중 로딩 오버레이 위젯
/// - 다단계 진행 표시기 (단계별 라벨)
/// - 아기 테마 바운싱 도트 애니메이션
/// - 한국어 단계 설명
class LoadingOverlay extends StatefulWidget {
  final int currentStep;
  final int totalSteps;
  final String? customMessage;

  const LoadingOverlay({
    super.key,
    this.currentStep = 0,
    this.totalSteps = 3,
    this.customMessage,
  });

  static const List<LoadingStep> defaultSteps = [
    LoadingStep(
      label: '얼굴을 분석하고 있어요',
      icon: Icons.face,
      emoji: '👶',
    ),
    LoadingStep(
      label: '음성을 텍스트로 변환 중',
      icon: Icons.mic,
      emoji: '🎤',
    ),
    LoadingStep(
      label: 'AI가 일기를 쓰고 있어요',
      icon: Icons.auto_awesome,
      emoji: '✨',
    ),
  ];

  @override
  State<LoadingOverlay> createState() => _LoadingOverlayState();
}

class LoadingStep {
  final String label;
  final IconData icon;
  final String emoji;

  const LoadingStep({
    required this.label,
    required this.icon,
    required this.emoji,
  });
}

class _LoadingOverlayState extends State<LoadingOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _dotsController;
  late final AnimationController _fadeController;

  @override
  void initState() {
    super.initState();

    _dotsController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    )..forward();
  }

  @override
  void dispose() {
    _dotsController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // AI 처리 중 시스템 뒤로가기 차단
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        // 사용자가 뒤로가기 시도하면 안내
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('잠시만요, 처리 중이에요...'),
            duration: Duration(seconds: 2),
          ),
        );
      },
      child: FadeTransition(
        opacity: _fadeController,
        child: Container(
          color: Colors.black.withValues(alpha: 0.5),
          child: Center(
            child: Card(
              margin: const EdgeInsets.all(32),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              elevation: 8,
              shadowColor: AppColors.primary.withValues(alpha: 0.3),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 바운싱 도트 애니메이션
                    _buildBouncingDots(),
                    const SizedBox(height: 28),

                    // 현재 단계 메시지
                    _buildCurrentStepMessage(),
                    const SizedBox(height: 24),

                    // 단계 진행 표시기
                    _buildStepIndicator(),
                    const SizedBox(height: 20),

                    // 진행 바
                    _buildProgressBar(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBouncingDots() {
    return SizedBox(
      height: 50,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(4, (index) {
          return AnimatedBuilder(
            animation: _dotsController,
            builder: (context, child) {
              final delay = index * 0.2;
              final animValue = (_dotsController.value - delay) % 1.0;
              final bounce =
                  animValue < 0.5 ? animValue * 2 : (1 - animValue) * 2;
              final offset = -12 * Curves.easeInOut.transform(bounce);

              return Transform.translate(
                offset: Offset(0, offset),
                child: child,
              );
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                _getDotEmoji(index),
                style: const TextStyle(fontSize: 28),
              ),
            ),
          );
        }),
      ),
    );
  }

  String _getDotEmoji(int index) {
    const emojis = ['👶', '🍼', '🧸', '💤'];
    return emojis[index % emojis.length];
  }

  Widget _buildCurrentStepMessage() {
    final steps = LoadingOverlay.defaultSteps;
    final currentLabel = widget.customMessage ??
        (widget.currentStep < steps.length
            ? steps[widget.currentStep].label
            : steps.last.label);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.3),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: Text(
        currentLabel,
        key: ValueKey(currentLabel),
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 17,
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
          height: 1.4,
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    final steps = LoadingOverlay.defaultSteps;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(steps.length, (index) {
        final isCompleted = index < widget.currentStep;
        final isCurrent = index == widget.currentStep;

        return Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
              width: isCurrent ? 36 : 28,
              height: isCurrent ? 36 : 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCompleted
                    ? AppColors.success
                    : isCurrent
                        ? AppColors.primary
                        : AppColors.textHint.withValues(alpha: 0.3),
                boxShadow: isCurrent
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.4),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: isCompleted
                    ? const Icon(Icons.check, color: Colors.white, size: 16)
                    : Text(
                        steps[index].emoji,
                        style: TextStyle(fontSize: isCurrent ? 16 : 12),
                      ),
              ),
            ),
            if (index < steps.length - 1)
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                width: 32,
                height: 2,
                color: index < widget.currentStep
                    ? AppColors.success
                    : AppColors.textHint.withValues(alpha: 0.2),
              ),
          ],
        );
      }),
    );
  }

  Widget _buildProgressBar() {
    final progress = widget.totalSteps > 0
        ? (widget.currentStep / widget.totalSteps).clamp(0.0, 1.0)
        : 0.0;

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 6,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeInOut,
              builder: (context, value, _) {
                return LinearProgressIndicator(
                  value: value,
                  backgroundColor:
                      AppColors.primaryLight.withValues(alpha: 0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${widget.currentStep}/${widget.totalSteps} 단계',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textHint,
          ),
        ),
      ],
    );
  }
}
