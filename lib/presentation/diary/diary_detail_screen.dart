import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/date_formatter.dart';
import '../../data/models/diary_entry.dart';
import '../widgets/development_report_card.dart';
import '../widgets/emotion_badge_widget.dart';
import '../widgets/loading_overlay.dart';
import 'diary_controller.dart';

class DiaryDetailScreen extends ConsumerStatefulWidget {
  final String diaryId;

  const DiaryDetailScreen({super.key, required this.diaryId});

  @override
  ConsumerState<DiaryDetailScreen> createState() => _DiaryDetailScreenState();
}

class _DiaryDetailScreenState extends ConsumerState<DiaryDetailScreen> {
  final _textController = TextEditingController();
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(diaryControllerProvider.notifier).loadEntry(widget.diaryId);
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(diaryControllerProvider);
    final controller = ref.read(diaryControllerProvider.notifier);

    // 텍스트 컨트롤러 동기화
    if (state.entry != null && !_isEditing) {
      _textController.text =
          state.entry!.finalText ?? state.entry!.llmDraft ?? '';
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: _goBackOrHome,
        ),
        title: Text(
          AppStrings.diaryDetail,
          style: TextStyle(color: AppColors.textPrimary),
        ),
        actions: [
          // 공유 버튼
          IconButton(
            onPressed: state.entry != null ? () => _shareDiary(state) : null,
            icon:
                const Icon(Icons.share_outlined, color: AppColors.textPrimary),
            tooltip: '공유',
          ),
          // 삭제 버튼
          IconButton(
            onPressed: state.isDeleting || state.entry == null
                ? null
                : () => _confirmDelete(context, controller),
            icon: state.isDeleting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.error,
                    ),
                  )
                : const Icon(Icons.delete_outline, color: AppColors.error),
            tooltip: '삭제',
          ),
          // 재생성 버튼
          IconButton(
            onPressed: state.isRegenerating
                ? null
                : () => controller.regenerateEntry(widget.diaryId),
            icon: Icon(
              Icons.refresh,
              color:
                  state.isRegenerating ? AppColors.textHint : AppColors.primary,
            ),
            tooltip: AppStrings.regenerateDiary,
          ),
        ],
      ),
      body: Stack(
        children: [
          if (state.isLoading)
            const Center(child: CircularProgressIndicator())
          else if (state.entry != null)
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 날짜 및 감정 배지
                  Row(
                    children: [
                      Text(
                        DateFormatter.formatDateTime(state.entry!.recordedAt),
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(),
                      if (state.entry!.emotionSummary != null)
                        EmotionBadgeWidget(
                          emotion: state.entry!.emotionSummary!,
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 일기 내용 (편집 가능)
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.edit_note,
                                  color: AppColors.primary, size: 20),
                              const SizedBox(width: 8),
                              const Text(
                                '오늘의 일기',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                              TextButton(
                                onPressed: () {
                                  setState(() => _isEditing = !_isEditing);
                                },
                                child: Text(_isEditing ? '완료' : '편집'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (_diaryImageUrls(state.entry!).isNotEmpty) ...[
                            _buildDiaryPhotoPreview(
                              _diaryImageUrls(state.entry!),
                            ),
                            const SizedBox(height: 14),
                          ],
                          TextField(
                            controller: _textController,
                            maxLines: null,
                            readOnly: !_isEditing,
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              hintText: '일기 내용이 여기에 표시됩니다',
                            ),
                            style: TextStyle(
                              fontSize: 15,
                              height: 1.8,
                              color: AppColors.textPrimary,
                            ),
                            onChanged: (_) {
                              if (!_isEditing) {
                                setState(() => _isEditing = true);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildAiAnalysisCard(state.entry!),
                  const SizedBox(height: 16),

                  // 발달 리포트 카드 — 방금 생성된 결과 우선, 없으면 DB에 저장된 값
                  () {
                    final report = state.generationResult?.developmentReport ??
                        state.entry?.developmentReport ??
                        '';
                    final milestone =
                        state.generationResult?.milestoneDetected ??
                            state.entry?.milestoneDetected;
                    final tips = state.generationResult?.parentingTips ??
                        state.entry?.parentingTips ??
                        const <String>[];
                    if (report.isEmpty &&
                        (milestone == null || milestone.isEmpty) &&
                        tips.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DevelopmentReportCard(
                          report: report,
                          milestone: (milestone != null && milestone.isNotEmpty)
                              ? milestone
                              : null,
                        ),
                        const SizedBox(height: 16),
                        if (tips.isNotEmpty) _buildParentingTips(tips),
                      ],
                    );
                  }(),

                  const SizedBox(height: 80), // 버튼 여유 공간
                ],
              ),
            ),
          if (state.isRegenerating)
            const LoadingOverlay(customMessage: 'AI가 일기를 다시 작성하고 있어요...'),
        ],
      ),
      // 저장 버튼
      bottomNavigationBar: state.entry != null
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton(
                  onPressed: state.isSaving
                      ? null
                      : () async {
                          await controller.saveEntry(
                            widget.diaryId,
                            _textController.text,
                          );
                          if (!context.mounted) return;

                          final saveError =
                              ref.read(diaryControllerProvider).error;
                          if (saveError == null) {
                            context.go('/home');
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('저장에 실패했어요: $saveError')),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: state.isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          AppStrings.saveDiary,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            )
          : null,
    );
  }

  void _goBackOrHome() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  List<String> _diaryImageUrls(DiaryEntry entry) {
    return entry.mediaUrls.where(_isImageUrl).toList();
  }

  bool _isImageUrl(String url) {
    final uri = Uri.tryParse(url);
    final path = (uri?.path ?? url).toLowerCase();
    return path.endsWith('.jpg') ||
        path.endsWith('.jpeg') ||
        path.endsWith('.png') ||
        path.endsWith('.webp') ||
        path.endsWith('.heic');
  }

  Widget _buildDiaryPhotoPreview(List<String> imageUrls) {
    final remaining = imageUrls.length - 1;

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: imageUrls.first,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                color: AppColors.card,
                child: Center(
                  child: Icon(
                    Icons.image_outlined,
                    color: AppColors.textHint,
                    size: 34,
                  ),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                color: AppColors.card,
                child: Center(
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: AppColors.textHint,
                    size: 34,
                  ),
                ),
              ),
            ),
            if (remaining > 0)
              Positioned(
                right: 10,
                bottom: 10,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '+$remaining',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, DiaryController controller) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('일기 삭제'),
        content: const Text('이 일기를 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('삭제', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final ok = await controller.deleteEntry(widget.diaryId);
      if (!mounted) return;
      if (ok) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('일기가 삭제되었습니다')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('삭제에 실패했습니다')),
        );
      }
    }
  }

  Future<void> _shareDiary(DiaryDetailState state) async {
    final entry = state.entry;
    if (entry == null) return;

    final text =
        '${DateFormatter.formatDate(entry.recordedAt)}\n\n${entry.finalText ?? entry.llmDraft ?? ''}\n\n- 아기일기 앱에서 작성됨';
    await SharePlus.instance.share(ShareParams(text: text, title: '아기일기'));
  }

  Widget _buildAiAnalysisCard(DiaryEntry entry) {
    final visionData = entry.visionData;
    return Card(
      elevation: 0,
      color: AppColors.primaryLight.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: AppColors.primary.withValues(alpha: 0.12),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics_outlined,
                    color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'AI 분석 결과',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildAnalysisRow(
              icon: Icons.face_retouching_natural,
              title: '표정 분석',
              value: _emotionLabel(entry.emotionSummary),
              detail: _faceDetail(visionData),
              color: AppColors.secondary,
            ),
            const SizedBox(height: 10),
            _buildAnalysisRow(
              icon: Icons.center_focus_strong,
              title: 'YOLO 행동 인식',
              value: _yoloBehaviorLabel(visionData),
              detail: _yoloBehaviorDetail(visionData),
              color: _yoloBehaviorColor(visionData),
            ),
            if (_hasVideoBehavior(visionData)) ...[
              const SizedBox(height: 10),
              _buildAnalysisRow(
                icon: Icons.videocam_outlined,
                title: 'YOLO 영상 분석',
                value: _videoBehaviorLabel(visionData),
                detail: _videoBehaviorDetail(visionData),
                color: _videoBehaviorColor(visionData),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisRow({
    required IconData icon,
    required String title,
    required String value,
    required String detail,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Flexible(
                      child: Text(
                        value,
                        textAlign: TextAlign.right,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: color,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  detail,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _emotionLabel(String? emotion) {
    switch (emotion) {
      case 'happy':
        return '웃는 표정';
      case 'sleeping':
        return '잠든 듯함';
      case 'surprised':
        return '또렷한 표정';
      case 'neutral':
        return '차분함';
      default:
        return '분석 없음';
    }
  }

  String _faceDetail(Map<String, dynamic>? visionData) {
    final details = visionData?['details'];
    if (details is! Map) return '사진 표정 분석 데이터가 저장되지 않았어요.';
    final faces = (details['faces_detected'] as num?)?.toInt() ?? 0;
    if (faces == 0) return '얼굴이 감지되지 않았어요.';
    final smile = (details['smile_probability'] as num?)?.toDouble();
    final leftEye = (details['left_eye_open'] as num?)?.toDouble();
    final rightEye = (details['right_eye_open'] as num?)?.toDouble();
    final eyes = leftEye != null && rightEye != null
        ? ((leftEye + rightEye) / 2).toStringAsFixed(2)
        : '없음';
    final smileText = smile?.toStringAsFixed(2) ?? '없음';
    return '얼굴 $faces개 · 미소 $smileText · 눈뜸 $eyes';
  }

  String _yoloBehaviorLabel(Map<String, dynamic>? visionData) {
    final behavior = visionData?['baby_behavior'];
    if (behavior is Map) {
      final action = behavior['primary_action']?.toString();
      if (action == null || action.isEmpty || action == 'null') {
        return '실행됨 · 감지 안됨';
      }
      return _behaviorKoreanLabel(action);
    }
    if (visionData?.containsKey('baby_behavior_error') ?? false) {
      return '분석 실패';
    }
    return '결과 없음';
  }

  String _yoloBehaviorDetail(Map<String, dynamic>? visionData) {
    final behavior = visionData?['baby_behavior'];
    if (behavior is Map) {
      final action = behavior['primary_action']?.toString();
      final label = behavior['primary_label']?.toString();
      final confidence = (behavior['confidence'] as num?)?.toDouble();
      final detectionsRaw = behavior['detections'];
      final detectionCount = detectionsRaw is List ? detectionsRaw.length : 0;

      if (action == null || action.isEmpty || action == 'null') {
        return 'YOLO 모델은 실행됐지만 기준치 이상 아기 행동은 없었어요.';
      }

      final confidenceText = confidence == null
          ? '신뢰도 없음'
          : '신뢰도 ${(confidence * 100).toStringAsFixed(0)}%';
      return '${label ?? action} · $confidenceText · 감지 $detectionCount개';
    }

    final error = visionData?['baby_behavior_error'];
    if (error != null) {
      return 'YOLO 실행 중 오류가 발생했어요: $error';
    }

    return 'YOLO 연결 전에 만든 일기거나 사진 분석 없이 생성된 일기예요.';
  }

  Color _yoloBehaviorColor(Map<String, dynamic>? visionData) {
    final behavior = visionData?['baby_behavior'];
    if (behavior is Map) {
      final action = behavior['primary_action']?.toString();
      if (action == null || action.isEmpty || action == 'null') {
        return AppColors.textSecondary;
      }
      return AppColors.success;
    }
    if (visionData?.containsKey('baby_behavior_error') ?? false) {
      return AppColors.error;
    }
    return AppColors.textHint;
  }

  bool _hasVideoBehavior(Map<String, dynamic>? visionData) {
    return visionData?['video_behavior'] is Map ||
        (visionData?.containsKey('video_behavior_error') ?? false);
  }

  String _videoBehaviorLabel(Map<String, dynamic>? visionData) {
    final behavior = visionData?['video_behavior'];
    if (behavior is Map) {
      final action = behavior['primary_action']?.toString();
      if (action == null || action.isEmpty || action == 'null') {
        return '실행됨 · 감지 안됨';
      }
      return _behaviorKoreanLabel(action);
    }
    if (visionData?.containsKey('video_behavior_error') ?? false) {
      return '분석 실패';
    }
    return '결과 없음';
  }

  String _videoBehaviorDetail(Map<String, dynamic>? visionData) {
    final behavior = visionData?['video_behavior'];
    if (behavior is Map) {
      final action = behavior['primary_action']?.toString();
      final label = behavior['primary_label']?.toString();
      final confidence = (behavior['confidence'] as num?)?.toDouble();
      final framesAnalyzed =
          (behavior['frames_analyzed'] as num?)?.toInt() ?? 0;
      final requestedFrames =
          (behavior['requested_frames'] as num?)?.toInt() ?? 0;
      final durationMs = (behavior['video_duration_ms'] as num?)?.toInt();
      final durationText = durationMs == null
          ? null
          : '${(durationMs / 1000).toStringAsFixed(1)}초';
      final frameText = '$framesAnalyzed/$requestedFrames프레임';

      if (action == null || action.isEmpty || action == 'null') {
        return 'YOLO가 영상 $frameText을 분석했지만 기준치 이상의 아기 행동은 없었어요.';
      }

      final confidenceText = confidence == null
          ? '신뢰도 없음'
          : '신뢰도 ${(confidence * 100).toStringAsFixed(0)}%';
      final durationSuffix = durationText == null ? '' : ' · $durationText';
      return '${label ?? action} · $confidenceText · $frameText$durationSuffix';
    }

    final error = visionData?['video_behavior_error'];
    if (error != null) {
      return '영상 YOLO 실행 중 오류가 발생했어요. $error';
    }

    return '영상 분석 기능 연결 전에 만든 일기거나 영상 없이 생성된 일기예요.';
  }

  Color _videoBehaviorColor(Map<String, dynamic>? visionData) {
    final behavior = visionData?['video_behavior'];
    if (behavior is Map) {
      final action = behavior['primary_action']?.toString();
      if (action == null || action.isEmpty || action == 'null') {
        return AppColors.textSecondary;
      }
      return AppColors.success;
    }
    if (visionData?.containsKey('video_behavior_error') ?? false) {
      return AppColors.error;
    }
    return AppColors.textHint;
  }

  String _behaviorKoreanLabel(String action) {
    switch (action) {
      case 'crawling':
        return '기기';
      case 'lifted':
        return '안김/들림';
      case 'lying_on_back':
        return '등 대고 누움';
      case 'lying_on_side':
        return '옆으로 누움';
      case 'tummy_time':
        return '터미타임';
      case 'sitting':
        return '앉기';
      case 'sitting_assisted':
        return '보조 앉기';
      case 'walking':
        return '걷기';
      case 'baby_detected':
        return '아기 감지';
      default:
        return action.replaceAll('_', ' ');
    }
  }

  Widget _buildParentingTips(List<String> tips) {
    return Card(
      elevation: 0,
      color: AppColors.secondaryLight.withValues(alpha: 0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: ExpansionTile(
        title: Row(
          children: [
            Icon(Icons.lightbulb_outline, color: AppColors.secondary, size: 20),
            const SizedBox(width: 8),
            Text(
              AppStrings.parentingTips,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        children: tips.map((tip) {
          return ListTile(
            leading: Icon(Icons.check_circle_outline,
                color: AppColors.secondary, size: 18),
            title: Text(tip, style: const TextStyle(fontSize: 14)),
          );
        }).toList(),
      ),
    );
  }
}
