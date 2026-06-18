import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

const _kTourSeenKey = 'has_seen_home_tour_v1';

Future<bool> hasSeenHomeTour() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_kTourSeenKey) ?? false;
}

Future<void> markHomeTourSeen() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_kTourSeenKey, true);
}

class HomeTourStep {
  final GlobalKey targetKey;
  final String emoji;
  final String title;
  final String description;

  const HomeTourStep({
    required this.targetKey,
    required this.emoji,
    required this.title,
    required this.description,
  });
}

class HomeTourOverlay extends StatefulWidget {
  final List<HomeTourStep> steps;
  final VoidCallback onComplete;

  const HomeTourOverlay({
    super.key,
    required this.steps,
    required this.onComplete,
  });

  @override
  State<HomeTourOverlay> createState() => _HomeTourOverlayState();
}

class _HomeTourOverlayState extends State<HomeTourOverlay>
    with SingleTickerProviderStateMixin {
  int _step = 0;
  late final AnimationController _ctrl;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..forward();
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Rect? _targetRect() {
    final ctx = widget.steps[_step].targetKey.currentContext;
    if (ctx == null) return null;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    final offset = box.localToGlobal(Offset.zero);
    return offset & box.size;
  }

  void _next() {
    if (_step < widget.steps.length - 1) {
      _ctrl.reset();
      setState(() => _step++);
      _ctrl.forward();
    } else {
      widget.onComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.steps[_step];
    final rect = _targetRect();
    final size = MediaQuery.of(context).size;
    final padding = MediaQuery.of(context).padding;
    final isLast = _step == widget.steps.length - 1;

    return FadeTransition(
      opacity: _fade,
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            // 어두운 오버레이 + 스포트라이트
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _next,
              child: CustomPaint(
                size: size,
                painter: rect != null
                    ? _SpotlightPainter(spotlight: rect.inflate(8))
                    : _FullDarkPainter(),
              ),
            ),

            // 툴팁 카드
            if (rect != null)
              _TooltipCard(
                step: current,
                targetRect: rect,
                screenSize: size,
                screenPadding: padding,
                isLast: isLast,
                onNext: _next,
              ),

            // 상단 - 스텝 인디케이터 + 건너뛰기
            Positioned(
              top: padding.top + 12,
              left: 16,
              right: 16,
              child: Row(
                children: [
                  ...List.generate(widget.steps.length, (i) {
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.only(right: 6),
                      width: i == _step ? 22 : 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: i == _step
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                  const Spacer(),
                  GestureDetector(
                    onTap: widget.onComplete,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.4),
                            width: 1),
                      ),
                      child: const Text(
                        '건너뛰기',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Tooltip Card ─────────────────────────────────────────

class _TooltipCard extends StatelessWidget {
  final HomeTourStep step;
  final Rect targetRect;
  final Size screenSize;
  final EdgeInsets screenPadding;
  final bool isLast;
  final VoidCallback onNext;

  const _TooltipCard({
    required this.step,
    required this.targetRect,
    required this.screenSize,
    required this.screenPadding,
    required this.isLast,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    const cardH = 170.0;
    const gap = 16.0;

    // 타겟이 화면 아래쪽이면 카드를 위에, 위쪽이면 아래에 배치
    final showAbove = targetRect.center.dy > screenSize.height * 0.55;
    double top =
        showAbove ? targetRect.top - cardH - gap : targetRect.bottom + gap;

    top = top.clamp(
      screenPadding.top + 60.0,
      screenSize.height - cardH - 24.0,
    );

    return Positioned(
      top: top,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(step.emoji, style: const TextStyle(fontSize: 26)),
                const SizedBox(width: 10),
                Expanded(child: Text(step.title, style: AppTextStyles.h3)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              step.description,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onNext,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(
                  isLast ? '시작하기 🎉' : '다음  →',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Painters ─────────────────────────────────────────────

class _SpotlightPainter extends CustomPainter {
  final Rect spotlight;
  _SpotlightPainter({required this.spotlight});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withValues(alpha: 0.72);
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(spotlight, const Radius.circular(14)));
    path.fillType = PathFillType.evenOdd;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) => old.spotlight != spotlight;
}

class _FullDarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.black.withValues(alpha: 0.72),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
