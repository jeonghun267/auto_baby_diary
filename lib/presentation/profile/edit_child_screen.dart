import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/supabase_service.dart';

class EditChildScreen extends ConsumerStatefulWidget {
  final String childId;
  const EditChildScreen({super.key, required this.childId});

  @override
  ConsumerState<EditChildScreen> createState() => _EditChildScreenState();
}

class _EditChildScreenState extends ConsumerState<EditChildScreen> {
  final _nameController = TextEditingController();
  DateTime? _birthDate;
  bool _isLoading = false;
  bool _isDeleting = false;
  bool _loaded = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _loadData() {
    if (_loaded) return;
    final profiles = ref.read(childProfilesProvider).valueOrNull ?? [];
    final child = profiles.where((p) => p.id == widget.childId).firstOrNull;
    if (child != null) {
      setState(() {
        _nameController.text = child.name;
        _birthDate = child.birthDate;
        _loaded = true;
      });
    }
  }

  int get _ageInMonths {
    if (_birthDate == null) return 0;
    final now = DateTime.now();
    return (now.year - _birthDate!.year) * 12 + now.month - _birthDate!.month;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? now,
      firstDate: DateTime(now.year - 6),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) {
      setState(() => _error = '이름을 입력해주세요');
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await SupabaseService.client.from('child_profiles').update({
        'name': _nameController.text.trim(),
        'birth_date': _birthDate?.toIso8601String().split('T')[0],
      }).eq('id', widget.childId);
      ref.invalidate(childProfilesProvider);
      if (mounted) context.pop();
    } catch (e) {
      setState(() => _error = '수정에 실패했습니다.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('아이 프로필 삭제'),
        content: const Text('정말 삭제하시겠습니까?\n관련된 모든 일기도 함께 삭제됩니다.'),
        actions: [
          TextButton(onPressed: () => ctx.pop(false), child: const Text('취소')),
          TextButton(
            onPressed: () => ctx.pop(true),
            child: const Text('삭제', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isDeleting = true);
    try {
      await SupabaseService.client
          .from('child_profiles')
          .delete()
          .eq('id', widget.childId);
      ref.invalidate(childProfilesProvider);
      if (mounted) context.pop();
    } catch (e) {
      setState(() => _error = '삭제에 실패했습니다.');
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('아이 정보 수정'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            onPressed: _isDeleting ? null : _delete,
            icon: _isDeleting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.delete_outline, color: AppColors.error),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.child_care_rounded,
                    size: 45, color: AppColors.primary),
              ),
            ),
            const SizedBox(height: 28),
            Text('이름', style: AppTextStyles.labelLarge),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: '아이 이름',
                prefixIcon: Icon(Icons.badge_outlined,
                    color: AppColors.primary.withValues(alpha: 0.6)),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('생년월일', style: AppTextStyles.labelLarge),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: AppColors.primaryLight.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today,
                        color: AppColors.primary.withValues(alpha: 0.6)),
                    const SizedBox(width: 12),
                    Text(
                      _birthDate != null
                          ? DateFormat('yyyy년 M월 d일').format(_birthDate!)
                          : '생년월일을 선택해주세요',
                      style: TextStyle(
                        fontSize: 15,
                        color: _birthDate != null
                            ? AppColors.textPrimary
                            : AppColors.textHint,
                      ),
                    ),
                    const Spacer(),
                    if (_birthDate != null)
                      Text('$_ageInMonths개월',
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(_error!,
                    style:
                        const TextStyle(color: AppColors.error, fontSize: 13)),
              ),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white))
                    : const Text('저장하기',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
