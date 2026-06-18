import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// 카메라 실시간 프리뷰 위젯 (부드러운 초기화 애니메이션 + 얼굴 가이드 프레임)
class CameraPreviewWidget extends StatefulWidget {
  final CameraController? controller;
  final bool showFaceGuide;
  final bool isSwitching;

  const CameraPreviewWidget({
    super.key,
    this.controller,
    this.showFaceGuide = true,
    this.isSwitching = false,
  });

  @override
  State<CameraPreviewWidget> createState() => _CameraPreviewWidgetState();
}

class _CameraPreviewWidgetState extends State<CameraPreviewWidget>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _guideController;
  late AnimationController _breatheController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _guideOpacity;
  late Animation<double> _breatheAnimation;

  double _currentZoom = 1.0;
  double _baseZoom = 1.0;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );

    _guideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _guideOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _guideController, curve: Curves.easeIn),
    );

    _breatheController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _breatheAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _breatheController, curve: Curves.easeInOut),
    );

    _checkAndAnimate();
  }

  void _checkAndAnimate() {
    if (widget.controller != null && widget.controller!.value.isInitialized) {
      _fadeController.forward();
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) _guideController.forward();
      });
    }
  }

  @override
  void didUpdateWidget(CameraPreviewWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      _fadeController.reset();
      _guideController.reset();
      _checkAndAnimate();
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _guideController.dispose();
    _breatheController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(32),
        bottomRight: Radius.circular(32),
      ),
      child: Container(
        color: const Color(0xFF1A1A2E),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 카메라 프리뷰 또는 로딩 상태
            if (widget.controller != null &&
                widget.controller!.value.isInitialized &&
                !widget.isSwitching)
              FadeTransition(
                opacity: _fadeAnimation,
                child: GestureDetector(
                  onScaleStart: _onScaleStart,
                  onScaleUpdate: _onScaleUpdate,
                  // StackFit.expand가 CameraPreview를 박스에 강제로 늘려
                  // 비율이 찌그러지는 문제를 cover 방식으로 보정한다.
                  // 카메라를 원래 비율대로 그린 뒤 박스를 덮을 만큼만
                  // 확대하고, 넘치는 부분은 ClipRect로 잘라낸다.
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      var scale =
                          (constraints.maxWidth / constraints.maxHeight) *
                              widget.controller!.value.aspectRatio;
                      if (scale < 1) scale = 1 / scale;
                      return ClipRect(
                        child: Transform.scale(
                          scale: scale,
                          child: Center(
                            child: CameraPreview(widget.controller!),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              )
            else
              _buildLoadingState(),

            // 카메라 전환 중 오버레이
            if (widget.isSwitching) _buildSwitchingOverlay(),

            // 얼굴 감지 가이드 프레임
            if (widget.showFaceGuide &&
                widget.controller != null &&
                widget.controller!.value.isInitialized)
              FadeTransition(
                opacity: _guideOpacity,
                child: _buildFaceGuideOverlay(),
              ),

            // 줌 레벨 표시
            if (_currentZoom > 1.05)
              Positioned(
                bottom: 20,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '${_currentZoom.toStringAsFixed(1)}x',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 카메라 아이콘 with 부드러운 펄스 애니메이션
          AnimatedBuilder(
            animation: _breatheAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _breatheAnimation.value,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary.withValues(alpha: 0.15),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    Icons.camera_alt_rounded,
                    size: 36,
                    color: AppColors.primary.withValues(alpha: 0.6),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          Text(
            '카메라를 준비하고 있어요...',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 15,
              fontWeight: FontWeight.w500,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 120,
            child: LinearProgressIndicator(
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(
                AppColors.primary.withValues(alpha: 0.6),
              ),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchingOverlay() {
    return Container(
      color: const Color(0xFF1A1A2E).withValues(alpha: 0.9),
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 500),
          builder: (context, value, child) {
            return Transform.rotate(
              angle: value * math.pi,
              child: Opacity(
                opacity: (1.0 - (value - 0.5).abs() * 2).clamp(0.3, 1.0),
                child: Icon(
                  Icons.flip_camera_ios_rounded,
                  size: 48,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFaceGuideOverlay() {
    return AnimatedBuilder(
      animation: _breatheAnimation,
      builder: (context, child) {
        return CustomPaint(
          painter: _FaceGuidePainter(
            breatheFactor: _breatheAnimation.value,
            guideColor: AppColors.primary.withValues(alpha: 0.4),
          ),
        );
      },
    );
  }

  void _onScaleStart(ScaleStartDetails details) {
    _baseZoom = _currentZoom;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    final newZoom = (_baseZoom * details.scale).clamp(1.0, 5.0);
    setState(() => _currentZoom = newZoom);
    widget.controller?.setZoomLevel(newZoom);
  }
}

/// 얼굴 가이드 프레임 페인터
class _FaceGuidePainter extends CustomPainter {
  final double breatheFactor;
  final Color guideColor;

  _FaceGuidePainter({
    required this.breatheFactor,
    required this.guideColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.38);
    final ovalWidth = size.width * 0.42 * breatheFactor;
    final ovalHeight = size.width * 0.56 * breatheFactor;

    final rect = Rect.fromCenter(
      center: center,
      width: ovalWidth,
      height: ovalHeight,
    );

    // 가이드 프레임 (점선 타원)
    final paint = Paint()
      ..color = guideColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // 코너 아크만 그리기 (더 세련된 느낌)
    const cornerLength = 0.15; // 아크 비율

    // 상단 좌측 코너
    canvas.drawArc(rect, -math.pi * 0.75, math.pi * cornerLength, false, paint);
    // 상단 우측 코너
    canvas.drawArc(
        rect, -math.pi * 0.25, -math.pi * cornerLength, false, paint);
    // 하단 우측 코너
    canvas.drawArc(rect, math.pi * 0.25, math.pi * cornerLength, false, paint);
    // 하단 좌측 코너
    canvas.drawArc(rect, math.pi * 0.75, -math.pi * cornerLength, false, paint);

    // 힌트 텍스트
    final textPainter = TextPainter(
      text: TextSpan(
        text: '아이 얼굴을 맞춰주세요',
        style: TextStyle(
          color: guideColor.withValues(alpha: 0.7),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        center.dx - textPainter.width / 2,
        center.dy + ovalHeight / 2 + 16,
      ),
    );
  }

  @override
  bool shouldRepaint(_FaceGuidePainter oldDelegate) =>
      breatheFactor != oldDelegate.breatheFactor;
}
