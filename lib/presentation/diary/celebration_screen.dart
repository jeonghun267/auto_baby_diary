import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

class CelebrationScreen extends StatefulWidget {
  final String diaryId;
  final String diaryText;
  final String emotionSummary;

  const CelebrationScreen({
    super.key,
    required this.diaryId,
    required this.diaryText,
    required this.emotionSummary,
  });

  @override
  State<CelebrationScreen> createState() => _CelebrationScreenState();
}

class _CelebrationScreenState extends State<CelebrationScreen>
    with TickerProviderStateMixin {
  late AnimationController _bounceController;
  late AnimationController _confettiController;
  late AnimationController _fadeInController;
  late Animation<double> _bounceAnimation;
  late Animation<double> _fadeInAnimation;

  late List<_ConfettiParticle> _particles;

  @override
  void initState() {
    super.initState();

    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _bounceAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.3), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 0.9), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 0.9, end: 1.1), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.1, end: 1.0), weight: 20),
    ]).animate(CurvedAnimation(
      parent: _bounceController,
      curve: Curves.easeOut,
    ));

    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );

    _fadeInController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeInAnimation = CurvedAnimation(
      parent: _fadeInController,
      curve: Curves.easeOut,
    );

    // Generate confetti particles
    final rng = math.Random();
    _particles = List.generate(60, (_) {
      return _ConfettiParticle(
        x: rng.nextDouble(),
        speed: 0.3 + rng.nextDouble() * 0.7,
        size: 4.0 + rng.nextDouble() * 6.0,
        color: [
          AppColors.primary,
          AppColors.primaryLight,
          AppColors.secondary,
          AppColors.emotionHappy,
          AppColors.emotionSurprised,
          AppColors.success,
        ][rng.nextInt(6)],
        drift: (rng.nextDouble() - 0.5) * 0.3,
      );
    });

    // Start animations
    _bounceController.forward();
    _confettiController.repeat();
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _fadeInController.forward();
    });
  }

  @override
  void dispose() {
    _bounceController.dispose();
    _confettiController.dispose();
    _fadeInController.dispose();
    super.dispose();
  }

  String get _previewText {
    if (widget.diaryText.length <= 100) return widget.diaryText;
    return '${widget.diaryText.substring(0, 100)}...';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Confetti layer
          AnimatedBuilder(
            animation: _confettiController,
            builder: (context, child) {
              return CustomPaint(
                size: MediaQuery.of(context).size,
                painter: _ConfettiPainter(
                  particles: _particles,
                  progress: _confettiController.value,
                ),
              );
            },
          ),

          // Main content
          SafeArea(
            child: Column(
              children: [
                // Close button
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: IconButton(
                      onPressed: () => context.go('/diary/${widget.diaryId}'),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: AppColors.textSecondary,
                        size: 28,
                      ),
                    ),
                  ),
                ),

                const Spacer(),

                // Bouncing emoji
                AnimatedBuilder(
                  animation: _bounceAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _bounceAnimation.value,
                      child: const Text(
                        '\u{1F389}',
                        style: TextStyle(fontSize: 80),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),

                // Title
                FadeTransition(
                  opacity: _fadeInAnimation,
                  child: const Text(
                    '일기가 완성되었어요!',
                    style: AppTextStyles.h1,
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 8),

                FadeTransition(
                  opacity: _fadeInAnimation,
                  child: Text(
                    _emotionText,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 32),

                // Diary preview card
                FadeTransition(
                  opacity: _fadeInAnimation,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Text(
                        _previewText,
                        style: AppTextStyles.diaryText,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),

                const Spacer(),

                // Buttons
                FadeTransition(
                  opacity: _fadeInAnimation,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      children: [
                        // Share button
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              SharePlus.instance.share(
                                ShareParams(text: widget.diaryText),
                              );
                            },
                            icon: const Icon(Icons.share_rounded),
                            label: const Text('공유하기'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: const BorderSide(color: AppColors.primary),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // View diary button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              context.go('/diary/${widget.diaryId}');
                            },
                            icon: const Icon(Icons.menu_book_rounded),
                            label: const Text(
                              '일기 보기',
                              style: AppTextStyles.buttonText,
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String get _emotionText {
    switch (widget.emotionSummary) {
      case 'happy':
        return '오늘 아이가 행복한 하루를 보냈네요!';
      case 'crying':
        return '오늘은 힘든 하루였군요. 수고했어요!';
      case 'surprised':
        return '오늘 특별한 순간이 있었네요!';
      default:
        return 'AI가 오늘의 소중한 순간을 기록했어요';
    }
  }
}

// ─── Confetti Particle ─────────────────────────────────

class _ConfettiParticle {
  final double x;
  final double speed;
  final double size;
  final Color color;
  final double drift;

  _ConfettiParticle({
    required this.x,
    required this.speed,
    required this.size,
    required this.color,
    required this.drift,
  });
}

// ─── Confetti Painter ──────────────────────────────────

class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiParticle> particles;
  final double progress;

  _ConfettiPainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final y = (progress * p.speed * 1.5) % 1.2;
      final opacity = y < 0.1 ? y / 0.1 : (y > 1.0 ? (1.2 - y) / 0.2 : 1.0);
      if (opacity <= 0) continue;

      final paint = Paint()
        ..color = p.color.withValues(alpha: opacity.clamp(0.0, 0.8))
        ..style = PaintingStyle.fill;

      final dx = p.x * size.width +
          math.sin(progress * math.pi * 4 + p.x * 10) * 20 +
          p.drift * size.width * progress;
      final dy = y * size.height;

      canvas.drawCircle(Offset(dx, dy), p.size / 2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) => true;
}
