import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/gemini_service.dart';
import '../../data/repositories/diary_repository.dart';

/// 월간 AI 발달 리포트 화면
class MonthlyReportScreen extends ConsumerStatefulWidget {
  const MonthlyReportScreen({super.key});

  @override
  ConsumerState<MonthlyReportScreen> createState() =>
      _MonthlyReportScreenState();
}

class _MonthlyReportScreenState extends ConsumerState<MonthlyReportScreen> {
  late DateTime _selectedMonth;
  bool _isLoading = false;
  String? _errorMessage;

  // Cache: year-month key -> report text
  final Map<String, String> _reportCache = {};

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month);
  }

  String get _cacheKey => '${_selectedMonth.year}-${_selectedMonth.month}';

  String get _monthLabel => '${_selectedMonth.year}년 ${_selectedMonth.month}월';

  void _changeMonth(int delta) {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + delta,
      );
    });
  }

  Future<void> _generateReport() async {
    if (_reportCache.containsKey(_cacheKey)) return;

    final child = ref.read(currentChildProvider);
    if (child == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('먼저 아이 프로필을 등록해주세요')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final diaryRepo = ref.read(diaryRepositoryProvider);
      final entries = await diaryRepo.getDiaryEntries(child.id);

      // Filter entries for selected month
      final monthEntries = entries.where((e) {
        return e.recordedAt.year == _selectedMonth.year &&
            e.recordedAt.month == _selectedMonth.month;
      }).toList();

      if (monthEntries.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = '이번 달에 작성된 일기가 없습니다.\n일기를 작성한 후 리포트를 생성해보세요.';
        });
        return;
      }

      final diaryTexts = monthEntries
          .map((e) => e.finalText ?? e.llmDraft ?? '')
          .where((t) => t.isNotEmpty)
          .toList();

      final emotionList = monthEntries
          .map((e) => e.emotionSummary)
          .where((e) => e != null)
          .toList();

      final milestones = monthEntries
          .map((e) => e.milestoneDetected)
          .where((m) => m != null)
          .map((m) => m!)
          .toList();

      final gemini = ref.read(geminiServiceProvider);
      final report = await gemini.generateMonthlyReport(
        monthlyData: {
          'diary_texts': diaryTexts,
          'child_age_months': child.ageInMonths,
          'growth_data': <String, dynamic>{},
          'milestones': milestones,
          'emotions': emotionList,
        },
      );

      setState(() {
        _reportCache[_cacheKey] = report;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = '리포트 생성 중 오류가 발생했습니다.\n잠시 후 다시 시도해주세요.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cachedReport = _reportCache[_cacheKey];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('월간 AI 리포트')),
      body: Column(
        children: [
          // Month selector
          _buildMonthSelector(),
          const Divider(height: 1),

          // Content
          Expanded(
            child: _isLoading
                ? _buildLoadingState()
                : cachedReport != null
                    ? _buildReportContent(cachedReport)
                    : _buildEmptyState(),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => _changeMonth(-1),
          ),
          const SizedBox(width: 8),
          Text(
            _monthLabel,
            style: AppTextStyles.h3,
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => _changeMonth(1),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppColors.primary),
          SizedBox(height: 20),
          Text(
            'AI가 리포트를 생성하고 있어요...',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '잠시만 기다려 주세요',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textHint,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.auto_awesome,
              size: 64,
              color: AppColors.primaryLight,
            ),
            const SizedBox(height: 20),
            Text(
              _monthLabel,
              style: AppTextStyles.h2,
            ),
            const SizedBox(height: 12),
            if (_errorMessage != null)
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              )
            else
              Text(
                'AI가 한 달간의 일기를 분석하여\n발달 리포트를 생성해 드려요',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _generateReport,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('리포트 생성'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportContent(String report) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildReportSection(
            icon: Icons.summarize,
            title: '이번 달 요약',
            color: AppColors.primary,
          ),
          _buildReportSection(
            icon: Icons.emoji_emotions,
            title: '감정 분석',
            color: AppColors.emotionHappy,
          ),
          _buildReportSection(
            icon: Icons.trending_up,
            title: '성장 포인트',
            color: AppColors.success,
          ),
          _buildReportSection(
            icon: Icons.visibility,
            title: '다음 달 예측',
            color: AppColors.secondary,
          ),
          _buildReportSection(
            icon: Icons.lightbulb_outline,
            title: '양육 팁',
            color: AppColors.emotionSurprised,
          ),
          const SizedBox(height: 8),
          // Full report text
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                report,
                style: AppTextStyles.bodyMedium.copyWith(height: 1.8),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Regenerate button
          Center(
            child: TextButton.icon(
              onPressed: () {
                _reportCache.remove(_cacheKey);
                _generateReport();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('다시 생성하기'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildReportSection({
    required IconData icon,
    required String title,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Text(
            title,
            style: AppTextStyles.labelLarge.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
