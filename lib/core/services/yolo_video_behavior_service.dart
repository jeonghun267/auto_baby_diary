import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'video_frame_extractor_service.dart';
import 'yolo_behavior_service.dart';

class VideoBehaviorTimelineItem {
  const VideoBehaviorTimelineItem({
    required this.timeMs,
    required this.action,
    required this.label,
    required this.confidence,
  });

  final int timeMs;
  final String? action;
  final String? label;
  final double? confidence;

  Map<String, dynamic> toJson() => {
        'time_ms': timeMs,
        'action': action,
        'label': label,
        'confidence': confidence,
      };
}

class YoloVideoBehaviorResult {
  const YoloVideoBehaviorResult({
    required this.timestamp,
    required this.videoDurationMs,
    required this.requestedFrames,
    required this.framesAnalyzed,
    required this.primaryAction,
    required this.primaryLabel,
    required this.confidence,
    required this.actionCounts,
    required this.timeline,
  });

  final DateTime timestamp;
  final int videoDurationMs;
  final int requestedFrames;
  final int framesAnalyzed;
  final String? primaryAction;
  final String? primaryLabel;
  final double? confidence;
  final Map<String, int> actionCounts;
  final List<VideoBehaviorTimelineItem> timeline;

  bool get hasPrimaryAction =>
      primaryAction != null && primaryAction!.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'primary_action': primaryAction,
        'primary_label': primaryLabel,
        'confidence': confidence,
        'video_duration_ms': videoDurationMs,
        'requested_frames': requestedFrames,
        'frames_analyzed': framesAnalyzed,
        'action_counts': actionCounts,
        'timeline': timeline.map((item) => item.toJson()).toList(),
        'timestamp': timestamp.toIso8601String(),
      };
}

class YoloVideoBehaviorService {
  YoloVideoBehaviorService(
    this._frameExtractor,
    this._behaviorService,
  );

  final VideoFrameExtractorService _frameExtractor;
  final YoloBehaviorService _behaviorService;

  Future<YoloVideoBehaviorResult> analyzeVideo(String videoPath) async {
    final extraction = await _frameExtractor.extractFrames(videoPath);
    final timeline = <VideoBehaviorTimelineItem>[];
    final actionStats = <String, _ActionStats>{};

    for (final frame in extraction.frames) {
      try {
        final frameResult = await _behaviorService.analyzeImage(frame.path);
        final primary = frameResult.primaryDetection;
        timeline.add(VideoBehaviorTimelineItem(
          timeMs: frame.timeMs,
          action: primary?.action,
          label: primary?.label,
          confidence: primary?.confidence,
        ));

        if (primary == null) continue;
        final stats = actionStats.putIfAbsent(
          primary.action,
          () => _ActionStats(label: primary.label),
        );
        stats.add(primary.confidence);
      } catch (e, st) {
        debugPrint(
            '[YOLO Video] frame analysis failed at ${frame.timeMs}ms: $e');
        debugPrint('$st');
        timeline.add(VideoBehaviorTimelineItem(
          timeMs: frame.timeMs,
          action: null,
          label: null,
          confidence: null,
        ));
      }
    }

    final primaryEntry = _selectPrimaryAction(actionStats);
    return YoloVideoBehaviorResult(
      timestamp: DateTime.now(),
      videoDurationMs: extraction.videoDurationMs,
      requestedFrames: extraction.requestedTimeMs.length,
      framesAnalyzed: extraction.framesExtracted,
      primaryAction: primaryEntry?.key,
      primaryLabel: primaryEntry?.value.label,
      confidence: primaryEntry?.value.averageConfidence,
      actionCounts: {
        for (final entry in actionStats.entries) entry.key: entry.value.count,
      },
      timeline: timeline,
    );
  }

  MapEntry<String, _ActionStats>? _selectPrimaryAction(
    Map<String, _ActionStats> stats,
  ) {
    if (stats.isEmpty) return null;

    final behaviorStats = Map<String, _ActionStats>.from(stats)
      ..remove('baby_detected');
    final candidates = behaviorStats.isNotEmpty ? behaviorStats : stats;
    final entries = candidates.entries.toList()
      ..sort((a, b) {
        final countCompare = b.value.count.compareTo(a.value.count);
        if (countCompare != 0) return countCompare;
        return b.value.averageConfidence.compareTo(a.value.averageConfidence);
      });
    return entries.first;
  }
}

class _ActionStats {
  _ActionStats({required this.label});

  final String label;
  int count = 0;
  double confidenceSum = 0;

  double get averageConfidence => count == 0 ? 0 : confidenceSum / count;

  void add(double confidence) {
    count += 1;
    confidenceSum += confidence;
  }
}

final yoloVideoBehaviorServiceProvider =
    Provider<YoloVideoBehaviorService>((ref) {
  return YoloVideoBehaviorService(
    ref.watch(videoFrameExtractorServiceProvider),
    ref.watch(yoloBehaviorServiceProvider),
  );
});
