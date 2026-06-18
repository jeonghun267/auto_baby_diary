import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/providers/app_providers.dart';
import '../../core/providers/health_providers.dart';
import '../../core/utils/error_mapper.dart';
import '../../data/repositories/growth_repository.dart';

class AddGrowthScreen extends ConsumerStatefulWidget {
  const AddGrowthScreen({super.key});

  @override
  ConsumerState<AddGrowthScreen> createState() => _AddGrowthScreenState();
}

class _AddGrowthScreenState extends ConsumerState<AddGrowthScreen> {
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _headCircController = TextEditingController();
  final _noteController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _heightController.dispose();
    _weightController.dispose();
    _headCircController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
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
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _submit() async {
    if (_isLoading) return; // 중복 탭 방지

    final heightText = _heightController.text.trim();
    final weightText = _weightController.text.trim();

    if (heightText.isEmpty && weightText.isEmpty) {
      setState(() => _error = '키 또는 몸무게를 입력해주세요');
      return;
    }

    final height = heightText.isNotEmpty ? double.tryParse(heightText) : null;
    final weight = weightText.isNotEmpty ? double.tryParse(weightText) : null;

    if (heightText.isNotEmpty && height == null) {
      setState(() => _error = '키를 올바른 숫자로 입력해주세요');
      return;
    }
    if (weightText.isNotEmpty && weight == null) {
      setState(() => _error = '몸무게를 올바른 숫자로 입력해주세요');
      return;
    }

    final headCircText = _headCircController.text.trim();
    double? headCirc;
    if (headCircText.isNotEmpty) {
      headCirc = double.tryParse(headCircText);
      if (headCirc == null) {
        setState(() => _error = '머리둘레를 올바른 숫자로 입력해주세요');
        return;
      }
    }

    final child = ref.read(currentChildProvider);
    if (child == null) {
      setState(() => _error = '아이를 먼저 등록해주세요');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await ref.read(growthRepositoryProvider).addGrowthRecord(
            childId: child.id,
            recordedAt: _selectedDate,
            height: height,
            weight: weight,
            headCircumference: headCirc,
            note: _noteController.text.trim().isNotEmpty
                ? _noteController.text.trim()
                : null,
          );

      ref.invalidate(growthRecordsProvider(child.id));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('성장 기록이 저장되었습니다')),
        );
        context.pop();
      }
    } catch (e) {
      setState(() => _error = ErrorMapper.map(e, fallback: '저장에 실패했습니다.'));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  static const TextStyle _inputTextStyle = TextStyle(
    fontSize: 15,
    color: AppColors.textPrimary,
  );

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    String? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: AppColors.primary.withValues(alpha: 0.6)),
      suffixText: suffix,
      suffixStyle:
          AppTextStyles.labelLarge.copyWith(color: AppColors.textSecondary),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide:
            BorderSide(color: AppColors.primaryLight.withValues(alpha: 0.3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('성장 기록 추가'),
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
            // Icon
            Center(
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.straighten_rounded,
                  size: 50,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '성장 기록을 입력해주세요',
              textAlign: TextAlign.center,
              style: AppTextStyles.h3,
            ),
            const SizedBox(height: 4),
            Text(
              '키, 몸무게 중 하나 이상 입력해주세요',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall,
            ),
            const SizedBox(height: 32),

            // Date picker
            Text('측정일', style: AppTextStyles.labelLarge),
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
                      DateFormat('yyyy년 M월 d일').format(_selectedDate),
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Height
            Text('키', style: AppTextStyles.labelLarge),
            const SizedBox(height: 8),
            TextField(
              controller: _heightController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: _inputTextStyle,
              decoration: _inputDecoration(
                hint: '키를 입력해주세요',
                icon: Icons.height_rounded,
                suffix: 'cm',
              ),
            ),
            const SizedBox(height: 20),

            // Weight
            Text('몸무게', style: AppTextStyles.labelLarge),
            const SizedBox(height: 8),
            TextField(
              controller: _weightController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: _inputTextStyle,
              decoration: _inputDecoration(
                hint: '몸무게를 입력해주세요',
                icon: Icons.monitor_weight_outlined,
                suffix: 'kg',
              ),
            ),
            const SizedBox(height: 20),

            // Head circumference
            Text('머리둘레 (선택)', style: AppTextStyles.labelLarge),
            const SizedBox(height: 8),
            TextField(
              controller: _headCircController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: _inputTextStyle,
              decoration: _inputDecoration(
                hint: '머리둘레를 입력해주세요',
                icon: Icons.circle_outlined,
                suffix: 'cm',
              ),
            ),
            const SizedBox(height: 20),

            // Note
            Text('메모 (선택)', style: AppTextStyles.labelLarge),
            const SizedBox(height: 8),
            TextField(
              controller: _noteController,
              maxLines: 3,
              style: _inputTextStyle,
              decoration: _inputDecoration(
                hint: '메모를 입력해주세요',
                icon: Icons.notes_rounded,
              ),
            ),
            const SizedBox(height: 24),

            // Error
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  _error!,
                  style: const TextStyle(color: AppColors.error, fontSize: 13),
                ),
              ),

            // Submit button
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 2,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        '저장하기',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
