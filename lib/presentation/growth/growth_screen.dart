import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/providers/app_providers.dart';
import '../../core/providers/health_providers.dart';
import '../../data/models/growth_record.dart';
import '../../data/repositories/growth_repository.dart';
import '../widgets/state_views.dart';

class GrowthScreen extends ConsumerStatefulWidget {
  const GrowthScreen({super.key});

  @override
  ConsumerState<GrowthScreen> createState() => _GrowthScreenState();
}

class _GrowthScreenState extends ConsumerState<GrowthScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const _tabs = ['키', '몸무게', '머리둘레'];
  static const _tabKeys = ['height', 'weight', 'head_circumference'];
  static const _tabUnits = ['cm', 'kg', 'cm'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final child = ref.watch(currentChildProvider);
    final recordsAsync = child != null
        ? ref.watch(growthRecordsProvider(child.id))
        : const AsyncValue<List<GrowthRecord>>.data([]);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('성장 기록'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, color: AppColors.primary),
            onPressed: () => context.push('/growth/add'),
          ),
        ],
      ),
      body: recordsAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          onRetry: () {
            if (child != null) {
              ref.invalidate(growthRecordsProvider(child.id));
            }
          },
        ),
        data: (records) {
          if (records.isEmpty) {
            return EmptyView(
              icon: Icons.straighten_rounded,
              title: '아직 성장 기록이 없어요',
              subtitle: '첫 번째 키·몸무게를 기록해보세요',
              actionLabel: '기록 추가',
              onAction: () => context.push('/growth/add'),
            );
          }
          return Column(
            children: [
              // Tab bar
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: AppColors.textSecondary,
                  labelStyle: AppTextStyles.labelLarge,
                  unselectedLabelStyle: AppTextStyles.labelMedium,
                  dividerColor: Colors.transparent,
                  tabs: _tabs.map((t) => Tab(text: t)).toList(),
                ),
              ),
              const SizedBox(height: 8),
              // Chart
              _buildChart(records, child!),
              const SizedBox(height: 8),
              // Records list
              Expanded(
                child: _buildRecordsList(records),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildChart(List<GrowthRecord> records, dynamic child) {
    final key = _tabKeys[_tabController.index];
    final unit = _tabUnits[_tabController.index];
    final birthDate = child.birthDate as DateTime;

    final spots = <FlSpot>[];
    for (final r in records) {
      final value = switch (key) {
        'height' => r.height,
        'weight' => r.weight,
        'head_circumference' => r.headCircumference,
        _ => null,
      };
      if (value == null) continue;
      final recordedAt = r.recordedAt;
      final monthAge = (recordedAt.year - birthDate.year) * 12 +
          recordedAt.month -
          birthDate.month +
          recordedAt.day / 30.0;
      spots.add(FlSpot(monthAge, value));
    }

    if (spots.isEmpty) {
      return Container(
        height: 200,
        margin: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Text(
            '${_tabs[_tabController.index]} 데이터가 없습니다',
            style: AppTextStyles.bodySmall,
          ),
        ),
      );
    }

    spots.sort((a, b) => a.x.compareTo(b.x));

    final minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final yPadding = (maxY - minY) * 0.15;

    return Container(
      height: 200,
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
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
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: _calcInterval(minY, maxY),
            getDrawingHorizontalLine: (value) => FlLine(
              color: AppColors.textHint.withValues(alpha: 0.2),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                interval: _calcXInterval(spots),
                getTitlesWidget: (value, meta) => Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${value.toInt()}개월',
                    style: AppTextStyles.caption,
                  ),
                ),
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) => Text(
                  value.toStringAsFixed(1),
                  style: AppTextStyles.caption,
                ),
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          minY: spots.length == 1 ? minY - 1 : minY - yPadding,
          maxY: spots.length == 1 ? maxY + 1 : maxY + yPadding,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              preventCurveOverShooting: true,
              color: AppColors.primary,
              barWidth: 3,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) =>
                    FlDotCirclePainter(
                  radius: 4,
                  color: AppColors.primary,
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                color: AppColors.primary.withValues(alpha: 0.1),
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (touchedSpots) => touchedSpots.map((spot) {
                return LineTooltipItem(
                  '${spot.y.toStringAsFixed(1)} $unit',
                  AppTextStyles.labelLarge.copyWith(color: Colors.white),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  double _calcInterval(double minY, double maxY) {
    final range = maxY - minY;
    if (range <= 0) return 1;
    if (range < 5) return 1;
    if (range < 20) return 5;
    return 10;
  }

  double _calcXInterval(List<FlSpot> spots) {
    if (spots.length < 2) return 1;
    final range = spots.last.x - spots.first.x;
    if (range <= 6) return 1;
    if (range <= 12) return 2;
    if (range <= 24) return 3;
    return 6;
  }

  Widget _buildRecordsList(List<GrowthRecord> records) {
    final reversed = records.reversed.toList();
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      itemCount: reversed.length,
      itemBuilder: (context, index) {
        final r = reversed[index];
        final date = r.recordedAt;
        final height = r.height;
        final weight = r.weight;
        final headCirc = r.headCircumference;
        final note = r.note;

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
                color: AppColors.primaryLight.withValues(alpha: 0.3)),
          ),
          color: AppColors.surface,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.straighten_rounded,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('yyyy.MM.dd').format(date),
                        style: AppTextStyles.captionBold.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          if (height != null)
                            _metricChip(
                                '${(height as num).toStringAsFixed(1)} cm'),
                          if (weight != null)
                            _metricChip(
                                '${(weight as num).toStringAsFixed(1)} kg'),
                          if (headCirc != null)
                            _metricChip(
                                '${(headCirc as num).toStringAsFixed(1)} cm'),
                        ],
                      ),
                      if (note != null && note.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          note,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.textHint,
                    size: 20,
                  ),
                  onPressed: () => _deleteRecord(r.id),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _metricChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: AppTextStyles.labelMedium),
    );
  }

  Future<void> _deleteRecord(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('기록 삭제'),
        content: const Text('이 성장 기록을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(growthRepositoryProvider).deleteGrowthRecord(id);
      final child = ref.read(currentChildProvider);
      if (child != null) {
        ref.invalidate(growthRecordsProvider(child.id));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('삭제에 실패했습니다.')),
        );
      }
    }
  }
}
