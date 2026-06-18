import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/supabase_service.dart';
import '../../core/utils/date_formatter.dart';
import '../../data/models/diary_entry.dart';
import '../widgets/state_views.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  List<DiaryEntry> _results = [];
  bool _isLoading = false;
  bool _hasSearched = false;
  String? _emotionFilter;

  static const _emotions = <String, String>{
    '전체': '',
    '행복': 'happy',
    '울음': 'crying',
    '놀람': 'surprised',
    '평온': 'neutral',
  };

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _performSearch();
    });
  }

  Future<void> _performSearch() async {
    final child = ref.read(currentChildProvider);
    if (child == null) return;

    final searchText = _searchController.text.trim();

    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });

    try {
      var query = SupabaseService.client
          .from('diary_entries')
          .select()
          .eq('child_id', child.id);

      if (searchText.isNotEmpty) {
        query = query.or(
            'final_text.ilike.%$searchText%,llm_draft.ilike.%$searchText%,stt_transcript.ilike.%$searchText%');
      }

      if (_emotionFilter != null && _emotionFilter!.isNotEmpty) {
        query = query.eq('emotion_summary', _emotionFilter!);
      }

      final response =
          await query.order('recorded_at', ascending: false).limit(50);

      if (mounted) {
        setState(() {
          _results = (response as List)
              .map((e) => DiaryEntry.fromJson(e as Map<String, dynamic>))
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _results = [];
        });
      }
    }
  }

  void _onEmotionFilterChanged(String label) {
    final value = _emotions[label] ?? '';
    setState(() {
      _emotionFilter = value.isEmpty ? null : value;
    });
    _performSearch();
  }

  String _getEmotionEmoji(String emotion) {
    switch (emotion) {
      case 'happy':
        return '😊';
      case 'crying':
        return '😢';
      case 'surprised':
        return '😮';
      default:
        return '😐';
    }
  }

  String _currentFilterLabel() {
    if (_emotionFilter == null) return '전체';
    for (final entry in _emotions.entries) {
      if (entry.value == _emotionFilter) return entry.key;
    }
    return '전체';
  }

  Widget _buildHighlightedText(String text, String query) {
    if (query.isEmpty) {
      return Text(
        text,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.bodyMedium.copyWith(height: 1.6),
      );
    }

    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final spans = <TextSpan>[];
    int start = 0;

    while (true) {
      final index = lowerText.indexOf(lowerQuery, start);
      if (index == -1) {
        spans.add(TextSpan(text: text.substring(start)));
        break;
      }
      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index)));
      }
      spans.add(TextSpan(
        text: text.substring(index, index + query.length),
        style: const TextStyle(
            fontWeight: FontWeight.bold, color: AppColors.primary),
      ));
      start = index + query.length;
    }

    return RichText(
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: AppTextStyles.bodyMedium.copyWith(height: 1.6),
        children: spans,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header with back button and search field
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back,
                        color: AppColors.textPrimary),
                    onPressed: () => context.pop(),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      autofocus: true,
                      onChanged: _onSearchChanged,
                      decoration: InputDecoration(
                        hintText: '일기 내용을 검색하세요',
                        hintStyle: const TextStyle(color: AppColors.textHint),
                        prefixIcon:
                            const Icon(Icons.search, color: AppColors.textHint),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear,
                                    color: AppColors.textHint),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _results = [];
                                    _hasSearched = false;
                                  });
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: AppColors.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Emotion filter chips
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: _emotions.keys.map((label) {
                    final isSelected = _currentFilterLabel() == label;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(
                          label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: isSelected
                                ? Colors.white
                                : AppColors.textPrimary,
                          ),
                        ),
                        selected: isSelected,
                        onSelected: (_) => _onEmotionFilterChanged(label),
                        backgroundColor: AppColors.surface,
                        selectedColor: AppColors.primary,
                        checkmarkColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        side: BorderSide(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.primaryLight.withValues(alpha: 0.4),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

            // Results
            Expanded(
              child: _buildBody(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const LoadingView();
    }

    if (!_hasSearched) {
      return const EmptyView(
        icon: Icons.search,
        title: '검색어를 입력해주세요',
        subtitle: '일기 본문에서 단어를 찾아드려요',
      );
    }

    if (_results.isEmpty) {
      return const EmptyView(
        icon: Icons.search_off,
        title: '검색 결과가 없어요',
        subtitle: '다른 단어로 검색해보세요',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final entry = _results[index];
        final previewText = entry.finalText ?? entry.llmDraft ?? '';
        final searchQuery = _searchController.text.trim();

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 1,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          color: AppColors.surface,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => context.push('/diary/${entry.id}'),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        DateFormatter.formatDate(entry.recordedAt),
                        style: AppTextStyles.labelMedium,
                      ),
                      const Spacer(),
                      if (entry.emotionSummary != null)
                        Text(
                          _getEmotionEmoji(entry.emotionSummary!),
                          style: const TextStyle(fontSize: 22),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildHighlightedText(previewText, searchQuery),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
