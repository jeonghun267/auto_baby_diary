import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

class ExtractedVideoFrame {
  const ExtractedVideoFrame({
    required this.path,
    required this.timeMs,
  });

  final String path;
  final int timeMs;
}

class VideoFrameExtractionResult {
  const VideoFrameExtractionResult({
    required this.videoDurationMs,
    required this.requestedTimeMs,
    required this.frames,
  });

  final int videoDurationMs;
  final List<int> requestedTimeMs;
  final List<ExtractedVideoFrame> frames;

  int get framesExtracted => frames.length;
}

class VideoFrameExtractorService {
  VideoFrameExtractorService({
    this.sampleInterval = const Duration(seconds: 1),
    this.maxFrames = 12,
    this.maxFrameWidth = 640,
    this.quality = 78,
  });

  final Duration sampleInterval;
  final int maxFrames;
  final int maxFrameWidth;
  final int quality;

  Future<VideoFrameExtractionResult> extractFrames(String videoPath) async {
    final duration = await _readDuration(videoPath);
    final requestedTimeMs = _buildSampleTimes(duration);
    final tempDir = await getTemporaryDirectory();
    final batchId = DateTime.now().microsecondsSinceEpoch;
    final frames = <ExtractedVideoFrame>[];

    for (final timeMs in requestedTimeMs) {
      try {
        final thumbnailPath = await VideoThumbnail.thumbnailFile(
          video: videoPath,
          thumbnailPath: tempDir.path,
          imageFormat: ImageFormat.JPEG,
          maxWidth: maxFrameWidth,
          quality: quality,
          timeMs: timeMs,
        );
        if (thumbnailPath == null || thumbnailPath.isEmpty) continue;
        final thumbnailFile = File(thumbnailPath);
        if (!await thumbnailFile.exists()) continue;
        final framePath = '${tempDir.path}/video_frame_${batchId}_$timeMs.jpg';
        await thumbnailFile.copy(framePath);
        frames.add(ExtractedVideoFrame(path: framePath, timeMs: timeMs));
      } catch (e, st) {
        debugPrint('[VideoFrame] failed to extract frame at ${timeMs}ms: $e');
        debugPrint('$st');
      }
    }

    return VideoFrameExtractionResult(
      videoDurationMs: duration.inMilliseconds,
      requestedTimeMs: requestedTimeMs,
      frames: frames,
    );
  }

  Future<Duration> _readDuration(String videoPath) async {
    final fallbackDuration =
        Duration(milliseconds: sampleInterval.inMilliseconds * maxFrames);
    final controller = VideoPlayerController.file(File(videoPath));
    try {
      await controller.initialize();
      final duration = controller.value.duration;
      if (duration < sampleInterval) {
        debugPrint(
          '[VideoFrame] suspicious video duration ${duration.inMilliseconds}ms; '
          'using fallback ${fallbackDuration.inMilliseconds}ms',
        );
        return fallbackDuration;
      }
      return duration;
    } catch (e, st) {
      debugPrint('[VideoFrame] failed to read duration: $e');
      debugPrint('$st');
      return fallbackDuration;
    } finally {
      await controller.dispose();
    }
  }

  List<int> _buildSampleTimes(Duration duration) {
    final durationMs = duration.inMilliseconds;
    final intervalMs = sampleInterval.inMilliseconds;
    if (durationMs <= 0 || intervalMs <= 0 || maxFrames <= 0) {
      return const [0];
    }

    if (durationMs <= intervalMs * maxFrames) {
      final count =
          (durationMs / intervalMs).ceil().clamp(1, maxFrames).toInt();
      final maxTimeMs = (durationMs - 1).clamp(0, durationMs).toInt();
      return List<int>.generate(count, (index) {
        final timeMs = index * intervalMs;
        return timeMs.clamp(0, maxTimeMs).toInt();
      }).toSet().toList();
    }

    final step = durationMs / maxFrames;
    return List<int>.generate(maxFrames, (index) {
      final timeMs = ((index * step) + (step / 2)).round();
      return timeMs.clamp(0, durationMs - 1).toInt();
    }).toSet().toList();
  }
}

final videoFrameExtractorServiceProvider =
    Provider<VideoFrameExtractorService>((ref) {
  return VideoFrameExtractorService();
});
