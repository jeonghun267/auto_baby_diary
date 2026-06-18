import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// 발달 리포트 카드 위젯
/// - 확장/축소 부드러운 애니메이션
/// - 발달 진행 바 (미니 차트)
/// - 이정표 축하 애니메이션
class DevelopmentReportCard extends StatefulWidget {
  final String report;
  final String? milestone;
  final double? developmentProgress;
  final Map<String, double>? developmentAreas;

  const DevelopmentReportCard({
    super.key,
    required this.report,
    this.milestone,
    this.developmentProgress,
    this.developmentAreas,
  });

  @override
  State<DevelopmentReportCard> createState() => _DevelopmentReportCardState();
}

class _DevelopmentReportCardState extends State<DevelopmentReportCard>
    with TickerProviderStateMixin {
  bool _isExpanded = false;

  late final AnimationController _milestoneController;
  late final Animation<double> _milestoneScale;
  late final Animation<double> _milestoneRotation;

  late final AnimationController _progressController;

  @override
  void initState() {
    super.initState();

    _milestoneController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _milestoneScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _milestoneController, curve: Curves.elasticOut),
    );
    _milestoneRotation = Tween<double>(begin: -0.1, end: 0.0).animate(
      CurvedAnimation(parent: _milestoneController, curve: Curves.easeOut),
    );

    _progressController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    if (widget.milestone != null) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) _milestoneController.forward();
      });
    }

    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _progressController.forward();
    });
  }

  @override
  void dispose() {
    _milestoneController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더 (탭하면 확장/축소)
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.insights,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '발달 리포트',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (!_isExpanded)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              widget.report,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 확장 콘텐츠
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: _buildExpandedContent(),
            crossFadeState: _isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
            sizeCurve: Curves.easeInOut,
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedContent() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 리포트 텍스트
          Text(
            widget.report,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 16),

          // 발달 진행 바
          _buildDevelopmentProgressSection(),

          // 마일스톤 축하
          if (widget.milestone != null) ...[
            const SizedBox(height: 16),
            _buildMilestoneCelebration(),
          ],
        ],
      ),
    );
  }

  Widget _buildDevelopmentProgressSection() {
    final areas = widget.developmentAreas ??
        {
          '신체 발달': 0.7,
          '언어 발달': 0.5,
          '인지 발달': 0.6,
          '사회성 발달': 0.45,
        };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '발달 영역별 진행도',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        ...areas.entries.map((entry) => _buildProgressBar(
              label: entry.key,
              progress: entry.value,
              color: _getAreaColor(entry.key),
            )),
      ],
    );
  }

  Widget _buildProgressBar({
    required String label,
    required double progress,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              AnimatedBuilder(
                animation: _progressController,
                builder: (context, child) {
                  return Text(
                    '${(progress * _progressController.value * 100).toInt()}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 8,
              child: AnimatedBuilder(
                animation: _progressController,
                builder: (context, child) {
                  return LinearProgressIndicator(
                    value: progress *
                        CurvedAnimation(
                          parent: _progressController,
                          curve: Curves.easeOutCubic,
                        ).value,
                    backgroundColor: color.withValues(alpha: 0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMilestoneCelebration() {
    return ScaleTransition(
      scale: _milestoneScale,
      child: RotationTransition(
        turns: _milestoneRotation,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.success.withValues(alpha: 0.15),
                AppColors.emotionHappy.withValues(alpha: 0.1),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.success.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Text('🎉', style: TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '발달 이정표 달성!',
                      style: TextStyle(
                        color: AppColors.success,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.milestone!,
                      style: TextStyle(
                        color: AppColors.success.withValues(alpha: 0.8),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.star, color: AppColors.emotionHappy, size: 24),
            ],
          ),
        ),
      ),
    );
  }

  Color _getAreaColor(String area) {
    switch (area) {
      case '신체 발달':
        return AppColors.primary;
      case '언어 발달':
        return AppColors.secondary;
      case '인지 발달':
        return AppColors.emotionSurprised;
      case '사회성 발달':
        return AppColors.emotionNeutral;
      default:
        return AppColors.primary;
    }
  }
}
