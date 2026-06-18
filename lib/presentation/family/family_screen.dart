import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/providers/app_providers.dart';
import '../../core/utils/error_mapper.dart';
import '../../data/models/family_member.dart';
import '../../data/repositories/family_repository.dart';
import '../widgets/state_views.dart';
import 'invite_dialog.dart';

/// 가족 관리 화면
class FamilyScreen extends ConsumerStatefulWidget {
  const FamilyScreen({super.key});

  @override
  ConsumerState<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends ConsumerState<FamilyScreen> {
  final _inviteCodeController = TextEditingController();
  bool _isInviting = false;
  bool _isJoining = false;

  @override
  void dispose() {
    _inviteCodeController.dispose();
    super.dispose();
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'parent':
        return '부모';
      case 'family':
        return '가족';
      case 'viewer':
        return '열람자';
      default:
        return role;
    }
  }

  Future<void> _onInviteFamily() async {
    debugPrint('[Family] invite button tapped');
    final child = ref.read(currentChildProvider);
    final user = ref.read(currentUserProvider);
    debugPrint('[Family] child=${child?.id} user=${user?.id}');
    if (child == null || user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('아이를 먼저 등록해주세요')),
      );
      return;
    }
    if (_isInviting) {
      debugPrint('[Family] already inviting, ignoring tap');
      return;
    }
    setState(() => _isInviting = true);

    try {
      debugPrint('[Family] calling createInvite');
      final code = await ref
          .read(familyRepositoryProvider)
          .createInvite(
            childId: child.id,
            inviterId: user.id,
          )
          .timeout(const Duration(seconds: 15));
      debugPrint('[Family] createInvite returned code=$code');
      if (!mounted) return;
      InviteDialog.show(context, code);
    } catch (e, st) {
      debugPrint('[Family] createInvite failed: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('초대 코드 생성 실패: ${ErrorMapper.mapFamilyInvite(e)}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isInviting = false);
    }
  }

  Future<void> _onJoinFamily() async {
    final code = _inviteCodeController.text.trim();
    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('6자리 초대 코드를 입력해주세요')),
      );
      return;
    }
    final user = ref.read(currentUserProvider);
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인이 필요합니다')),
      );
      return;
    }
    if (_isJoining) return;
    setState(() => _isJoining = true);

    try {
      final member = await ref.read(familyRepositoryProvider).joinByCode(
            code: code,
            userId: user.id,
          );
      ref.invalidate(familyMembersProvider(member.childId));
      ref.invalidate(childProfilesProvider);
      _inviteCodeController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('가족에 참여했습니다 🎉')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorMapper.mapFamilyInvite(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _isJoining = false);
    }
  }

  Future<void> _onRemoveMember(FamilyMember member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('멤버 제거'),
        content: Text('${member.nickname ?? "이 멤버"}를 가족에서 제거하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('제거', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(familyRepositoryProvider).removeMember(member.id);
      ref.invalidate(familyMembersProvider(member.childId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('제거 실패: ${ErrorMapper.map(e)}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final child = ref.watch(currentChildProvider);
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('가족 관리')),
      body: child == null
          ? _buildNoChildState()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 안내 카드
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: AppColors.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${child.name}의 일기/성장 기록을 가족과 공유할 수 있어요.\n'
                          '초대 코드는 24시간 동안 유효합니다.',
                          style: AppTextStyles.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 초대 버튼
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isInviting ? null : _onInviteFamily,
                    icon: _isInviting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.person_add),
                    label: Text(_isInviting ? '코드 생성 중...' : '가족 초대하기'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // 초대 코드 입력
                Text('초대 코드 입력', style: AppTextStyles.h3),
                const SizedBox(height: 8),
                Text(
                  '가족에게 받은 초대 코드를 입력하세요',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _inviteCodeController,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 18,
                          letterSpacing: 4,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: InputDecoration(
                          hintText: '------',
                          hintStyle: TextStyle(
                            color: AppColors.textHint,
                            letterSpacing: 4,
                          ),
                          counterText: '',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _isJoining ? null : _onJoinFamily,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(72, 52),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 18,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isJoining
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('참여'),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // 가족 멤버 목록
                Row(
                  children: [
                    Text('가족 멤버', style: AppTextStyles.h3),
                    const SizedBox(width: 8),
                    Consumer(
                      builder: (context, ref, _) {
                        final async =
                            ref.watch(familyMembersProvider(child.id));
                        return async.maybeWhen(
                          data: (members) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${members.length}명',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          orElse: () => const SizedBox.shrink(),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                Consumer(
                  builder: (context, ref, _) {
                    final async = ref.watch(familyMembersProvider(child.id));
                    return async.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: SizedBox(
                          height: 48,
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      ),
                      error: (e, _) => Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            '가족 멤버를 불러올 수 없습니다.\n${ErrorMapper.map(e)}',
                            style: AppTextStyles.bodyMedium,
                          ),
                        ),
                      ),
                      data: (members) {
                        if (members.isEmpty) {
                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.group_add,
                                    size: 48,
                                    color: AppColors.textHint,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    '아직 가족 멤버가 없습니다.\n위 버튼으로 가족을 초대해보세요.',
                                    textAlign: TextAlign.center,
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        return Column(
                          children: members.map((m) {
                            final isMe = m.userId == user?.id;
                            final isOwner = m.role == 'parent';
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: AppColors.primaryLight,
                                  child: Text(
                                    (m.nickname ?? _roleLabel(m.role))[0],
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  m.nickname ?? _roleLabel(m.role),
                                  style: AppTextStyles.label,
                                ),
                                subtitle: Text(
                                  '${_roleLabel(m.role)} · ${m.createdAt.year}.${m.createdAt.month}.${m.createdAt.day} 참여${isMe ? " · 나" : ""}',
                                  style: AppTextStyles.caption,
                                ),
                                trailing: isOwner || isMe
                                    ? Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryLight
                                              .withValues(alpha: 0.3),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          _roleLabel(m.role),
                                          style: AppTextStyles.caption.copyWith(
                                            color: AppColors.primaryDark,
                                          ),
                                        ),
                                      )
                                    : IconButton(
                                        icon: const Icon(
                                          Icons.remove_circle_outline,
                                          color: AppColors.error,
                                        ),
                                        onPressed: () => _onRemoveMember(m),
                                        tooltip: '멤버 제거',
                                      ),
                              ),
                            );
                          }).toList(),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
    );
  }

  Widget _buildNoChildState() {
    return EmptyView(
      icon: Icons.family_restroom,
      title: '아이를 먼저 등록해주세요',
      subtitle: '아이 프로필이 등록된 후에 가족과 공유할 수 있어요',
      actionLabel: '아이 등록하기',
      onAction: () => context.push('/profile/add-child'),
    );
  }
}
