import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/supabase_service.dart';
import '../../core/utils/error_mapper.dart';
import '../../data/repositories/child_profile_repository.dart';

// signup_screen 에서 임시 저장한 아이 정보를 받기 위한 키
const _kPendingChildName = 'pending_child_name';
const _kPendingChildBirthDate = 'pending_child_birth_date';

class AddChildScreen extends ConsumerStatefulWidget {
  const AddChildScreen({super.key});

  @override
  ConsumerState<AddChildScreen> createState() => _AddChildScreenState();
}

class _AddChildScreenState extends ConsumerState<AddChildScreen> {
  final _nameController = TextEditingController();
  DateTime? _birthDate;
  String _gender = '남아';
  bool _isLoading = false;
  String? _error;
  File? _profileImage;

  @override
  void initState() {
    super.initState();
    _restorePendingChildInfo();
  }

  /// 가입 시 입력했던 아이 정보가 SharedPreferences에 있으면 가져와서 채움
  Future<void> _restorePendingChildInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingName = prefs.getString(_kPendingChildName);
      final pendingBirth = prefs.getString(_kPendingChildBirthDate);
      if (!mounted) return;
      if (pendingName != null && pendingName.isNotEmpty) {
        _nameController.text = pendingName;
      }
      if (pendingBirth != null && pendingBirth.isNotEmpty) {
        try {
          setState(() => _birthDate = DateTime.parse(pendingBirth));
        } catch (_) {}
      }
    } catch (_) {
      // prefs 실패 시 그냥 비워둠
    }
  }

  Future<void> _clearPendingChildInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kPendingChildName);
      await prefs.remove(_kPendingChildBirthDate);
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  int get _ageInMonths {
    if (_birthDate == null) return 0;
    final now = DateTime.now();
    return (now.year - _birthDate!.year) * 12 + now.month - _birthDate!.month;
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
    );
    if (image != null) {
      setState(() => _profileImage = File(image.path));
    }
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
              surface: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _submit() async {
    if (_isLoading) return; // 중복 탭 방지

    if (_nameController.text.trim().isEmpty) {
      setState(() => _error = '아이 이름을 입력해주세요');
      return;
    }
    if (_birthDate == null) {
      setState(() => _error = '생년월일을 선택해주세요');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final user = SupabaseService.auth.currentUser;
      if (user == null) throw Exception('로그인이 필요합니다');

      final repo = ref.read(childProfileRepositoryProvider);
      await repo.createChild(
        userId: user.id,
        name: _nameController.text.trim(),
        birthDate: _birthDate!,
        gender: _gender,
        profileImage: _profileImage,
      );

      // 가입 시 임시 저장한 아이 정보 정리
      await _clearPendingChildInfo();

      // providers 새로고침
      ref.invalidate(childProfilesProvider);

      if (mounted) {
        // 첫 아이면 홈으로, 그 외엔 pop
        final myChildren = await repo.getMyChildren(user.id);
        if (mounted) {
          if (myChildren.length <= 1) {
            context.go('/home');
          } else {
            context.pop();
          }
        }
      }
    } catch (e) {
      debugPrint('[AddChild] 등록 실패: $e');
      // Storage 실패 시 선택된 이미지 초기화로 재시도 가능하게
      final raw = e.toString().toLowerCase();
      if (raw.contains('storage') || raw.contains('bucket')) {
        if (mounted) setState(() => _profileImage = null);
      }
      setState(() => _error = ErrorMapper.mapMedia(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('아이 등록'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 프로필 사진
            Center(
              child: GestureDetector(
                onTap: _pickPhoto,
                child: Stack(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight.withValues(alpha: 0.3),
                        shape: BoxShape.circle,
                        image: _profileImage != null
                            ? DecorationImage(
                                image: FileImage(_profileImage!),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: _profileImage == null
                          ? const Icon(
                              Icons.child_care_rounded,
                              size: 50,
                              color: AppColors.primary,
                            )
                          : null,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '아이 정보를 알려주세요',
              textAlign: TextAlign.center,
              style: AppTextStyles.h3,
            ),
            const SizedBox(height: 4),
            Text(
              '정확한 발달 분석을 위해 필요해요',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall,
            ),
            const SizedBox(height: 32),

            // 이름
            Text('이름', style: AppTextStyles.labelLarge),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: '아이 이름을 입력해주세요',
                prefixIcon: Icon(Icons.badge_outlined,
                    color: AppColors.primary.withValues(alpha: 0.6)),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                      color: AppColors.primaryLight.withValues(alpha: 0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 생년월일
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
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '현재 $_ageInMonths개월',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 성별
            Text('성별', style: AppTextStyles.labelLarge),
            const SizedBox(height: 8),
            Row(
              children: ['남아', '여아'].map((g) {
                final selected = _gender == g;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _gender = g),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: EdgeInsets.only(
                          right: g == '남아' ? 8 : 0, left: g == '여아' ? 8 : 0),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.primary : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: selected
                              ? AppColors.primary
                              : AppColors.primaryLight.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '${g == "남아" ? "👦" : "👧"} $g',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color:
                                selected ? Colors.white : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // 에러
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(_error!,
                    style:
                        const TextStyle(color: AppColors.error, fontSize: 13)),
              ),

            // 등록 버튼
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 2,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white),
                      )
                    : const Text('등록하기',
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
