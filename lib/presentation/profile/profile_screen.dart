import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/providers/app_providers.dart';
import '../../data/repositories/auth_repository.dart';

/// 프로필 화면
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final childProfilesAsync = ref.watch(childProfilesProvider);
    final currentChild = ref.watch(currentChildProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(AppStrings.profile),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('로그아웃'),
                  content: const Text('정말 로그아웃 하시겠습니까?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('취소'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: const Text('로그아웃',
                          style: TextStyle(color: AppColors.error)),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                await ref.read(authRepositoryProvider).signOut();
                if (context.mounted) context.go('/login');
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 사용자 정보 카드
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: AppColors.primaryLight,
                    child:
                        const Icon(Icons.person, size: 36, color: Colors.white),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.email ?? '사용자',
                          style: AppTextStyles.h3,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '우리 아이의 소중한 하루를 기록해요',
                          style: AppTextStyles.body2,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 아이 프로필 섹션
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('아이 프로필', style: AppTextStyles.h3),
              TextButton.icon(
                onPressed: () => context.push('/profile/add-child'),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('추가'),
              ),
            ],
          ),
          const SizedBox(height: 8),

          childProfilesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) =>
                Text(AppStrings.errorGeneric, style: AppTextStyles.body2),
            data: (profiles) {
              if (profiles.isEmpty) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Icon(Icons.child_care,
                            size: 48, color: AppColors.textHint),
                        const SizedBox(height: 12),
                        Text(
                          '등록된 아이가 없습니다.\n아이 프로필을 추가해주세요.',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.body2,
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Column(
                children: profiles.map((profile) {
                  final isSelected = currentChild?.id == profile.id;
                  return Card(
                    color: isSelected ? AppColors.card : AppColors.surface,
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isSelected
                            ? AppColors.primary
                            : AppColors.primaryLight,
                        child: Text(
                          profile.name.isNotEmpty ? profile.name[0] : '?',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(profile.name, style: AppTextStyles.label),
                      subtitle: Text(
                        '${profile.ageInMonths}개월',
                        style: AppTextStyles.caption,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isSelected)
                            const Icon(Icons.check_circle,
                                color: AppColors.primary, size: 20),
                          IconButton(
                            icon: const Icon(Icons.edit, size: 18),
                            onPressed: () => context
                                .push('/profile/edit-child/${profile.id}'),
                          ),
                        ],
                      ),
                      onTap: () async {
                        if (currentChild?.id == profile.id) return;
                        await selectChild(ref, profile.id);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('${profile.name}(으)로 전환했어요'),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                    ),
                  );
                }).toList(),
              );
            },
          ),

          const SizedBox(height: 24),

          // 가족 관리
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.secondary.withValues(alpha: 0.2),
                child: const Icon(Icons.family_restroom,
                    color: AppColors.secondaryDark),
              ),
              title: const Text('가족 관리', style: AppTextStyles.label),
              subtitle: Text(
                '가족을 초대하고 함께 기록해요',
                style: AppTextStyles.caption,
              ),
              trailing:
                  const Icon(Icons.chevron_right, color: AppColors.textHint),
              onTap: () => context.push('/family'),
            ),
          ),

          const SizedBox(height: 8),

          // 데이터 내보내기
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.success.withValues(alpha: 0.2),
                child:
                    const Icon(Icons.picture_as_pdf, color: AppColors.success),
              ),
              title: const Text('데이터 내보내기', style: AppTextStyles.label),
              subtitle: Text(
                '성장/접종/마일스톤 기록을 PDF로 내보내기',
                style: AppTextStyles.caption,
              ),
              trailing:
                  const Icon(Icons.chevron_right, color: AppColors.textHint),
              onTap: () => context.push('/export'),
            ),
          ),
        ],
      ),
    );
  }
}
