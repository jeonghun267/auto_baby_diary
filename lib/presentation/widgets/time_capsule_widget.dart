import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/date_formatter.dart';
import '../../data/models/diary_entry.dart';

/// 1년 전 오늘의 일기를 보여주는 타임캡슐 위젯
class TimeCapsuleWidget extends StatelessWidget {
  final DiaryEntry? entry;

  const TimeCapsuleWidget({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    if (entry == null) return const SizedBox.shrink();

    final diaryText = entry!.finalText ?? entry!.llmDraft ?? '';
    final preview =
        diaryText.length > 80 ? '${diaryText.substring(0, 80)}...' : diaryText;
    final hasPhoto = entry!.mediaUrls.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: GestureDetector(
        onTap: () => context.push('/diary/${entry!.id}'),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFFFF3E0),
                Color(0xFFFCE4EC),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.camera_alt_outlined,
                      size: 18,
                      color: AppColors.primaryDark,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '1\uB144 \uC804 \uC624\uB298',
                      style: AppTextStyles.labelLarge.copyWith(
                        color: AppColors.primaryDark,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      DateFormatter.formatDate(entry!.recordedAt),
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (hasPhoto) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          entry!.mediaUrls.first,
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color:
                                  AppColors.primaryLight.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.photo_outlined,
                              color: AppColors.primary,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (entry!.emotionSummary != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                _getEmotionEmoji(entry!.emotionSummary!),
                                style: const TextStyle(fontSize: 20),
                              ),
                            ),
                          if (preview.isNotEmpty)
                            Text(
                              preview,
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.textPrimary,
                                height: 1.5,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getEmotionEmoji(String emotion) {
    switch (emotion) {
      case 'happy':
        return '\uD83D\uDE0A';
      case 'crying':
        return '\uD83D\uDE22';
      case 'surprised':
        return '\uD83D\uDE2E';
      default:
        return '\uD83D\uDE10';
    }
  }
}
