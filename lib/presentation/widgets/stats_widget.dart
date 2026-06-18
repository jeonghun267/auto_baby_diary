import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// 통계 위젯
/// - 감정 분포 파이 차트 (플레이스홀더)
/// - 일기 수 통계
/// - 연속 기록 카운터 (불꽃 아이콘)
class StatsWidget extends StatelessWidget {
  final int totalDiaryCount;
  final int streakDays;
  final Map<String, int> emotionDistribution;

  const StatsWidget({
    super.key,
    required this.totalDiaryCount,
    required this.streakDays,
    required this.emotionDistribution,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 상단 요약 카드 (일기 수 + 연속 기록)
        Row(
          children: [
            Expanded(
                child: _buildStatCard(
              icon: Icons.book,
              iconColor: AppColors.primary,
              label: '총 일기',
              value: '$totalDiaryCount',
              unit: '개',
              backgroundColor: AppColors.primary.withValues(alpha: 0.08),
            )),
            const SizedBox(width: 12),
            Expanded(child: _buildStreakCard()),
          ],
        ),
        const SizedBox(height: 16),

        // 감정 분포
        _buildEmotionDistribution(),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required String unit,
    required Color backgroundColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: iconColor.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  unit,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreakCard() {
    final hasStreak = streakDays > 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: hasStreak
            ? LinearGradient(
                colors: [
                  AppColors.emotionSurprised.withValues(alpha: 0.12),
                  AppColors.emotionHappy.withValues(alpha: 0.08),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: hasStreak ? null : AppColors.textHint.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasStreak
              ? AppColors.emotionSurprised.withValues(alpha: 0.2)
              : AppColors.textHint.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                hasStreak ? '🔥' : '💤',
                style: const TextStyle(fontSize: 22),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$streakDays',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '일',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '연속 기록',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmotionDistribution() {
    final total = emotionDistribution.values.fold(0, (a, b) => a + b);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.pie_chart, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                '감정 분포',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 파이 차트 플레이스홀더
          if (total > 0) ...[
            _buildEmotionPieChart(total),
            const SizedBox(height: 16),
            // 범례
            ..._buildEmotionLegend(total),
          ] else
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  '아직 기록된 감정이 없어요',
                  style: TextStyle(
                    color: AppColors.textHint,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmotionPieChart(int total) {
    return SizedBox(
      height: 20,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Row(
          children: emotionDistribution.entries.map((entry) {
            final ratio = entry.value / total;
            return Expanded(
              flex: (ratio * 100).toInt().clamp(1, 100),
              child: Container(color: _getEmotionColor(entry.key)),
            );
          }).toList(),
        ),
      ),
    );
  }

  List<Widget> _buildEmotionLegend(int total) {
    return emotionDistribution.entries.map((entry) {
      final ratio = total > 0 ? entry.value / total : 0.0;

      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: _getEmotionColor(entry.key),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _getEmotionEmoji(entry.key),
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(width: 6),
            Text(
              _getEmotionLabel(entry.key),
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const Spacer(),
            Text(
              '${entry.value}회',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${(ratio * 100).toInt()}%',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textHint,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  Color _getEmotionColor(String emotion) {
    switch (emotion) {
      case 'happy':
        return AppColors.emotionHappy;
      case 'crying':
        return AppColors.emotionCrying;
      case 'surprised':
        return AppColors.emotionSurprised;
      default:
        return AppColors.emotionNeutral;
    }
  }

  String _getEmotionEmoji(String emotion) {
    switch (emotion) {
      case 'happy':
        return '😊';
      case 'crying':
        return '😢';
      case 'surprised':
        return '😮';
      default:
        return '😐';
    }
  }

  String _getEmotionLabel(String emotion) {
    switch (emotion) {
      case 'happy':
        return '행복';
      case 'crying':
        return '울음';
      case 'surprised':
        return '놀람';
      default:
        return '평온';
    }
  }
}
