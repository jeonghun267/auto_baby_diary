import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/providers/app_providers.dart';
import '../../core/providers/health_providers.dart';
import '../../core/services/pdf_export_service.dart';

class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({super.key});

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  bool _includeGrowth = true;
  bool _includeVaccination = true;
  bool _includeMilestone = true;
  bool _isGenerating = false;

  @override
  Widget build(BuildContext context) {
    final child = ref.watch(currentChildProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('데이터 내보내기'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: child == null
          ? const Center(child: Text('아이 프로필을 먼저 등록해주세요.'))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Child info summary
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: AppColors.primaryLight,
                          child: Text(
                            child.name.isNotEmpty ? child.name[0] : '?',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(child.name, style: AppTextStyles.h3),
                              const SizedBox(height: 4),
                              Text(
                                '${child.ageInMonths}개월 | ${child.gender}',
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

                Text('포함할 항목', style: AppTextStyles.h3),
                const SizedBox(height: 8),

                // Checkboxes
                CheckboxListTile(
                  title: const Text('성장 기록 포함'),
                  subtitle: const Text('키, 몸무게, 머리둘레 기록'),
                  value: _includeGrowth,
                  activeColor: AppColors.primary,
                  onChanged: (v) => setState(() => _includeGrowth = v ?? true),
                ),
                CheckboxListTile(
                  title: const Text('예방접종 기록 포함'),
                  subtitle: const Text('접종 이력 및 병원 정보'),
                  value: _includeVaccination,
                  activeColor: AppColors.primary,
                  onChanged: (v) =>
                      setState(() => _includeVaccination = v ?? true),
                ),
                CheckboxListTile(
                  title: const Text('마일스톤 기록 포함'),
                  subtitle: const Text('발달 마일스톤 달성 현황'),
                  value: _includeMilestone,
                  activeColor: AppColors.primary,
                  onChanged: (v) =>
                      setState(() => _includeMilestone = v ?? true),
                ),
                const SizedBox(height: 32),

                // Generate button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _isGenerating ? null : () => _generatePdf(),
                    icon: _isGenerating
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.picture_as_pdf),
                    label: Text(_isGenerating ? 'PDF 생성 중...' : 'PDF 생성 및 공유'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _generatePdf() async {
    final child = ref.read(currentChildProvider);
    if (child == null) return;

    setState(() => _isGenerating = true);

    try {
      final growthAsync =
          await ref.read(growthRecordsProvider(child.id).future);
      final vaccinationsAsync =
          await ref.read(vaccinationsProvider(child.id).future);
      final milestonesAsync =
          await ref.read(milestonesProvider(child.id).future);

      final service = PdfExportService();
      final pdfBytes = await service.generateReport(
        child: child,
        growth: growthAsync,
        vaccinations: vaccinationsAsync,
        milestones: milestonesAsync,
        includeGrowth: _includeGrowth,
        includeVaccinations: _includeVaccination,
        includeMilestones: _includeMilestone,
      );

      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: '${child.name}_pediatric_report.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF 생성에 실패했습니다: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }
}
