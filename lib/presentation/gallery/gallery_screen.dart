import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/supabase_service.dart';
import '../widgets/state_views.dart';

class _GalleryItem {
  final String diaryId;
  final String imageUrl;
  final DateTime recordedAt;
  final String? emotionSummary;

  _GalleryItem({
    required this.diaryId,
    required this.imageUrl,
    required this.recordedAt,
    this.emotionSummary,
  });
}

class _MonthGroup {
  final String label; // e.g. "2026년 4월"
  final List<_GalleryItem> items;

  _MonthGroup({required this.label, required this.items});
}

class GalleryScreen extends ConsumerStatefulWidget {
  const GalleryScreen({super.key});

  @override
  ConsumerState<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends ConsumerState<GalleryScreen> {
  List<_GalleryItem> _allItems = [];
  bool _isLoading = true;
  String? _error;
  String _selectedEmotion = '전체';

  static const _emotionFilters = [
    '전체',
    '행복 😊',
    '울음 😢',
    '놀람 😮',
    '평온 😌',
  ];

  static const _emotionFilterKeys = {
    '전체': null,
    '행복 😊': 'happy',
    '울음 😢': 'crying',
    '놀람 😮': 'surprised',
    '평온 😌': 'neutral',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPhotos());
  }

  Future<void> _loadPhotos() async {
    final child = ref.read(currentChildProvider);
    if (child == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await SupabaseService.client
          .from('diary_entries')
          .select('id, media_urls, recorded_at, emotion_summary')
          .eq('child_id', child.id)
          .not('media_urls', 'eq', '{}')
          .order('recorded_at', ascending: false);

      final items = <_GalleryItem>[];
      for (final row in (response as List)) {
        final map = row as Map<String, dynamic>;
        final urls = (map['media_urls'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [];
        final recordedAt = DateTime.parse(map['recorded_at'] as String);
        final emotion = map['emotion_summary'] as String?;
        final diaryId = map['id'] as String;

        for (final url in urls) {
          items.add(_GalleryItem(
            diaryId: diaryId,
            imageUrl: url,
            recordedAt: recordedAt,
            emotionSummary: emotion,
          ));
        }
      }

      if (mounted) {
        setState(() {
          _allItems = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  List<_GalleryItem> get _filteredItems {
    final filterKey = _emotionFilterKeys[_selectedEmotion];
    if (filterKey == null) return _allItems;
    return _allItems.where((item) => item.emotionSummary == filterKey).toList();
  }

  List<_MonthGroup> get _monthGroups {
    final filtered = _filteredItems;
    final Map<String, List<_GalleryItem>> grouped = {};

    for (final item in filtered) {
      final key = '${item.recordedAt.year}년 ${item.recordedAt.month}월';
      grouped.putIfAbsent(key, () => []).add(item);
    }

    return grouped.entries
        .map((e) => _MonthGroup(label: e.key, items: e.value))
        .toList();
  }

  String _getEmotionEmoji(String? emotion) {
    switch (emotion) {
      case 'happy':
        return '😊';
      case 'crying':
        return '😢';
      case 'surprised':
        return '😮';
      case 'neutral':
        return '😌';
      default:
        return '😐';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text(
          '사진 앨범',
          style: TextStyle(
              color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const LoadingView();
    }

    if (_error != null) {
      return ErrorView(onRetry: _loadPhotos);
    }

    if (_allItems.isEmpty) {
      return const EmptyView(
        icon: Icons.camera_alt_outlined,
        title: '아직 사진이 없어요',
        subtitle: '일기를 작성하면 자동으로 앨범에 추가돼요',
      );
    }

    final groups = _monthGroups;

    return RefreshIndicator(
      onRefresh: _loadPhotos,
      color: AppColors.primary,
      child: CustomScrollView(
        slivers: [
          // Emotion filter chips
          SliverToBoxAdapter(
            child: _buildEmotionFilterChips(),
          ),

          // Empty state when filter yields no results
          if (groups.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Text(
                  '해당 감정의 사진이 없습니다',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textSecondary),
                ),
              ),
            ),

          // Month groups with photo grids
          for (final group in groups) ...[
            SliverToBoxAdapter(
              child: _buildMonthHeader(group.label),
            ),
            SliverToBoxAdapter(
              child: _buildPhotoGrid(group.items),
            ),
          ],

          // Bottom padding
          const SliverToBoxAdapter(
            child: SizedBox(height: 24),
          ),
        ],
      ),
    );
  }

  Widget _buildEmotionFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: _emotionFilters.map((label) {
          final isSelected = _selectedEmotion == label;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(label),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedEmotion = selected ? label : '전체';
                });
              },
              selectedColor: AppColors.primaryLight,
              backgroundColor: AppColors.card,
              checkmarkColor: AppColors.primaryDark,
              labelStyle: TextStyle(
                color: isSelected
                    ? AppColors.primaryDark
                    : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 13,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.textHint.withValues(alpha: 0.3),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMonthHeader(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
          letterSpacing: -0.3,
        ),
      ),
    );
  }

  Widget _buildPhotoGrid(List<_GalleryItem> items) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return GestureDetector(
            onTap: () => context.push('/diary/${item.diaryId}'),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: item.imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: AppColors.card,
                      child: const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: AppColors.card,
                      child: const Icon(Icons.broken_image,
                          color: AppColors.textHint, size: 28),
                    ),
                  ),
                  // Emotion emoji overlay in bottom-right
                  if (item.emotionSummary != null)
                    Positioned(
                      right: 4,
                      bottom: 4,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _getEmotionEmoji(item.emotionSummary),
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
