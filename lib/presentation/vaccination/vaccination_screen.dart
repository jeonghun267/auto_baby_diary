import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/providers/app_providers.dart';
import '../../core/providers/health_providers.dart';
import '../../data/models/vaccination_record.dart';
import '../../data/repositories/vaccination_repository.dart';
import '../widgets/state_views.dart';

class VaccinationScreen extends ConsumerStatefulWidget {
  const VaccinationScreen({super.key});

  @override
  ConsumerState<VaccinationScreen> createState() => _VaccinationScreenState();
}

class _VaccinationScreenState extends ConsumerState<VaccinationScreen> {
  bool _isInitializing = false;

  static const _defaultVaccinations = [
    {
      'name': 'B형간염',
      'dose': 1,
      'description': 'B형간염 1차',
      'recommended_month': 0,
    },
    {
      'name': 'BCG(피내용)',
      'dose': 1,
      'description': '결핵 예방',
      'recommended_month': 0,
    },
    {
      'name': 'B형간염',
      'dose': 2,
      'description': 'B형간염 2차',
      'recommended_month': 1,
    },
    {
      'name': 'DTaP',
      'dose': 1,
      'description': '디프테리아/파상풍/백일해 1차',
      'recommended_month': 2,
    },
    {
      'name': 'IPV',
      'dose': 1,
      'description': '폴리오 1차',
      'recommended_month': 2,
    },
    {
      'name': 'Hib',
      'dose': 1,
      'description': 'b형헤모필루스인플루엔자 1차',
      'recommended_month': 2,
    },
    {
      'name': '폐렴구균',
      'dose': 1,
      'description': '폐렴구균 1차',
      'recommended_month': 2,
    },
    {
      'name': 'B형간염',
      'dose': 3,
      'description': 'B형간염 3차',
      'recommended_month': 6,
    },
    {
      'name': 'DTaP',
      'dose': 3,
      'description': '디프테리아/파상풍/백일해 3차',
      'recommended_month': 6,
    },
    {
      'name': 'IPV',
      'dose': 3,
      'description': '폴리오 3차',
      'recommended_month': 6,
    },
    {
      'name': 'Hib',
      'dose': 3,
      'description': 'b형헤모필루스인플루엔자 3차',
      'recommended_month': 6,
    },
    {
      'name': '폐렴구균',
      'dose': 3,
      'description': '폐렴구균 3차',
      'recommended_month': 6,
    },
    {
      'name': '인플루엔자',
      'dose': 1,
      'description': '인플루엔자 1차',
      'recommended_month': 6,
    },
    {
      'name': 'MMR',
      'dose': 1,
      'description': '홍역/유행성이하선염/풍진 1차',
      'recommended_month': 12,
    },
    {
      'name': '수두',
      'dose': 1,
      'description': '수두 1차',
      'recommended_month': 12,
    },
    {
      'name': 'A형간염',
      'dose': 1,
      'description': 'A형간염 1차',
      'recommended_month': 12,
    },
    {
      'name': 'Hib',
      'dose': 4,
      'description': 'b형헤모필루스인플루엔자 4차',
      'recommended_month': 12,
    },
    {
      'name': '폐렴구균',
      'dose': 4,
      'description': '폐렴구균 4차',
      'recommended_month': 12,
    },
    {
      'name': 'DTaP',
      'dose': 4,
      'description': '디프테리아/파상풍/백일해 4차',
      'recommended_month': 15,
    },
    {
      'name': 'A형간염',
      'dose': 2,
      'description': 'A형간염 2차',
      'recommended_month': 18,
    },
    {
      'name': '일본뇌염(불활성화)',
      'dose': 1,
      'description': '일본뇌염 1차',
      'recommended_month': 12,
    },
    {
      'name': '일본뇌염(불활성화)',
      'dose': 2,
      'description': '일본뇌염 2차',
      'recommended_month': 13,
    },
    {
      'name': 'DTaP',
      'dose': 5,
      'description': '디프테리아/파상풍/백일해 5차',
      'recommended_month': 48,
    },
    {
      'name': 'IPV',
      'dose': 4,
      'description': '폴리오 4차',
      'recommended_month': 48,
    },
    {
      'name': 'MMR',
      'dose': 2,
      'description': '홍역/유행성이하선염/풍진 2차',
      'recommended_month': 48,
    },
  ];

  String _monthLabel(int month) {
    if (month == 0) return '출생 시';
    if (month < 12) return '$month개월';
    if (month % 12 == 0) return '${month ~/ 12}세';
    return '${month ~/ 12}세 ${month % 12}개월';
  }

