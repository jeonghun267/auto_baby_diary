import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

/// 연속 기록 스트릭 배지 위젯
class StreakBadgeWidget extends StatelessWidget {
  final int streakCount;

  const StreakBadgeWidget({super.key, required this.streakCount});

  @override
  Widget build(BuildContext context) {
    if (streakCount == 0) {
      return _buildBadge(
        emoji: '\uD83D\uDCA4',
        text:
            '\uC624\uB298 \uCCAB \uAE30\uB85D\uC744 \uB0A8\uACA8\uBCF4\uC138\uC694',
        backgroundColor: AppColors.secondaryLight.withValues(alpha: 0.3),
        textColor: AppColors.textSecondary,
      );
    }

    String emoji;
    Color backgroundColor;
    Color textColor;

    if (streakCount >= 30) {
      emoji = '\uD83D\uDC8E';
      backgroundColor = const Color(0xFFE8EAF6);
      textColor = const Color(0xFF3F51B5);
    } else if (streakCount >= 7) {
      emoji = '\uD83D\uDD25';
      backgroundColor = const Color(0xFFFFF8E1);
      textColor = const Color(0xFFF57F17);
    } else {
      emoji = '\uD83D\uDD25';
      backgroundColor = AppColors.primaryLight.withValues(alpha: 0.2);
      textColor = AppColors.primaryDark;
    }

    return _buildBadge(
      emoji: emoji,
      text: '$streakCount\uC77C \uC5F0\uC18D',
      backgroundColor: backgroundColor,
      textColor: textColor,
    );
  }

  Widget _buildBadge({
    required String emoji,
    required String text,
    required Color backgroundColor,
    required Color textColor,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 6),
          Text(
            text,
            style: AppTextStyles.labelMedium.copyWith(
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
