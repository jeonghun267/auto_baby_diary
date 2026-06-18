import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/providers/app_providers.dart';
import '../../core/providers/health_providers.dart';
import '../../data/models/milestone_record.dart';
import '../../core/services/notification_service.dart';
import '../../data/repositories/milestone_repository.dart';
import '../widgets/state_views.dart';

class MilestoneScreen extends ConsumerStatefulWidget {
  const MilestoneScreen({super.key});

  @override
  ConsumerState<MilestoneScreen> createState() => _MilestoneScreenState();
}

class _MilestoneScreenState extends ConsumerState<MilestoneScreen> {
  String _selectedCategory = '전체';
  bool _isInitializing = false;

  static const _categories = ['전체', '신체', '인지', '사회성', '언어'];

  static const _categoryColors = {
    '신체': AppColors.primary,
    '인지': AppColors.secondary,
    '사회성': AppColors.success,
    '언어': AppColors.warning,
  };

  static const _defaultMilestones = [
    {'title': '고개를 가눌 수 있다', 'category': '신체', 'expected_month': 3},
    {'title': '물건을 쥘 수 있다', 'category': '신체', 'expected_month': 3},
    {'title': '소리에 반응한다', 'category': '인지', 'expected_month': 3},
    {'title': '사회적 미소를 짓는다', 'category': '사회성', 'expected_month': 3},
    {'title': '옹알이를 한다', 'category': '언어', 'expected_month': 3},
    {'title': '뒤집기를 할 수 있다', 'category': '신체', 'expected_month': 6},
    {'title': '앉을 수 있다 (도움 필요)', 'category': '신체', 'expected_month': 6},
    {'title': '물건을 입으로 탐색한다', 'category': '인지', 'expected_month': 6},
    {'title': '낯가림이 시작된다', 'category': '사회성', 'expected_month': 6},
    {'title': '자음 소리를 낸다 (바바, 마마)', 'category': '언어', 'expected_month': 6},
    {'title': '혼자 앉을 수 있다', 'category': '신체', 'expected_month': 9},
    {'title': '기어다닐 수 있다', 'category': '신체', 'expected_month': 9},
    {'title': '물건 영속성을 이해한다', 'category': '인지', 'expected_month': 9},
    {'title': '까꿍 놀이를 즐긴다', 'category': '사회성', 'expected_month': 9},
    {'title': '의미 있는 첫 단어를 말한다', 'category': '언어', 'expected_month': 9},
    {'title': '잡고 서기를 할 수 있다', 'category': '신체', 'expected_month': 12},
    {'title': '첫 걸음을 뗀다', 'category': '신체', 'expected_month': 12},
    {'title': '간단한 지시를 이해한다', 'category': '인지', 'expected_month': 12},
    {'title': '손가락으로 가리킨다', 'category': '사회성', 'expected_month': 12},
    {'title': '2-3개 단어를 말한다', 'category': '언어', 'expected_month': 12},
    {'title': '혼자 걸을 수 있다', 'category': '신체', 'expected_month': 18},
    {'title': '블록 쌓기를 할 수 있다', 'category': '인지', 'expected_month': 18},
    {'title': '다른 아이에게 관심을 보인다', 'category': '사회성', 'expected_month': 18},
    {'title': '10개 이상 단어를 사용한다', 'category': '언어', 'expected_month': 18},
    {'title': '계단을 오를 수 있다', 'category': '신체', 'expected_month': 24},
    {'title': '간단한 퍼즐을 맞출 수 있다', 'category': '인지', 'expected_month': 24},
    {'title': '역할 놀이를 한다', 'category': '사회성', 'expected_month': 24},
    {'title': '두 단어 문장을 만든다', 'category': '언어', 'expected_month': 24},
  ];

