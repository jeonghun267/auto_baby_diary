import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/services/supabase_service.dart';
import '../../core/utils/error_mapper.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/child_profile_repository.dart';

/// 이메일 인증 후 add-child 화면에서 prefill하기 위한 키
const _kPendingChildName = 'pending_child_name';
const _kPendingChildBirthDate = 'pending_child_birth_date';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _childNameController = TextEditingController();
  DateTime? _childBirthDate;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _errorMessage;

  // 약관 동의
  bool _agreeTerms = false;
  bool _agreePrivacy = false;
  bool _agreeAll = false;

  // Step tracking: 0 = account, 1 = terms, 2 = child info
  int _currentStep = 0;

  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;
  late final AnimationController _slideController;
  late final Animation<Offset> _slideAnimation;
  late final AnimationController _stepTransitionController;
  late final Animation<double> _stepFadeAnimation;
  late final Animation<Offset> _stepSlideAnimation;
  late final AnimationController _loadingPulseController;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _stepTransitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _stepFadeAnimation = CurvedAnimation(
      parent: _stepTransitionController,
      curve: Curves.easeOut,
    );
    _stepSlideAnimation = Tween<Offset>(
      begin: const Offset(0.3, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _stepTransitionController,
      curve: Curves.easeOutCubic,
    ));

    _loadingPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _fadeController.forward();
    _slideController.forward();
    _stepTransitionController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _childNameController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    _stepTransitionController.dispose();
    _loadingPulseController.dispose();
    super.dispose();
  }

  void _toggleAgreeAll(bool? value) {
    setState(() {
      _agreeAll = value ?? false;
      _agreeTerms = _agreeAll;
      _agreePrivacy = _agreeAll;
    });
  }

  void _goToNextStep() {
    if (_currentStep == 0) {
      // Validate account fields
      if (_emailController.text.isEmpty ||
          !RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$')
              .hasMatch(_emailController.text)) {
        setState(() => _errorMessage = '올바른 이메일을 입력해주세요');
        return;
      }
      if (_passwordController.text.length < 6) {
        setState(() => _errorMessage = '비밀번호는 6자 이상이어야 합니다');
        return;
      }
      if (_passwordController.text != _confirmPasswordController.text) {
        setState(() => _errorMessage = '비밀번호가 일치하지 않습니다');
        return;
      }
      setState(() {
        _errorMessage = null;
        _currentStep = 1;
      });
      _stepTransitionController.reset();
      _stepTransitionController.forward();
    } else if (_currentStep == 1) {
      // Validate terms
      if (!_agreeTerms || !_agreePrivacy) {
        setState(() => _errorMessage = '필수 약관에 모두 동의해주세요');
        return;
      }
      setState(() {
        _errorMessage = null;
        _currentStep = 2;
      });
      _stepTransitionController.reset();
      _stepTransitionController.forward();
    }
  }

  void _goToPrevStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep = _currentStep - 1;
        _errorMessage = null;
      });
      _stepTransitionController.reset();
      _stepTransitionController.forward();
    } else {
      context.go('/login');
    }
  }

  Future<void> _handleSignup() async {
    // Validate child info
    if (_childNameController.text.trim().isEmpty) {
      setState(() => _errorMessage = '아이 이름을 입력해주세요');
      return;
    }
    if (_childBirthDate == null) {
      setState(() => _errorMessage = '아이의 생년월일을 선택해주세요');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await ref.read(authRepositoryProvider).signUp(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );

      // 세션이 없으면 이메일 확인이 필요한 상태
      if (response.session == null) {
        // 입력한 아이 정보를 임시 저장 → 로그인 후 add-child에서 자동으로 채워짐
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(
            _kPendingChildName,
            _childNameController.text.trim(),
          );
          await prefs.setString(
            _kPendingChildBirthDate,
            _childBirthDate!.toIso8601String(),
          );
        } catch (_) {
          // SharedPreferences 실패해도 가입 흐름은 계속
        }

        if (mounted) {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text('이메일을 확인해주세요'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_emailController.text.trim()}으로\n인증 메일을 보냈어요.',
                    style: const TextStyle(height: 1.5),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '메일의 링크를 클릭한 뒤 로그인해주세요.\n'
                      '입력하신 아이 정보는 저장되어 있어요.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    context.go('/login');
                  },
                  child: const Text('확인'),
                ),
              ],
            ),
          );
        }
        return;
      }

      // 세션이 있으면 바로 아이 프로필 저장 후 홈으로
      final user = SupabaseService.auth.currentUser;
      if (user != null &&
          _childNameController.text.trim().isNotEmpty &&
          _childBirthDate != null) {
        await ref.read(childProfileRepositoryProvider).createChild(
              userId: user.id,
              name: _childNameController.text.trim(),
              birthDate: _childBirthDate!,
            );
        if (mounted) context.go('/home');
      } else {
        // 아이 정보 누락 시에만 add-child로
        if (mounted) context.go('/profile/add-child');
      }
    } on AuthException catch (e) {
      setState(() => _errorMessage = ErrorMapper.mapSignup(e));
    } catch (e) {
      setState(() => _errorMessage = ErrorMapper.mapSignup(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _childBirthDate ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _childBirthDate = picked);
    }
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: AppColors.textHint,
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
      prefixIcon: Container(
        margin: const EdgeInsets.only(left: 12, right: 8),
        child: Icon(
          icon,
          color: AppColors.primary.withValues(alpha: 0.6),
          size: 22,
        ),
      ),
      prefixIconConstraints: const BoxConstraints(minWidth: 48),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: AppColors.primaryLight.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.error, width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFF0F5),
              Color(0xFFFFF8F0),
              Color(0xFFFFFDF7),
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Column(
                children: [
                  _buildAppBar(),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 8),
                            _buildStepIndicator(),
                            const SizedBox(height: 28),
                            _buildHeader(),
                            const SizedBox(height: 32),
                            FadeTransition(
                              opacity: _stepFadeAnimation,
                              child: SlideTransition(
                                position: _stepSlideAnimation,
                                child: _currentStep == 0
                                    ? _buildAccountStep()
                                    : _currentStep == 1
                                        ? _buildTermsStep()
                                        : _buildChildInfoStep(),
                              ),
                            ),
                            if (_errorMessage != null) ...[
                              const SizedBox(height: 16),
                              _buildErrorMessage(),
                            ],
                            const SizedBox(height: 28),
                            _buildActionButton(),
                            const SizedBox(height: 24),
                            if (_currentStep == 0) _buildLoginLink(),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            onPressed: _goToPrevStep,
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: AppColors.textPrimary,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildStepDot(0),
        _buildStepLine(1),
        _buildStepDot(1),
        _buildStepLine(2),
        _buildStepDot(2),
      ],
    );
  }

  Widget _buildStepLine(int afterStep) {
    return Container(
      width: 32,
      height: 2,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(1),
        color: _currentStep >= afterStep
            ? AppColors.primary
            : AppColors.primaryLight.withValues(alpha: 0.3),
      ),
    );
  }

  Widget _buildStepDot(int step) {
    final isActive = _currentStep >= step;
    final isCurrent = _currentStep == step;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      width: isCurrent ? 32 : 12,
      height: 12,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: isActive
            ? AppColors.primary
            : AppColors.primaryLight.withValues(alpha: 0.3),
        boxShadow: isCurrent
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Text(
            _currentStep == 0
                ? AppStrings.signup
                : _currentStep == 1
                    ? '약관 동의'
                    : '아이 정보 입력',
            key: ValueKey(_currentStep),
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
        ),
        const SizedBox(height: 8),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Text(
            _currentStep == 0
                ? '아이의 특별한 순간을 기록해보세요'
                : _currentStep == 1
                    ? '서비스 이용을 위해 약관에 동의해주세요'
                    : '우리 아이의 정보를 알려주세요',
            key: ValueKey('subtitle_$_currentStep'),
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary.withValues(alpha: 0.8),
              fontWeight: FontWeight.w400,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAccountStep() {
    return Column(
      children: [
        _buildFieldContainer(
          child: TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
            decoration: _inputDecoration(
              label: AppStrings.email,
              icon: Icons.email_rounded,
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildFieldContainer(
          child: TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
            decoration: _inputDecoration(
              label: AppStrings.password,
              icon: Icons.lock_rounded,
              suffixIcon: GestureDetector(
                onTap: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
                child: Container(
                  margin: const EdgeInsets.only(right: 12),
                  child: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    color: AppColors.textHint,
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildFieldContainer(
          child: TextFormField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirm,
            style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
            decoration: _inputDecoration(
              label: AppStrings.passwordConfirm,
              icon: Icons.lock_outline_rounded,
              suffixIcon: GestureDetector(
                onTap: () => setState(() => _obscureConfirm = !_obscureConfirm),
                child: Container(
                  margin: const EdgeInsets.only(right: 12),
                  child: Icon(
                    _obscureConfirm
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    color: AppColors.textHint,
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTermsStep() {
    return Column(
      children: [
        // 전체 동의
        Container(
          decoration: BoxDecoration(
            color: _agreeAll
                ? AppColors.primary.withValues(alpha: 0.08)
                : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _agreeAll
                  ? AppColors.primary.withValues(alpha: 0.3)
                  : AppColors.primaryLight.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: CheckboxListTile(
            value: _agreeAll,
            onChanged: _toggleAgreeAll,
            activeColor: AppColors.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              '전체 동의',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            subtitle: Text(
              '서비스 이용약관 및 개인정보 처리방침에 동의합니다',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            controlAffinity: ListTileControlAffinity.leading,
          ),
        ),
        const SizedBox(height: 12),

        // 이용약관 동의 (필수)
        _buildTermsItem(
          title: '서비스 이용약관 동의',
          required: true,
          value: _agreeTerms,
          onChanged: (v) {
            setState(() {
              _agreeTerms = v ?? false;
              _agreeAll = _agreeTerms && _agreePrivacy;
            });
          },
          onDetail: () => _showTermsDetail(
            '서비스 이용약관',
            '아기일기 서비스 이용약관\n\n'
                '제1조 (목적)\n'
                '이 약관은 아기일기(이하 "서비스")의 이용 조건 및 절차, '
                '이용자와 서비스 제공자의 권리, 의무 및 책임사항을 규정함을 목적으로 합니다.\n\n'
                '제2조 (서비스 내용)\n'
                '서비스는 AI 기반 육아일기 자동 작성, 아이 감정 분석, '
                '발달 리포트 제공 등의 기능을 포함합니다.\n\n'
                '제3조 (이용자의 의무)\n'
                '이용자는 서비스 이용 시 관계법령, 이 약관의 규정을 준수하여야 합니다.\n\n'
                '제4조 (서비스 변경 및 중단)\n'
                '서비스 제공자는 서비스의 내용을 변경하거나 중단할 수 있으며, '
                '이 경우 사전에 공지합니다.',
          ),
        ),
        const SizedBox(height: 8),

        // 개인정보 처리방침 동의 (필수)
        _buildTermsItem(
          title: '개인정보 처리방침 동의',
          required: true,
          value: _agreePrivacy,
          onChanged: (v) {
            setState(() {
              _agreePrivacy = v ?? false;
              _agreeAll = _agreeTerms && _agreePrivacy;
            });
          },
          onDetail: () => _showTermsDetail(
            '개인정보 처리방침',
            '아기일기 개인정보 처리방침\n\n'
                '1. 수집하는 개인정보 항목\n'
                '- 이메일 주소, 비밀번호 (회원가입)\n'
                '- 아이 이름, 생년월일 (서비스 이용)\n'
                '- 사진, 동영상, 음성 메모 (일기 작성)\n\n'
                '2. 개인정보의 수집 및 이용 목적\n'
                '- AI 기반 육아일기 자동 작성\n'
                '- 아이 감정 분석 및 발달 리포트 제공\n'
                '- 서비스 개선 및 맞춤형 콘텐츠 제공\n\n'
                '3. 개인정보의 보유 및 이용기간\n'
                '회원 탈퇴 시까지 보유하며, 탈퇴 요청 시 즉시 삭제합니다.\n\n'
                '4. 개인정보의 제3자 제공\n'
                '원칙적으로 이용자의 동의 없이 제3자에게 제공하지 않습니다.',
          ),
        ),
      ],
    );
  }

  Widget _buildTermsItem({
    required String title,
    required bool required,
    required bool value,
    required ValueChanged<bool?> onChanged,
    required VoidCallback onDetail,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.primaryLight.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Checkbox(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primary,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(!value),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        required ? '필수' : '선택',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: required
                              ? AppColors.primary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: onDetail,
            icon: Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textHint,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  void _showTermsDetail(String title, String content) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (ctx, scrollController) => Column(
          children: [
            // 핸들
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textHint,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.all(20),
                child: Text(
                  content,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.8,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChildInfoStep() {
    return Column(
      children: [
        // Profile photo placeholder
        Center(
          child: GestureDetector(
            onTap: () {
              // TODO: Pick profile photo
            },
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primaryLight.withValues(alpha: 0.5),
                    AppColors.primary.withValues(alpha: 0.3),
                  ],
                ),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  width: 2.5,
                  strokeAlign: BorderSide.strokeAlignOutside,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    Icons.child_care_rounded,
                    size: 44,
                    color: AppColors.primary.withValues(alpha: 0.6),
                  ),
                  Positioned(
                    bottom: 2,
                    right: 2,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.camera_alt_rounded,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '프로필 사진 추가',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 24),
        // Child name
        _buildFieldContainer(
          child: TextFormField(
            controller: _childNameController,
            style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
            decoration: _inputDecoration(
              label: '아이 이름',
              icon: Icons.face_rounded,
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Birth date
        _buildFieldContainer(
          child: GestureDetector(
            onTap: _pickBirthDate,
            child: AbsorbPointer(
              child: TextFormField(
                style:
                    const TextStyle(fontSize: 15, color: AppColors.textPrimary),
                decoration: _inputDecoration(
                  label: '생년월일',
                  icon: Icons.cake_rounded,
                  suffixIcon: Container(
                    margin: const EdgeInsets.only(right: 12),
                    child: Icon(
                      Icons.calendar_today_rounded,
                      color: AppColors.primary.withValues(alpha: 0.6),
                      size: 20,
                    ),
                  ),
                ),
                controller: TextEditingController(
                  text: _childBirthDate != null
                      ? DateFormat('yyyy년 M월 d일').format(_childBirthDate!)
                      : '',
                )..selection = const TextSelection.collapsed(offset: 0),
                readOnly: true,
              ),
            ),
          ),
        ),
        if (_childBirthDate != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.secondary.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: AppColors.secondaryDark,
                ),
                const SizedBox(width: 8),
                Text(
                  '현재 ${_calculateAge()}',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.secondaryDark,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  String _calculateAge() {
    if (_childBirthDate == null) return '';
    final now = DateTime.now();
    final months = (now.year - _childBirthDate!.year) * 12 +
        now.month -
        _childBirthDate!.month;
    if (months < 1) return '신생아';
    if (months < 12) return '$months개월';
    final years = months ~/ 12;
    final remainMonths = months % 12;
    if (remainMonths == 0) return '$years세';
    return '$years세 $remainMonths개월';
  }

  Widget _buildFieldContainer({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.error.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: AppColors.error, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage!,
              style: TextStyle(
                color: AppColors.error,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton() {
    final isLastStep = _currentStep == 2;
    return AnimatedBuilder(
      animation: _loadingPulseController,
      builder: (context, child) {
        return Container(
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: _isLoading
                  ? [
                      AppColors.primary.withValues(
                          alpha: 0.7 + 0.3 * _loadingPulseController.value),
                      AppColors.primaryLight.withValues(
                          alpha: 0.7 + 0.3 * _loadingPulseController.value),
                    ]
                  : [
                      AppColors.primary,
                      AppColors.primaryLight,
                    ],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
                spreadRadius: -2,
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _isLoading
                  ? null
                  : isLastStep
                      ? _handleSignup
                      : _goToNextStep,
              child: Center(
                child: _isLoading
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '가입 중...',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withValues(alpha: 0.9),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            isLastStep ? '가입 완료' : '다음',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                          if (!isLastStep) ...[
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.arrow_forward_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ],
                        ],
                      ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoginLink() {
    return Center(
      child: GestureDetector(
        onTap: () => context.go('/login'),
        child: RichText(
          text: TextSpan(
            text: '${AppStrings.hasAccount} ',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w400,
            ),
            children: [
              TextSpan(
                text: AppStrings.login,
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.underline,
                  decorationColor: AppColors.primary.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
