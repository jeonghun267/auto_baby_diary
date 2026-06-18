import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/services/app_lock_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/supabase_service.dart';
import '../../core/utils/error_mapper.dart';
import '../../data/repositories/child_profile_repository.dart';

/// 설정 화면
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _reminderEnabled = false;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 20, minute: 0);
  bool _milestoneAlertEnabled = true;
  bool _appLockEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _reminderEnabled = prefs.getBool('reminder_enabled') ?? false;
      final reminderHour = prefs.getInt('reminder_hour') ?? 20;
      final reminderMinute = prefs.getInt('reminder_minute') ?? 0;
      _reminderTime = TimeOfDay(hour: reminderHour, minute: reminderMinute);
      _milestoneAlertEnabled = prefs.getBool('milestone_alert_enabled') ?? true;
      _appLockEnabled = prefs.getBool('app_lock_enabled') ?? false;
    });
  }

  Future<void> _savePreference(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is int) {
      await prefs.setInt(key, value);
    }
  }

  // ─── Password Change ───────────────────────────────────
  void _showPasswordChangeDialog() {
    final user = SupabaseService.auth.currentUser;
    final email = user?.email;

    if (email == null || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이메일 정보를 찾을 수 없습니다.')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('비밀번호 변경'),
        content: Text(
          '$email 으로 비밀번호 재설정 이메일을 보내시겠습니까?',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await SupabaseService.auth.resetPasswordForEmail(email);
                if (mounted) {
                  showDialog(
                    context: context,
                    builder: (ctx2) => AlertDialog(
                      title: const Text('이메일 전송 완료'),
                      content: const Text('비밀번호 재설정 이메일을 보냈습니다.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx2).pop(),
                          child: const Text('확인'),
                        ),
                      ],
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('이메일 전송에 실패했습니다.')),
                  );
                }
              }
            },
            child: const Text('보내기'),
          ),
        ],
      ),
    );
  }

  // ─── Account Deletion ──────────────────────────────────
  void _showDeleteAccountDialog() {
    final confirmController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('회원 탈퇴'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '정말 탈퇴하시겠습니까?\n모든 데이터가 삭제되며 복구할 수 없습니다.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.error,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '확인을 위해 "탈퇴"를 입력해주세요.',
                style: AppTextStyles.bodySmall,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: confirmController,
                decoration: const InputDecoration(
                  hintText: '탈퇴',
                  isDense: true,
                ),
                onChanged: (_) => setDialogState(() {}),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: confirmController.text.trim() == '탈퇴'
                  ? () async {
                      Navigator.of(ctx).pop();
                      await _deleteAccount();
                    }
                  : null,
              child: Text(
                '탈퇴하기',
                style: TextStyle(
                  color: confirmController.text.trim() == '탈퇴'
                      ? AppColors.error
                      : AppColors.textHint,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteAccount() async {
    try {
      final userId = SupabaseService.auth.currentUser?.id;
      if (userId == null) return;

      // 1) 아이별로 Storage 미디어 정리 (cascade 전에)
      //    각 아이마다 deleteChild 호출하면 일기 미디어도 함께 정리됨
      try {
        final childRepo = ref.read(childProfileRepositoryProvider);
        final myChildren = await childRepo.getMyChildren(userId);
        for (final child in myChildren) {
          await childRepo.deleteChild(child.id);
        }
      } catch (e) {
        // 일부 미디어 정리 실패해도 계정 삭제는 계속 진행
        debugPrint('[DeleteAccount] 미디어 정리 실패: $e');
      }

      // 2) profiles 삭제 (cascade로 남은 데이터 자동 삭제)
      await SupabaseService.client.from('profiles').delete().eq('id', userId);

      await SupabaseService.auth.signOut();

      if (mounted) {
        context.go('/login');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('탈퇴 실패: ${ErrorMapper.map(e)}')),
        );
      }
    }
  }

  // ─── Reminder Time Picker ──────────────────────────────
  Future<void> _pickReminderTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.primary,
                ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _reminderTime = picked);
      await _savePreference('reminder_hour', picked.hour);
      await _savePreference('reminder_minute', picked.minute);

      // 리마인더가 켜져 있으면 새 시각으로 다시 스케줄
      if (_reminderEnabled) {
        await _rescheduleReminder();
      }
    }
  }

  /// 리마인더 토글 핸들러
  Future<void> _onReminderToggle(bool value) async {
    setState(() => _reminderEnabled = value);
    await _savePreference('reminder_enabled', value);

    if (value) {
      // 권한 요청
      final granted = await NotificationService.requestPermission();
      if (!granted) {
        if (mounted) {
          setState(() => _reminderEnabled = false);
          await _savePreference('reminder_enabled', false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('알림 권한이 필요해요. 설정에서 허용해주세요.'),
            ),
          );
        }
        return;
      }
      await _rescheduleReminder();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '매일 ${_reminderTime.format(context)}에 알려드릴게요',
            ),
          ),
        );
      }
    } else {
      await NotificationService.cancelReminder();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('리마인더를 껐어요')),
        );
      }
    }
  }

  /// 앱 잠금 토글 핸들러
  Future<void> _onAppLockToggle(bool value) async {
    if (value) {
      // 켜기 — 디바이스 인증 가능 여부 확인
      final available = await AppLockService.isAvailable();
      if (!available) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                '이 기기는 생체 인증을 지원하지 않아요. 시스템 설정에서 PIN/패턴을 먼저 설정해주세요.',
              ),
            ),
          );
        }
        return;
      }
      final ok = await AppLockService.enable();
      if (!ok) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('인증에 실패했어요. 다시 시도해주세요.')),
          );
        }
        return;
      }
      if (mounted) {
        setState(() => _appLockEnabled = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('앱 잠금이 켜졌어요 🔒')),
        );
      }
    } else {
      // 끄기 — 인증 후 비활성화
      final ok = await AppLockService.disable();
      if (!ok) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('인증에 실패했어요.')),
          );
        }
        return;
      }
      if (mounted) {
        setState(() => _appLockEnabled = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('앱 잠금을 껐어요')),
        );
      }
    }
  }

  Future<void> _rescheduleReminder() async {
    try {
      await NotificationService.scheduleDailyReminder(
        hour: _reminderTime.hour,
        minute: _reminderTime.minute,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('알림 예약에 실패했어요')),
        );
      }
    }
  }

  // ─── Cache Clear ───────────────────────────────────────
  Future<void> _clearCache() async {
    imageCache.clear();
    imageCache.clearLiveImages();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('캐시가 삭제되었습니다.')),
      );
    }
  }

  // ─── Terms / Privacy Bottom Sheet ──────────────────────
  void _showTermsBottomSheet() {
    _showTextBottomSheet(
      title: '이용약관',
      content: '''
본 서비스 이용약관(이하 "약관")은 자동 육아일기(이하 "서비스")의 이용 조건과 절차, 이용자와 서비스 제공자 간의 권리, 의무 및 책임사항 등을 규정합니다.

제1조 (목적)
본 약관은 서비스가 제공하는 모든 서비스의 이용조건 및 절차에 관한 사항을 규정하는 것을 목적으로 합니다.

제2조 (서비스의 제공)
서비스는 아이의 사진을 분석하여 자동으로 육아일기를 생성하는 기능을 제공합니다.

제3조 (개인정보)
서비스는 이용자의 개인정보를 소중히 보호하며, 관련 법령에 따라 처리합니다.

제4조 (이용자의 의무)
이용자는 서비스 이용 시 타인의 권리를 침해하거나 관련 법령을 위반하는 행위를 하여서는 안 됩니다.

제5조 (서비스의 변경 및 중단)
서비스는 필요에 따라 서비스의 내용을 변경하거나 중단할 수 있으며, 이 경우 사전에 공지합니다.
''',
    );
  }

  void _showPrivacyBottomSheet() {
    _showTextBottomSheet(
      title: '개인정보 처리방침',
      content: '''
자동 육아일기(이하 "서비스")는 이용자의 개인정보를 중요시하며, 「개인정보 보호법」을 준수합니다.

1. 수집하는 개인정보 항목
- 이메일 주소, 비밀번호 (회원가입 시)
- 아이의 이름, 생년월일, 성별 (프로필 등록 시)
- 사진 (일기 작성 시)

2. 개인정보의 수집 및 이용 목적
- 회원 관리 및 서비스 제공
- AI 기반 일기 자동 생성
- 서비스 개선 및 통계 분석

3. 개인정보의 보유 및 이용 기간
- 회원 탈퇴 시까지 보유하며, 탈퇴 시 즉시 삭제합니다.

4. 개인정보의 제3자 제공
- 원칙적으로 이용자의 개인정보를 제3자에게 제공하지 않습니다.

5. 개인정보의 안전성 확보 조치
- 데이터 암호화, 접근 권한 관리 등 기술적 보호조치를 시행합니다.
''',
    );
  }

  void _showTextBottomSheet({
    required String title,
    required String content,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (ctx, scrollController) => Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textHint,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(title, style: AppTextStyles.h3),
            const Divider(height: 24),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(content, style: AppTextStyles.bodyMedium),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ─── Build ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final isDarkMode = themeMode == ThemeMode.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('설정'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // ── 구독 ──
          _buildSectionHeader('구독'),
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: _buildListTile(
              icon: Icons.workspace_premium,
              title: '프리미엄 플랜',
              onTap: () => context.push('/premium'),
            ),
          ),

          // ── 내 계정 ──
          _buildSectionHeader('내 계정'),
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Column(
              children: [
                _buildListTile(
                  icon: Icons.lock_outline,
                  title: '비밀번호 변경',
                  onTap: _showPasswordChangeDialog,
                ),
                const Divider(height: 1, indent: 56),
                _buildListTile(
                  icon: Icons.person_off_outlined,
                  title: '회원 탈퇴',
                  titleColor: AppColors.error,
                  onTap: _showDeleteAccountDialog,
                ),
              ],
            ),
          ),

          // ── 알림 ──
          _buildSectionHeader('알림'),
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.edit_notifications_outlined,
                      color: AppColors.primary),
                  title: Text('일기 기록 리마인더', style: AppTextStyles.bodyLarge),
                  subtitle: Text(
                    _reminderEnabled
                        ? '매일 ${_reminderTime.format(context)}에 알림'
                        : '꺼짐',
                    style: AppTextStyles.caption,
                  ),
                  value: _reminderEnabled,
                  activeColor: AppColors.primary,
                  onChanged: _onReminderToggle,
                ),
                if (_reminderEnabled) ...[
                  const Divider(height: 1, indent: 56),
                  ListTile(
                    leading:
                        const Icon(Icons.access_time, color: AppColors.primary),
                    title: Text('리마인더 시간', style: AppTextStyles.bodyLarge),
                    trailing: Text(
                      _reminderTime.format(context),
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: _pickReminderTime,
                  ),
                ],
                const Divider(height: 1, indent: 56),
                SwitchListTile(
                  secondary: const Icon(Icons.emoji_events_outlined,
                      color: AppColors.primary),
                  title: Text('마일스톤 알림', style: AppTextStyles.bodyLarge),
                  value: _milestoneAlertEnabled,
                  activeColor: AppColors.primary,
                  onChanged: (value) {
                    setState(() => _milestoneAlertEnabled = value);
                    _savePreference('milestone_alert_enabled', value);
                  },
                ),
              ],
            ),
          ),

          // ── 앱 설정 ──
          _buildSectionHeader('앱 설정'),
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.dark_mode_outlined,
                      color: AppColors.primary),
                  title: Text('다크 모드', style: AppTextStyles.bodyLarge),
                  value: isDarkMode,
                  activeColor: AppColors.primary,
                  onChanged: (_) {
                    ref.read(themeModeProvider.notifier).toggle();
                  },
                ),
                const Divider(height: 1, indent: 56),
                SwitchListTile(
                  secondary:
                      const Icon(Icons.lock_outlined, color: AppColors.primary),
                  title: Text('앱 잠금', style: AppTextStyles.bodyLarge),
                  subtitle: Text(
                    _appLockEnabled ? '생체 인증으로 앱을 보호하고 있어요' : '꺼짐',
                    style: AppTextStyles.caption,
                  ),
                  value: _appLockEnabled,
                  activeColor: AppColors.primary,
                  onChanged: _onAppLockToggle,
                ),
              ],
            ),
          ),

          // ── 데이터 ──
          _buildSectionHeader('데이터'),
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: _buildListTile(
              icon: Icons.cleaning_services_outlined,
              title: '캐시 삭제',
              onTap: _clearCache,
            ),
          ),

          // ── 앱 정보 ──
          _buildSectionHeader('앱 정보'),
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Column(
              children: [
                ListTile(
                  leading:
                      const Icon(Icons.info_outline, color: AppColors.primary),
                  title: Text('버전', style: AppTextStyles.bodyLarge),
                  trailing: Text(
                    '1.0.0',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                const Divider(height: 1, indent: 56),
                _buildListTile(
                  icon: Icons.description_outlined,
                  title: '이용약관',
                  onTap: () => context.push('/terms'),
                ),
                const Divider(height: 1, indent: 56),
                _buildListTile(
                  icon: Icons.privacy_tip_outlined,
                  title: '개인정보 처리방침',
                  onTap: () => context.push('/privacy'),
                ),
                const Divider(height: 1, indent: 56),
                _buildListTile(
                  icon: Icons.source_outlined,
                  title: '오픈소스 라이선스',
                  onTap: () {
                    showLicensePage(
                      context: context,
                      applicationName: '자동 육아일기',
                      applicationVersion: '1.0.0',
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ─── Helpers ───────────────────────────────────────────

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 8, bottom: 8),
      child: Text(
        title,
        style: AppTextStyles.labelLarge.copyWith(
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required String title,
    Color? titleColor,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: titleColor ?? AppColors.primary),
      title: Text(
        title,
        style: AppTextStyles.bodyLarge.copyWith(
          color: titleColor,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: AppColors.textHint,
      ),
      onTap: onTap,
    );
  }
}
