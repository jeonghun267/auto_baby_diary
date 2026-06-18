import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// 음성 메모 녹음 위젯 - 애니메이션 웨이브폼 + 타이머 + 부드러운 확장/축소
class VoiceMemoWidget extends StatefulWidget {
  final bool isRecording;
  final VoidCallback onToggle;
  final int recordingSeconds;

  const VoiceMemoWidget({
    super.key,
    required this.isRecording,
    required this.onToggle,
    this.recordingSeconds = 0,
  });

  @override
  State<VoiceMemoWidget> createState() => _VoiceMemoWidgetState();
}

class _VoiceMemoWidgetState extends State<VoiceMemoWidget>
    with TickerProviderStateMixin {
  late AnimationController _expandController;
  late AnimationController _pulseController;
  late AnimationController _waveController;
  late Animation<double> _expandAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _expandController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeOutCubic,
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    if (widget.isRecording) {
      _expandController.forward();
      _pulseController.repeat(reverse: true);
      _waveController.repeat();
    }
  }

  @override
  void didUpdateWidget(VoiceMemoWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRecording && !oldWidget.isRecording) {
      _expandController.forward();
      _pulseController.repeat(reverse: true);
      _waveController.repeat();
    } else if (!widget.isRecording && oldWidget.isRecording) {
      _expandController.reverse();
      _pulseController.stop();
      _pulseController.reset();
      _waveController.stop();
      _waveController.reset();
    }
  }

  @override
  void dispose() {
    _expandController.dispose();
    _pulseController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  String _formatDuration(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onToggle,
      child: AnimatedBuilder(
        animation: Listenable.merge([_expandAnimation, _pulseAnimation]),
        builder: (context, child) {
          return Transform.scale(
            scale: widget.isRecording ? _pulseAnimation.value : 1.0,
            child: Container(
              constraints: BoxConstraints(
                minWidth: 56,
                maxWidth: widget.isRecording ? 220 : 56,
              ),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
                padding: EdgeInsets.symmetric(
                  horizontal: widget.isRecording ? 16 : 0,
                  vertical: widget.isRecording ? 12 : 0,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: widget.isRecording
                        ? [
                            AppColors.error.withValues(alpha: 0.9),
                            AppColors.error.withValues(alpha: 0.7),
                          ]
                        : [
                            AppColors.secondary.withValues(alpha: 0.9),
                            AppColors.secondary.withValues(alpha: 0.7),
                          ],
                  ),
                  borderRadius: BorderRadius.circular(
                    widget.isRecording ? 28 : 28,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (widget.isRecording
                              ? AppColors.error
                              : AppColors.secondary)
                          .withValues(alpha: 0.4),
                      blurRadius: widget.isRecording ? 20 : 12,
                      offset: const Offset(0, 4),
                      spreadRadius: widget.isRecording ? 2 : 0,
                    ),
                  ],
                ),
                child: widget.isRecording
                    ? _buildExpandedContent()
                    : _buildCollapsedContent(),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCollapsedContent() {
    return Container(
      width: 56,
      height: 56,
      alignment: Alignment.center,
      child: const Icon(
        Icons.mic_rounded,
        color: Colors.white,
        size: 24,
      ),
    );
  }

  Widget _buildExpandedContent() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 녹음 중지 아이콘
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.25),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.stop_rounded,
            color: Colors.white,
            size: 18,
          ),
        ),
        const SizedBox(width: 10),

        // 웨이브폼 애니메이션
        SizedBox(
          width: 80,
          height: 28,
          child: AnimatedBuilder(
            animation: _waveController,
            builder: (context, child) {
              return CustomPaint(
                painter: _WaveformPainter(
                  progress: _waveController.value,
                  isActive: widget.isRecording,
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 10),

        // 타이머
        Text(
          _formatDuration(widget.recordingSeconds),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

/// 웨이브폼 페인터 - 녹음 중 애니메이션 바
class _WaveformPainter extends CustomPainter {
  final double progress;
  final bool isActive;
  static final math.Random _random = math.Random(42);
  static final List<double> _heights =
      List.generate(20, (_) => _random.nextDouble());

  _WaveformPainter({required this.progress, required this.isActive});

  @override
  void paint(Canvas canvas, Size size) {
    final barCount = 20;
    final barWidth = size.width / (barCount * 2);
    final maxHeight = size.height * 0.9;
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = barWidth;

    for (int i = 0; i < barCount; i++) {
      final x = (i * 2 + 1) * barWidth;
      final phase = (progress * 2 * math.pi) + (i * 0.4);
      final heightFactor =
          isActive ? (math.sin(phase) * 0.4 + 0.5) * _heights[i] + 0.15 : 0.15;
      final barHeight = maxHeight * heightFactor.clamp(0.1, 1.0);

      canvas.drawLine(
        Offset(x, (size.height + barHeight) / 2),
        Offset(x, (size.height - barHeight) / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter oldDelegate) =>
      progress != oldDelegate.progress || isActive != oldDelegate.isActive;
}
