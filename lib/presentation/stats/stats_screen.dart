import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/providers/app_providers.dart';
import '../../core/providers/health_providers.dart';
import '../../data/models/diary_entry.dart';
import '../../data/models/growth_record.dart';

class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('통계'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: '감정 분석'),
            Tab(text: '성장 차트'),
            Tab(text: '베스트 표정'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _EmotionAnalysisTab(),
          _GrowthChartTab(),
          _BestExpressionsTab(),
        ],
      ),
    );
  }
}

// ─── Tab 1: Emotion Analysis ──────────────────────────
class _EmotionAnalysisTab extends ConsumerWidget {
  const _EmotionAnalysisTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final child = ref.watch(currentChildProvider);
    if (child == null) {
      return const Center(child: Text('아이 프로필을 먼저 등록해주세요.'));
    }

    final diariesAsync = ref.watch(diaryListProvider(child.id));

    return diariesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('오류가 발생했습니다: $e')),
      data: (diaries) {
        final monthlyData = _groupByMonth(diaries);
        if (monthlyData.isEmpty) {
          return const Center(child: Text('감정 데이터가 없습니다.'));
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('월별 감정 분포', style: AppTextStyles.h3),
              const SizedBox(height: 16),
              SizedBox(
                height: monthlyData.length * 60.0 + 40,
                child: _buildEmotionBarChart(monthlyData),
              ),
              const SizedBox(height: 24),
              _buildLegend(),
            ],
          ),
        );
      },
    );
  }

  Map<String, Map<String, int>> _groupByMonth(List<DiaryEntry> diaries) {
    final result = <String, Map<String, int>>{};
    for (final d in diaries) {
      if (d.emotionSummary == null) continue;
      final monthKey = DateFormat('yyyy-MM').format(d.recordedAt);
      result.putIfAbsent(
          monthKey,
          () => {
                'happy': 0,
                'crying': 0,
                'surprised': 0,
                'neutral': 0,
              });
      final emotion = d.emotionSummary!;
      if (result[monthKey]!.containsKey(emotion)) {
        result[monthKey]![emotion] = result[monthKey]![emotion]! + 1;
      } else {
        result[monthKey]!['neutral'] = result[monthKey]!['neutral']! + 1;
      }
    }
    // Sort by month
    final sorted = Map.fromEntries(
      result.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
    return sorted;
  }

  Widget _buildEmotionBarChart(Map<String, Map<String, int>> data) {
    final months = data.keys.toList();

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        barTouchData: BarTouchData(enabled: true),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= months.length) {
                  return const SizedBox.shrink();
                }
                final parts = months[idx].split('-');
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${parts[1]}월',
                    style: const TextStyle(fontSize: 10),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) => Text(
                value.toInt().toString(),
                style: const TextStyle(fontSize: 10),
              ),
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        barGroups: List.generate(months.length, (i) {
          final counts = data[months[i]]!;
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: (counts['happy'] ?? 0).toDouble(),
                color: AppColors.emotionHappy,
                width: 8,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(4)),
              ),
              BarChartRodData(
                toY: (counts['crying'] ?? 0).toDouble(),
                color: AppColors.emotionCrying,
                width: 8,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(4)),
              ),
              BarChartRodData(
                toY: (counts['surprised'] ?? 0).toDouble(),
                color: AppColors.emotionSurprised,
                width: 8,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(4)),
              ),
              BarChartRodData(
                toY: (counts['neutral'] ?? 0).toDouble(),
                color: AppColors.emotionNeutral,
                width: 8,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildLegend() {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        _legendItem(AppColors.emotionHappy, '행복'),
        _legendItem(AppColors.emotionCrying, '울음'),
        _legendItem(AppColors.emotionSurprised, '놀람'),
        _legendItem(AppColors.emotionNeutral, '평온'),
      ],
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

// ─── Tab 2: Growth Chart with WHO Reference ───────────
class _GrowthChartTab extends ConsumerWidget {
  const _GrowthChartTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final child = ref.watch(currentChildProvider);
    if (child == null) {
      return const Center(child: Text('아이 프로필을 먼저 등록해주세요.'));
    }

    final recordsAsync = ref.watch(growthRecordsProvider(child.id));

    return recordsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('오류가 발생했습니다: $e')),
      data: (records) {
        if (records.isEmpty) {
          return const Center(child: Text('성장 기록이 없습니다.'));
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('체중 (kg)', style: AppTextStyles.h3),
              const SizedBox(height: 8),
              SizedBox(
                height: 220,
                child: _buildWeightChart(records, child.birthDate),
              ),
              const SizedBox(height: 8),
              _buildChartLegend(),
              const SizedBox(height: 24),
              Text('키 (cm)', style: AppTextStyles.h3),
              const SizedBox(height: 8),
              SizedBox(
                height: 220,
                child: _buildHeightChart(records, child.birthDate),
              ),
              const SizedBox(height: 8),
              _buildChartLegend(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWeightChart(List<GrowthRecord> records, DateTime birthDate) {
    final spots = <FlSpot>[];
    for (final r in records) {
      if (r.weight == null) continue;
      final monthAge = _monthAge(birthDate, r.recordedAt);
      spots.add(FlSpot(monthAge, r.weight!));
    }
    if (spots.isEmpty) {
      return const Center(child: Text('체중 데이터가 없습니다.'));
    }
    spots.sort((a, b) => a.x.compareTo(b.x));

    // WHO 50th percentile weight (approximate, boys, 0-24m)
    final who50 = <FlSpot>[
      const FlSpot(0, 3.3),
      const FlSpot(1, 4.5),
      const FlSpot(2, 5.6),
      const FlSpot(3, 6.4),
      const FlSpot(4, 7.0),
      const FlSpot(5, 7.5),
      const FlSpot(6, 7.9),
      const FlSpot(9, 8.9),
      const FlSpot(12, 9.6),
      const FlSpot(15, 10.3),
      const FlSpot(18, 10.9),
      const FlSpot(21, 11.5),
      const FlSpot(24, 12.2),
    ];

    return _buildLineChart(spots, who50, 'kg');
  }

  Widget _buildHeightChart(List<GrowthRecord> records, DateTime birthDate) {
    final spots = <FlSpot>[];
    for (final r in records) {
      if (r.height == null) continue;
      final monthAge = _monthAge(birthDate, r.recordedAt);
      spots.add(FlSpot(monthAge, r.height!));
    }
    if (spots.isEmpty) {
      return const Center(child: Text('키 데이터가 없습니다.'));
    }
    spots.sort((a, b) => a.x.compareTo(b.x));

    // WHO 50th percentile length (approximate, boys, 0-24m)
    final who50 = <FlSpot>[
      const FlSpot(0, 49.9),
      const FlSpot(1, 54.7),
      const FlSpot(2, 58.4),
      const FlSpot(3, 61.4),
      const FlSpot(4, 63.9),
      const FlSpot(5, 65.9),
      const FlSpot(6, 67.6),
      const FlSpot(9, 72.0),
      const FlSpot(12, 75.7),
      const FlSpot(15, 79.1),
      const FlSpot(18, 82.3),
      const FlSpot(21, 85.1),
      const FlSpot(24, 87.8),
    ];

    return _buildLineChart(spots, who50, 'cm');
  }

  Widget _buildLineChart(
      List<FlSpot> childSpots, List<FlSpot> whoSpots, String unit) {
    final allY = childSpots.map((s) => s.y).toList();
    final minY = allY.reduce((a, b) => a < b ? a : b);
    final maxY = allY.reduce((a, b) => a > b ? a : b);
    final yPadding = (maxY - minY) * 0.2;

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
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
              getTitlesWidget: (value, meta) => Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${value.toInt()}m',
                  style: const TextStyle(fontSize: 10),
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
                style: const TextStyle(fontSize: 10),
              ),
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minY: childSpots.length == 1 ? minY - 1 : minY - yPadding,
        maxY: childSpots.length == 1 ? maxY + 1 : maxY + yPadding,
        lineBarsData: [
          // Child data
          LineChartBarData(
            spots: childSpots,
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
          // WHO 50th percentile reference
          LineChartBarData(
            spots: whoSpots,
            isCurved: true,
            preventCurveOverShooting: true,
            color: AppColors.textHint,
            barWidth: 1.5,
            dashArray: [6, 4],
            dotData: const FlDotData(show: false),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) => touchedSpots.map((spot) {
              final label = spot.barIndex == 0 ? 'Child' : 'WHO 50th';
              return LineTooltipItem(
                '$label: ${spot.y.toStringAsFixed(1)} $unit',
                const TextStyle(color: Colors.white, fontSize: 12),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildChartLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(width: 20, height: 3, color: AppColors.primary),
        const SizedBox(width: 4),
        const Text('우리 아이', style: TextStyle(fontSize: 11)),
        const SizedBox(width: 16),
        Container(
          width: 20,
          height: 0,
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: AppColors.textHint,
                width: 1.5,
                style: BorderStyle.solid,
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),
        const Text('WHO 50th', style: TextStyle(fontSize: 11)),
      ],
    );
  }

  double _monthAge(DateTime birthDate, DateTime date) {
    return (date.year - birthDate.year) * 12 +
        date.month -
        birthDate.month +
        date.day / 30.0;
  }
}

// ─── Tab 3: Best Expressions ──────────────────────────
class _BestExpressionsTab extends ConsumerWidget {
  const _BestExpressionsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final child = ref.watch(currentChildProvider);
    if (child == null) {
      return const Center(child: Text('아이 프로필을 먼저 등록해주세요.'));
    }

    final diariesAsync = ref.watch(diaryListProvider(child.id));

    return diariesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('오류가 발생했습니다: $e')),
      data: (diaries) {
        final happyEntries = diaries
            .where((d) => d.emotionSummary == 'happy' && d.mediaUrls.isNotEmpty)
            .toList();

        if (happyEntries.isEmpty) {
          return const Center(
            child: Text('행복한 표정 사진이 아직 없습니다.'),
          );
        }

        // Collect all media URLs from happy entries
        final photos = <_PhotoItem>[];
        for (final entry in happyEntries) {
          for (final url in entry.mediaUrls) {
            photos.add(_PhotoItem(url: url, date: entry.recordedAt));
          }
        }

        return GridView.builder(
          padding: const EdgeInsets.all(8),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
          ),
          itemCount: photos.length,
          itemBuilder: (context, index) {
            final photo = photos[index];
            return ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: photo.url,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: AppColors.card,
                      child: const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: AppColors.card,
                      child: const Icon(
                        Icons.broken_image,
                        color: AppColors.textHint,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 2, horizontal: 4),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.6),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: Text(
                        DateFormat('MM.dd').format(photo.date),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _PhotoItem {
  final String url;
  final DateTime date;
  const _PhotoItem({required this.url, required this.date});
}
