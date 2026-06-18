import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// 감지된 감정을 배지 형태로 표시하는 위젯
/// - 애니메이션 입장 (스케일 + 페이드)
/// - 감정에 맞는 그라데이션 배경
/// - 활성 감정 펄스 애니메이션
class EmotionBadgeWidget extends StatefulWidget {
  final String emotion;
  final double? confidence;
  final bool isActive;
  final bool animate;
  final VoidCallback? onTap;

  const EmotionBadgeWidget({
    super.key,
    required this.emotion,
    this.confidence,
    this.isActive = false,
    this.animate = true,
    this.onTap,
  });

  @override
  State<EmotionBadgeWidget> createState() => _EmotionBadgeWidgetState();
}

class _EmotionBadgeWidgetState extends State<EmotionBadgeWidget>
    with TickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    // 입장 애니메이션
    _entranceController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.elasticOut,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeIn,
    );

    // 펄스 애니메이션 (활성 감정용)
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (widget.animate) {
      _entranceController.forward();
    } else {
      _entranceController.value = 1.0;
    }

    if (widget.isActive) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(EmotionBadgeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.isActive && oldWidget.isActive) {
      _pulseController.stop();
      _pulseController.value = 0.0;
    }
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = _getEmotionColor();
    final gradientColors = _getGradientColors();

    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: widget.isActive ? _pulseAnimation.value : 1.0,
              child: child,
            );
          },
          child: GestureDetector(
            onTap: widget.onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: color.withValues(alpha: 0.4),
                  width: widget.isActive ? 2.0 : 1.5,
                ),
                boxShadow: widget.isActive
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.3),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: color.withValues(alpha: 0.15),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _getEmotionEmoji(),
                    style: const TextStyle(fontSize: 18),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _getEmotionLabel(),
                    style: TextStyle(
                      color: _getTextColor(),
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  if (widget.confidence != null) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${(widget.confidence! * 100).toInt()}%',
                        style: TextStyle(
                          color: _getTextColor().withValues(alpha: 0.8),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _getEmotionColor() {
    switch (widget.emotion) {
      case 'happy':
        return AppColors.emotionHappy;
      case 'crying':
        return AppColors.emotionCrying;
      case 'surprised':
        return AppColors.emotionSurprised;
      case 'sleeping':
        return AppColors.emotionSleeping;
      default:
        return AppColors.emotionNeutral;
    }
  }

  List<Color> _getGradientColors() {
    switch (widget.emotion) {
      case 'happy':
        return [
          AppColors.emotionHappy.withValues(alpha: 0.2),
          AppColors.emotionHappy.withValues(alpha: 0.1),
        ];
      case 'crying':
        return [
          AppColors.emotionCrying.withValues(alpha: 0.2),
          AppColors.emotionCrying.withValues(alpha: 0.1),
        ];
      case 'surprised':
        return [
          AppColors.emotionSurprised.withValues(alpha: 0.2),
          AppColors.emotionSurprised.withValues(alpha: 0.1),
        ];
      case 'sleeping':
        return [
          AppColors.emotionSleeping.withValues(alpha: 0.2),
          AppColors.emotionSleeping.withValues(alpha: 0.1),
        ];
      default:
        return [
          AppColors.emotionNeutral.withValues(alpha: 0.2),
          AppColors.emotionNeutral.withValues(alpha: 0.1),
        ];
    }
  }

  Color _getTextColor() {
    switch (widget.emotion) {
      case 'happy':
        return const Color(0xFF8B6914);
      case 'crying':
        return const Color(0xFF2E6B8A);
      case 'surprised':
        return const Color(0xFF9B5A1A);
      case 'sleeping':
        return const Color(0xFF5B4E8C);
      default:
        return const Color(0xFF4A7C5C);
    }
  }

  String _getEmotionEmoji() {
    switch (widget.emotion) {
      case 'happy':
        return '😊';
      case 'crying':
        return '😢';
      case 'surprised':
        return '😮';
      case 'sleeping':
        return '😴';
      default:
        return '😐';
    }
  }

  String _getEmotionLabel() {
    switch (widget.emotion) {
      case 'happy':
        return '행복';
      case 'crying':
        return '울음';
      case 'surprised':
        return '놀람';
      case 'sleeping':
        return '잠';
      default:
        return '평온';
    }
  }
}
