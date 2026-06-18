import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../data/models/diary_entry.dart';
import 'emotion_badge_widget.dart';

/// 재사용 가능한 일기 카드 위젯
/// - 감정, 날짜, 미리보기 텍스트, 미디어 썸네일 표시
/// - 탭하면 상세 화면으로 이동
/// - 부드러운 그림자와 둥근 모서리
class DiaryCardWidget extends StatelessWidget {
  final DiaryEntry entry;
  final bool showFullDate;
  final VoidCallback? onTap;

  const DiaryCardWidget({
    super.key,
    required this.entry,
    this.showFullDate = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap ?? () => context.push('/diary/${entry.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 왼쪽 감정 색상 바
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: _getEmotionColor(),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                    ),
                  ),
                ),
                // 메인 콘텐츠
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 상단: 날짜 + 감정 배지
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                showFullDate
                                    ? DateFormatter.formatDate(entry.recordedAt)
                                    : DateFormatter.formatTime(
                                        entry.recordedAt),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textHint,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            if (entry.emotionSummary != null)
                              EmotionBadgeWidget(
                                emotion: entry.emotionSummary!,
                                animate: false,
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // 일기 미리보기 텍스트
                        Text(
                          entry.finalText ?? entry.llmDraft ?? '일기 내용이 없습니다',
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textPrimary,
                            height: 1.6,
                          ),
                        ),

                        // 미디어 썸네일
                        if (entry.mediaUrls.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _buildMediaThumbnails(),
                        ],

                        // 마일스톤 표시
                        if (entry.milestoneDetected != null) ...[
                          const SizedBox(height: 10),
                          _buildMilestoneTag(),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMediaThumbnails() {
    final displayCount =
        entry.mediaUrls.length > 3 ? 3 : entry.mediaUrls.length;
    final remaining = entry.mediaUrls.length - displayCount;

    return SizedBox(
      height: 56,
      child: Row(
        children: [
          ...List.generate(displayCount, (index) {
            return Container(
              width: 56,
              height: 56,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: AppColors.card,
              ),
              clipBehavior: Clip.antiAlias,
              child: CachedNetworkImage(
                imageUrl: entry.mediaUrls[index],
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: AppColors.card,
                  child: Icon(
                    Icons.image,
                    color: AppColors.textHint,
                    size: 24,
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: AppColors.card,
                  child: Icon(
                    Icons.broken_image,
                    color: AppColors.textHint,
                    size: 24,
                  ),
                ),
              ),
            );
          }),
          if (remaining > 0)
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: AppColors.card,
              ),
              child: Center(
                child: Text(
                  '+$remaining',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMilestoneTag() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🌟', style: TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          Text(
            entry.milestoneDetected!,
            style: TextStyle(
              fontSize: 11,
              color: AppColors.success,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Color _getEmotionColor() {
    switch (entry.emotionSummary) {
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
}