  @override
  Widget build(BuildContext context) {
    final child = ref.watch(currentChildProvider);
    final milestonesAsync = child != null
        ? ref.watch(milestonesProvider(child.id))
        : const AsyncValue<List<MilestoneRecord>>.data([]);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('발달 마일스톤'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: milestonesAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          onRetry: () {
            if (child != null) {
              ref.invalidate(milestonesProvider(child.id));
            }
          },
        ),
        data: (milestones) {
          if (milestones.isEmpty) {
            return _buildInitializeState(child);
          }
          return _buildContent(milestones, child!);
        },
      ),
    );
  }

  Widget _buildInitializeState(dynamic child) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.emoji_events_rounded, size: 64, color: AppColors.textHint),
          const SizedBox(height: 16),
          Text(
            '마일스톤을 초기화하시겠습니까?',
            style: AppTextStyles.body2,
          ),
          const SizedBox(height: 8),
          Text(
            '기본 발달 마일스톤을 생성합니다',
            style: AppTextStyles.bodySmall,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed:
                _isInitializing ? null : () => _initializeDefaults(child),
            icon: _isInitializing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.add_task_rounded),
            label: Text(_isInitializing ? '초기화 중...' : '마일스톤 초기화'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _initializeDefaults(dynamic child) async {
    if (child == null) return;
    setState(() => _isInitializing = true);

    try {
      await ref
          .read(milestoneRepositoryProvider)
          .initializeMilestones(child.id, _defaultMilestones);
      ref.invalidate(milestonesProvider(child.id));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('초기화에 실패했습니다.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isInitializing = false);
    }
  }

  Widget _buildContent(List<MilestoneRecord> milestones, dynamic child) {
    final filtered = _selectedCategory == '전체'
        ? milestones
        : milestones
            .where((m) =>
                milestoneCategoryToString(m.category) == _selectedCategory)
            .toList();

    final achievedCount = milestones.where((m) => m.isAchieved).length;
    final total = milestones.length;
    final progress = total > 0 ? achievedCount / total : 0.0;

    // Group by expected_month
    final grouped = <int, List<MilestoneRecord>>{};
    for (final m in filtered) {
      grouped.putIfAbsent(m.expectedMonth, () => []);
      grouped[m.expectedMonth]!.add(m);
    }
    final sortedMonths = grouped.keys.toList()..sort();

    return Column(
      children: [
        // Progress bar
        Container(
          margin: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('전체 진행률', style: AppTextStyles.labelLarge),
                  Text(
                    '$achievedCount / $total (${(progress * 100).toInt()}%)',
                    style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 10,
                  backgroundColor: AppColors.card,
                  valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                ),
              ),
            ],
          ),
        ),

        // Category chips
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: _categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final cat = _categories[index];
              final selected = _selectedCategory == cat;
              return ChoiceChip(
                label: Text(cat),
                selected: selected,
                selectedColor: AppColors.primary,
                backgroundColor: AppColors.surface,
                labelStyle: TextStyle(
                  color: selected ? Colors.white : AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: selected
                        ? AppColors.primary
                        : AppColors.primaryLight.withValues(alpha: 0.3),
                  ),
                ),
                onSelected: (_) => setState(() => _selectedCategory = cat),
              );
            },
          ),
        ),
        const SizedBox(height: 8),

        // Grouped milestones list
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    '해당 카테고리의 마일스톤이 없습니다',
                    style: AppTextStyles.bodySmall,
                  ),
                )
              : ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  itemCount: sortedMonths.length,
                  itemBuilder: (context, index) {
                    final month = sortedMonths[index];
                    final items = grouped[month]!;
                    final monthLabel = month == 0
                        ? '출생 시'
                        : month < 12
                            ? '$month개월'
                            : month % 12 == 0
                                ? '${month ~/ 12}세'
                                : '${month ~/ 12}세 ${month % 12}개월';
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            monthLabel,
                            style: AppTextStyles.h3.copyWith(fontSize: 16),
                          ),
                        ),
                        ...items.map((m) => _buildMilestoneItem(m, child)),
                        const SizedBox(height: 8),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildMilestoneItem(MilestoneRecord milestone, dynamic child) {
    final isAchieved = milestone.isAchieved;
    final category = milestoneCategoryToString(milestone.category);
    final color = _categoryColors[category] ?? AppColors.textSecondary;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isAchieved
              ? AppColors.success.withValues(alpha: 0.3)
              : AppColors.primaryLight.withValues(alpha: 0.2),
        ),
      ),
      color: isAchieved
          ? AppColors.success.withValues(alpha: 0.05)
          : AppColors.surface,
      child: CheckboxListTile(
        value: isAchieved,
        activeColor: AppColors.success,
        checkColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        controlAffinity: ListTileControlAffinity.leading,
        title: Row(
          children: [
            Expanded(
              child: Text(
                milestone.title,
                style: AppTextStyles.bodyMedium.copyWith(
                  decoration: isAchieved ? TextDecoration.lineThrough : null,
                  color: isAchieved
                      ? AppColors.textSecondary
                      : AppColors.textPrimary,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                category,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
          ],
        ),
        subtitle: isAchieved && milestone.achievedAt != null
            ? Text(
                '달성: ${DateFormat('yyyy.MM.dd').format(milestone.achievedAt!)}',
                style: AppTextStyles.caption.copyWith(color: AppColors.success),
              )
            : null,
        onChanged: (_) => _toggleMilestone(milestone, child),
      ),
    );
  }

  Future<void> _toggleMilestone(
      MilestoneRecord milestone, dynamic child) async {
    final wasAchieved = milestone.isAchieved;
    try {
      await ref.read(milestoneRepositoryProvider).toggleMilestone(
            milestone.id,
            !wasAchieved,
          );
      ref.invalidate(milestonesProvider(child.id));

      // 새로 달성한 경우에만 알림 (해제 시는 알림 X)
      if (!wasAchieved) {
        // 사용자가 마일스톤 알림을 켰을 때만
        try {
          final prefs = await SharedPreferences.getInstance();
          final enabled = prefs.getBool('milestone_alert_enabled') ?? true;
          if (enabled) {
            await NotificationService.showMilestoneAchieved(
              childName: child.name as String,
              milestoneTitle: milestone.title,
            );
          }
        } catch (_) {
          // 알림 실패해도 토글은 성공
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('업데이트에 실패했습니다.')),
        );
      }
    }
  }
}