  @override
  Widget build(BuildContext context) {
    final child = ref.watch(currentChildProvider);
    final vaccinationsAsync = child != null
        ? ref.watch(vaccinationsProvider(child.id))
        : const AsyncValue<List<VaccinationRecord>>.data([]);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('예방접종'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: vaccinationsAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          onRetry: () {
            if (child != null) {
              ref.invalidate(vaccinationsProvider(child.id));
            }
          },
        ),
        data: (vaccinations) {
          if (vaccinations.isEmpty) {
            return _buildInitializeState(child);
          }
          return _buildContent(vaccinations, child!);
        },
      ),
      floatingActionButton: child != null
          ? FloatingActionButton(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              tooltip: '접종 추가',
              onPressed: () => _showAddVaccinationDialog(child),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Future<void> _showAddVaccinationDialog(dynamic child) async {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    int doseNumber = 1;
    int recommendedMonth = 0;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text('접종 추가'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('백신 이름', style: AppTextStyles.labelMedium),
                    const SizedBox(height: 6),
                    TextField(
                      controller: nameController,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: '예: 인플루엔자',
                        filled: true,
                        fillColor: AppColors.card,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('설명 (선택)', style: AppTextStyles.labelMedium),
                    const SizedBox(height: 6),
                    TextField(
                      controller: descriptionController,
                      decoration: InputDecoration(
                        hintText: '예: 인플루엔자 1차',
                        filled: true,
                        fillColor: AppColors.card,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('차수', style: AppTextStyles.labelMedium),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<int>(
                                initialValue: doseNumber,
                                items: List.generate(10, (i) => i + 1)
                                    .map((d) => DropdownMenuItem(
                                          value: d,
                                          child: Text('$d차'),
                                        ))
                                    .toList(),
                                onChanged: (v) =>
                                    setDialogState(() => doseNumber = v ?? 1),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: AppColors.card,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('권장 시기', style: AppTextStyles.labelMedium),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<int>(
                                initialValue: recommendedMonth,
                                isExpanded: true,
                                items: const [
                                  0,
                                  1,
                                  2,
                                  4,
                                  6,
                                  9,
                                  12,
                                  15,
                                  18,
                                  24,
                                  36,
                                  48,
                                  60,
                                  72,
                                ]
                                    .map((m) => DropdownMenuItem(
                                          value: m,
                                          child: Text(_monthLabelStatic(m)),
                                        ))
                                    .toList(),
                                onChanged: (v) => setDialogState(
                                    () => recommendedMonth = v ?? 0),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: AppColors.card,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('취소'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (nameController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('백신 이름을 입력해주세요')),
                      );
                      return;
                    }
                    Navigator.pop(ctx, true);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('추가'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != true || !mounted) return;

    try {
      await ref.read(vaccinationRepositoryProvider).addVaccination(
            childId: child.id,
            name: nameController.text.trim(),
            description: descriptionController.text.trim().isNotEmpty
                ? descriptionController.text.trim()
                : null,
            recommendedMonth: recommendedMonth,
            doseNumber: doseNumber,
          );
      ref.invalidate(vaccinationsProvider(child.id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('접종이 추가되었습니다')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('추가에 실패했습니다')),
        );
      }
    }
  }

  static String _monthLabelStatic(int month) {
    if (month == 0) return '출생 시';
    if (month < 12) return '$month개월';
    if (month % 12 == 0) return '${month ~/ 12}세';
    return '${month ~/ 12}세 ${month % 12}개월';
  }

  Widget _buildInitializeState(dynamic child) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.vaccines_rounded, size: 64, color: AppColors.textHint),
          const SizedBox(height: 16),
          Text(
            '예방접종 목록을 초기화하시겠습니까?',
            style: AppTextStyles.body2,
          ),
          const SizedBox(height: 8),
          Text(
            '국가 필수 예방접종 스케줄을 생성합니다',
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
            label: Text(_isInitializing ? '초기화 중...' : '접종 목록 초기화'),
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
      await ref.read(vaccinationRepositoryProvider).initializeVaccinations(
            child.id,
            _defaultVaccinations,
          );
      ref.invalidate(vaccinationsProvider(child.id));
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

  Widget _buildContent(List<VaccinationRecord> vaccinations, dynamic child) {
    final completedCount = vaccinations.where((v) => v.isCompleted).length;
    final total = vaccinations.length;
    final progress = total > 0 ? completedCount / total : 0.0;

    // Group by recommended_month
    final grouped = <int, List<VaccinationRecord>>{};
    for (final v in vaccinations) {
      grouped.putIfAbsent(v.recommendedMonth, () => []);
      grouped[v.recommendedMonth]!.add(v);
    }
    final sortedMonths = grouped.keys.toList()..sort();

    return Column(
      children: [
        // Summary
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
                  Text('접종 현황', style: AppTextStyles.labelLarge),
                  Text(
                    '$completedCount / $total 접종 완료',
                    style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.success,
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
                  valueColor: const AlwaysStoppedAnimation(AppColors.success),
                ),
              ),
            ],
          ),
        ),

        // Grouped list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            itemCount: sortedMonths.length,
            itemBuilder: (context, index) {
              final month = sortedMonths[index];
              final items = grouped[month]!;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      _monthLabel(month),
                      style: AppTextStyles.h3.copyWith(fontSize: 16),
                    ),
                  ),
                  ...items.map((v) => _buildVaccinationItem(v, child)),
                  const SizedBox(height: 8),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildVaccinationItem(VaccinationRecord vaccination, dynamic child) {
    final isCompleted = vaccination.isCompleted;
    final name = vaccination.name;
    final dose = vaccination.doseNumber;
    final description = vaccination.description ?? '';
    final hospital = vaccination.hospital;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isCompleted
              ? AppColors.success.withValues(alpha: 0.3)
              : AppColors.primaryLight.withValues(alpha: 0.2),
        ),
      ),
      color: isCompleted
          ? AppColors.success.withValues(alpha: 0.05)
          : AppColors.surface,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _toggleVaccination(vaccination, child),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Checkbox
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: isCompleted ? AppColors.success : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isCompleted ? AppColors.success : AppColors.textHint,
                    width: 2,
                  ),
                ),
                child: isCompleted
                    ? const Icon(Icons.check_rounded,
                        size: 18, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 14),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: AppTextStyles.labelLarge.copyWith(
                              color: isCompleted
                                  ? AppColors.textSecondary
                                  : AppColors.textPrimary,
                              decoration: isCompleted
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.secondary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$dose차',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.secondaryDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(description, style: AppTextStyles.bodySmall),
                    ],
                    if (isCompleted) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.check_circle_outline,
                              size: 14, color: AppColors.success),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat('yyyy.MM.dd').format(
                              vaccination.completedAt!,
                            ),
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.success,
                            ),
                          ),
                          if (hospital != null && hospital.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Icon(Icons.local_hospital_outlined,
                                size: 14, color: AppColors.textHint),
                            const SizedBox(width: 4),
                            Text(hospital, style: AppTextStyles.caption),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggleVaccination(
      VaccinationRecord vaccination, dynamic child) async {
    final repo = ref.read(vaccinationRepositoryProvider);

    if (vaccination.isCompleted) {
      try {
        await repo.unmarkCompleted(vaccination.id);
        ref.invalidate(vaccinationsProvider(child.id));
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('업데이트에 실패했습니다.')),
          );
        }
      }
      return;
    }

    final result = await _showCompletionDialog();
    if (result == null) return;

    try {
      await repo.markCompleted(
        id: vaccination.id,
        completedAt: DateTime.parse(result['date'] as String),
        hospital: result['hospital'] as String?,
      );
      ref.invalidate(vaccinationsProvider(child.id));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('업데이트에 실패했습니다.')),
        );
      }
    }
  }

  Future<Map<String, dynamic>?> _showCompletionDialog() async {
    final hospitalController = TextEditingController();
    DateTime selectedDate = DateTime.now();

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text('접종 완료', style: AppTextStyles.h3),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('접종일', style: AppTextStyles.labelMedium),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
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
                      if (picked != null) {
                        setDialogState(() => selectedDate = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.primaryLight.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today,
                              size: 18,
                              color: AppColors.primary.withValues(alpha: 0.6)),
                          const SizedBox(width: 8),
                          Text(
                            DateFormat('yyyy년 M월 d일').format(selectedDate),
                            style: AppTextStyles.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('병원명 (선택)', style: AppTextStyles.labelMedium),
                  const SizedBox(height: 8),
                  TextField(
                    controller: hospitalController,
                    decoration: InputDecoration(
                      hintText: '병원명을 입력해주세요',
                      filled: true,
                      fillColor: AppColors.card,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppColors.primaryLight.withValues(alpha: 0.3),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: AppColors.primary, width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    '취소',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx, {
                      'date': selectedDate.toIso8601String(),
                      'hospital': hospitalController.text.trim().isNotEmpty
                          ? hospitalController.text.trim()
                          : null,
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('완료'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
