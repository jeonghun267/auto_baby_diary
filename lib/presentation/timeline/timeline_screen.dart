import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/providers/app_providers.dart';
import '../../core/utils/date_formatter.dart';
import '../widgets/state_views.dart';
import 'timeline_controller.dart';

/// 타임라인 화면 - 일기 목록을 시간순으로 표시 (페이지네이션 + 무한 스크롤)
class TimelineScreen extends ConsumerStatefulWidget {
  const TimelineScreen({super.key});

  @override
  ConsumerState<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends ConsumerState<TimelineScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // 끝에서 200px 이내 도달 시 다음 페이지 로드
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 200) {
      ref.read(timelineControllerProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final child = ref.watch(currentChildProvider);
    final state = ref.watch(timelineControllerProvider);
    final controller = ref.read(timelineControllerProvider.notifier);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(AppStrings.timeline),
      ),
      body: child == null
          ? _buildNoChildState()
          : RefreshIndicator(
              onRefresh: controller.refresh,
              color: AppColors.primary,
              child: _buildBody(state),
            ),
    );
  }

  Widget _buildBody(TimelineState state) {
    if (state.isLoading && state.entries.isEmpty) {
      return const SkeletonListView(itemHeight: 100);
    }
    if (state.error != null && state.entries.isEmpty) {
      return ErrorView(
        message: AppStrings.errorGeneric,
        onRetry: () => ref.read(timelineControllerProvider.notifier).refresh(),
      );
    }
    if (state.entries.isEmpty) {
      return ListView(
        // RefreshIndicator가 동작하려면 스크롤 가능해야 함
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: const EmptyView(
              icon: Icons.timeline,
              title: '아직 기록이 없어요',
              subtitle: '첫 번째 일기를 작성해보세요!',
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: state.entries.length + (state.hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        // 로딩 인디케이터 (마지막 행)
        if (index >= state.entries.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: state.isLoadingMore
                  ? const CircularProgressIndicator()
                  : const SizedBox(height: 24),
            ),
          );
        }

        final entry = state.entries[index];
        final isLast = index == state.entries.length - 1 && !state.hasMore;
        return InkWell(
          onTap: () => context.push('/diary/${entry.id}'),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 타임라인 라인 + 도트
                Column(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.primaryLight,
                          width: 2,
                        ),
                      ),
                    ),
                    if (!isLast)
                      Container(
                        width: 2,
                        height: 80,
                        color: AppColors.primaryLight,
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                // 내용 카드
                Expanded(
                  child: Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                DateFormatter.formatDate(entry.recordedAt),
                                style: AppTextStyles.captionBold
                                    .copyWith(color: AppColors.primary),
                              ),
                              const Spacer(),
                              if (entry.emotionSummary != null)
                                Text(
                                  _getEmotionEmoji(entry.emotionSummary!),
                                  style: const TextStyle(fontSize: 18),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            entry.finalText ?? entry.llmDraft ?? '내용 없음',
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.body2,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNoChildState() {
    return EmptyView(
      icon: Icons.child_care_rounded,
      title: '아이를 먼저 등록해주세요',
      subtitle: '아이 프로필이 등록된 후에 일기를 볼 수 있어요',
      actionLabel: '아이 등록하기',
      onAction: () => context.push('/profile/add-child'),
    );
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
}
