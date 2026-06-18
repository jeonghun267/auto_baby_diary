import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';

class BabyBehaviorDetection {
  const BabyBehaviorDetection({
    required this.label,
    required this.action,
    required this.confidence,
    required this.classIndex,
    required this.normalizedBox,
    required this.source,
    required this.sourceRect,
  });

  final String label;
  final String action;
  final double confidence;
  final int classIndex;
  final Map<String, double> normalizedBox;
  final String source;
  final Map<String, double> sourceRect;

  Map<String, dynamic> toJson() => {
        'label': label,
        'action': action,
        'confidence': confidence,
        'class_index': classIndex,
        'normalized_box': normalizedBox,
        'source': source,
        'source_rect': sourceRect,
      };
}

class YoloBehaviorResult {
  const YoloBehaviorResult({
    required this.timestamp,
    required this.detections,
    required this.candidatesAnalyzed,
  });

  final DateTime timestamp;
  final List<BabyBehaviorDetection> detections;
  final List<String> candidatesAnalyzed;

  bool get hasDetections => detections.isNotEmpty;

  BabyBehaviorDetection? get primaryDetection {
    if (detections.isEmpty) return null;
    final behaviorDetections = detections
        .where((detection) => detection.action != 'baby_detected')
        .toList();
    if (behaviorDetections.isNotEmpty) return behaviorDetections.first;
    return detections.first;
  }

  Map<String, dynamic> toJson() {
    final primary = primaryDetection;
    return {
      'primary_action': primary?.action,
      'primary_label': primary?.label,
      'confidence': primary?.confidence,
      'source': primary?.source,
      'source_rect': primary?.sourceRect,
      'candidates_analyzed': candidatesAnalyzed,
      'timestamp': timestamp.toIso8601String(),
      'detections': detections.map((detection) => detection.toJson()).toList(),
    };
  }
}

class YoloBehaviorService {
  YoloBehaviorService({
    this.confidenceThreshold = 0.25,
    this.iouThreshold = 0.7,
    this.enableMultiCrop = true,
  });

  static const String _modelPath = 'assets/models/baby_behavior_yolov8n.tflite';
  static const String _labelsPath = 'assets/models/baby_labels.txt';

  static const List<_CropSpec> _cropSpecs = [
    _CropSpec(
      name: 'center_zoom',
      left: 0.15,
      top: 0.15,
      width: 0.70,
      height: 0.70,
    ),
    _CropSpec(
      name: 'lower_zoom',
      left: 0.05,
      top: 0.30,
      width: 0.90,
      height: 0.65,
    ),
    _CropSpec(
      name: 'left_zoom',
      left: 0.00,
      top: 0.15,
      width: 0.65,
      height: 0.75,
    ),
    _CropSpec(
      name: 'right_zoom',
      left: 0.35,
      top: 0.15,
      width: 0.65,
      height: 0.75,
    ),
  ];

  final double confidenceThreshold;
  final double iouThreshold;
  final bool enableMultiCrop;

  YOLO? _yolo;
  Future<void>? _loadFuture;
  Future<List<String>>? _labelsFuture;

  Future<YoloBehaviorResult> analyzeImage(String imagePath) async {
    await _ensureLoaded();

    final labels = await _loadLabels();
    final imageBytes = await File(imagePath).readAsBytes();
    final candidates = await _buildCandidates(imageBytes);
    final detections = <BabyBehaviorDetection>[];

    for (final candidate in candidates) {
      try {
        final candidateDetections = await _predictCandidate(candidate, labels);
        if (candidateDetections.isNotEmpty) {
          debugPrint(
            '[YOLO] ${candidate.name}: '
            '${candidateDetections.map((d) => '${d.label}/${d.confidence.toStringAsFixed(2)}').join(', ')}',
          );
        }
        detections.addAll(candidateDetections);
      } catch (e, st) {
        debugPrint('[YOLO] ${candidate.name} failed: $e');
        debugPrint('$st');
      }
    }

    detections.sort((a, b) {
      final aSpecific = a.action == 'baby_detected' ? 0 : 1;
      final bSpecific = b.action == 'baby_detected' ? 0 : 1;
      final specificCompare = bSpecific.compareTo(aSpecific);
      if (specificCompare != 0) return specificCompare;
      return b.confidence.compareTo(a.confidence);
    });

    final result = YoloBehaviorResult(
      timestamp: DateTime.now(),
      detections: detections,
      candidatesAnalyzed:
          candidates.map((candidate) => candidate.name).toList(),
    );
    final primary = result.primaryDetection;
    debugPrint(
      '[YOLO] ${File(imagePath).uri.pathSegments.last}: '
      'candidates=${candidates.length}, detections=${detections.length}, '
      'primary=${primary == null ? 'none' : '${primary.action}/${primary.confidence.toStringAsFixed(2)} from ${primary.source}'}',
    );
    return result;
  }

  Future<List<BabyBehaviorDetection>> _predictCandidate(
    _ImageCandidate candidate,
    List<String> labels,
  ) async {
    final rawResult = await _yolo!.predict(
      candidate.bytes,
      confidenceThreshold: confidenceThreshold,
      iouThreshold: iouThreshold,
    );

    final rawDetections = _rawDetections(rawResult);
    return rawDetections
        .map((raw) => _parseDetection(raw, labels, candidate))
        .whereType<BabyBehaviorDetection>()
        .where((detection) => detection.confidence >= confidenceThreshold)
        .toList();
  }

  Future<List<_ImageCandidate>> _buildCandidates(
      Uint8List originalBytes) async {
    final candidates = <_ImageCandidate>[
      _ImageCandidate(
        name: 'full',
        bytes: originalBytes,
        sourceRect: _rectMap(0, 0, 1, 1),
      ),
    ];

    if (!enableMultiCrop) return candidates;

    ui.Image? image;
    try {
      image = await _decodeImage(originalBytes);
      for (final spec in _cropSpecs) {
        final cropBytes = await _cropToPngBytes(image, spec);
        candidates.add(
          _ImageCandidate(
            name: spec.name,
            bytes: cropBytes,
            sourceRect: spec.toRectMap(),
          ),
        );
      }
    } catch (e, st) {
      debugPrint('[YOLO] multi-crop preparation failed: $e');
      debugPrint('$st');
    } finally {
      image?.dispose();
    }

    return candidates;
  }

  Future<ui.Image> _decodeImage(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    try {
      final frame = await codec.getNextFrame();
      return frame.image;
    } finally {
      codec.dispose();
    }
  }

  Future<Uint8List> _cropToPngBytes(ui.Image source, _CropSpec spec) async {
    final sourceWidth = source.width.toDouble();
    final sourceHeight = source.height.toDouble();
    final cropRect = ui.Rect.fromLTWH(
      sourceWidth * spec.left,
      sourceHeight * spec.top,
      sourceWidth * spec.width,
      sourceHeight * spec.height,
    );
    final outputWidth = cropRect.width.round().clamp(1, source.width);
    final outputHeight = cropRect.height.round().clamp(1, source.height);

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final paint = ui.Paint()..filterQuality = ui.FilterQuality.medium;
    canvas.drawImageRect(
      source,
      cropRect,
      ui.Rect.fromLTWH(0, 0, outputWidth.toDouble(), outputHeight.toDouble()),
      paint,
    );

    final picture = recorder.endRecording();
    final cropped = await picture.toImage(outputWidth, outputHeight);
    final byteData = await cropped.toByteData(format: ui.ImageByteFormat.png);
    picture.dispose();
    cropped.dispose();

    if (byteData == null) {
      throw StateError('Failed to encode YOLO crop ${spec.name}.');
    }
    return byteData.buffer.asUint8List();
  }

  Future<void> _ensureLoaded() {
    final existing = _loadFuture;
    if (existing != null) return existing;

    return _loadFuture = () async {
      final yolo = YOLO(
        modelPath: _modelPath,
        task: YOLOTask.detect,
        useGpu: true,
        numItemsThreshold: 10,
      );
      final loaded = await yolo.loadModel();
      if (!loaded) {
        throw StateError('Failed to load YOLO baby behavior model.');
      }
      _yolo = yolo;
    }();
  }

  Future<List<String>> _loadLabels() {
    final existing = _labelsFuture;
    if (existing != null) return existing;

    return _labelsFuture = rootBundle.loadString(_labelsPath).then(
          (raw) => raw
              .split(RegExp(r'\r?\n'))
              .map((label) => label.trim())
              .where((label) => label.isNotEmpty)
              .toList(),
        );
  }

  Iterable<Map<dynamic, dynamic>> _rawDetections(Map<String, dynamic> result) {
    final detections = result['detections'];
    if (detections is List) {
      return detections.whereType<Map>().map(Map<dynamic, dynamic>.from);
    }

    final boxes = result['boxes'];
    if (boxes is List) {
      return boxes.whereType<Map>().map(Map<dynamic, dynamic>.from);
    }

    return const [];
  }

  BabyBehaviorDetection? _parseDetection(
    Map<dynamic, dynamic> raw,
    List<String> labels,
    _ImageCandidate candidate,
  ) {
    try {
      final yoloResult = YOLOResult.fromMap(raw);
      final label = _resolveLabel(
        yoloResult.className,
        yoloResult.classIndex,
        labels,
      );
      return BabyBehaviorDetection(
        label: label,
        action: _normalizeAction(label),
        confidence: yoloResult.confidence,
        classIndex: yoloResult.classIndex,
        normalizedBox: _projectBoxToOriginal(
          _rectToMap(yoloResult.normalizedBox),
          candidate.sourceRect,
        ),
        source: candidate.name,
        sourceRect: candidate.sourceRect,
      );
    } catch (_) {
      final classIndex = _toInt(
            raw['classIndex'] ??
                raw['class_index'] ??
                raw['class'] ??
                raw['cls'],
          ) ??
          -1;
      final label = _resolveLabel(
        raw['className']?.toString() ??
            raw['class_name']?.toString() ??
            raw['label']?.toString() ??
            raw['name']?.toString(),
        classIndex,
        labels,
      );
      final confidence = _toDouble(
            raw['confidence'] ??
                raw['conf'] ??
                raw['score'] ??
                raw['probability'],
          ) ??
          0.0;
      if (label.isEmpty || confidence <= 0) return null;

      return BabyBehaviorDetection(
        label: label,
        action: _normalizeAction(label),
        confidence: confidence,
        classIndex: classIndex,
        normalizedBox: _projectBoxToOriginal(
          _normalizedBoxFromRaw(raw),
          candidate.sourceRect,
        ),
        source: candidate.name,
        sourceRect: candidate.sourceRect,
      );
    }
  }

  String _resolveLabel(String? rawLabel, int classIndex, List<String> labels) {
    final label = rawLabel?.trim() ?? '';
    if (label.isNotEmpty) return label;
    if (classIndex >= 0 && classIndex < labels.length) {
      return labels[classIndex];
    }
    return '';
  }

  String _normalizeAction(String label) {
    switch (label) {
      case 'crawl':
      case 'baby-crawling':
        return 'crawling';
      case 'baby-lifted':
        return 'lifted';
      case 'baby-lying-on-back':
        return 'lying_on_back';
      case 'baby-lying-on-left-side':
      case 'baby-lying-on-right-side':
        return 'lying_on_side';
      case 'tummy':
      case 'baby-lying-on-stomach':
        return 'tummy_time';
      case 'baby-sitting':
        return 'sitting';
      case 'baby-sitting-assisted':
        return 'sitting_assisted';
      case 'walking':
        return 'walking';
      case 'baby':
        return 'baby_detected';
      default:
        return label.replaceAll('-', '_');
    }
  }

  Map<String, double> _rectToMap(ui.Rect rect) => {
        'left': rect.left,
        'top': rect.top,
        'right': rect.right,
        'bottom': rect.bottom,
      };

  Map<String, double> _normalizedBoxFromRaw(Map<dynamic, dynamic> raw) {
    final normalizedBox = raw['normalizedBox'] ?? raw['normalized_box'];
    if (normalizedBox is Map) {
      return {
        'left': _toDouble(normalizedBox['left'] ?? normalizedBox['x1']) ?? 0.0,
        'top': _toDouble(normalizedBox['top'] ?? normalizedBox['y1']) ?? 0.0,
        'right':
            _toDouble(normalizedBox['right'] ?? normalizedBox['x2']) ?? 0.0,
        'bottom':
            _toDouble(normalizedBox['bottom'] ?? normalizedBox['y2']) ?? 0.0,
      };
    }

    return const {
      'left': 0.0,
      'top': 0.0,
      'right': 0.0,
      'bottom': 0.0,
    };
  }

  Map<String, double> _projectBoxToOriginal(
    Map<String, double> box,
    Map<String, double> sourceRect,
  ) {
    final sourceLeft = sourceRect['left'] ?? 0.0;
    final sourceTop = sourceRect['top'] ?? 0.0;
    final sourceRight = sourceRect['right'] ?? 1.0;
    final sourceBottom = sourceRect['bottom'] ?? 1.0;
    final sourceWidth = sourceRight - sourceLeft;
    final sourceHeight = sourceBottom - sourceTop;

    return {
      'left': _clamp01(sourceLeft + ((box['left'] ?? 0.0) * sourceWidth)),
      'top': _clamp01(sourceTop + ((box['top'] ?? 0.0) * sourceHeight)),
      'right': _clamp01(sourceLeft + ((box['right'] ?? 0.0) * sourceWidth)),
      'bottom': _clamp01(sourceTop + ((box['bottom'] ?? 0.0) * sourceHeight)),
    };
  }

  double _clamp01(double value) => value.clamp(0.0, 1.0).toDouble();

  Map<String, double> _rectMap(
    double left,
    double top,
    double right,
    double bottom,
  ) =>
      {
        'left': left,
        'top': top,
        'right': right,
        'bottom': bottom,
      };

  int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  double? _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  void dispose() {
    final yolo = _yolo;
    _yolo = null;
    _loadFuture = null;
    if (yolo != null) {
      unawaited(yolo.dispose());
    }
  }
}

class _ImageCandidate {
  const _ImageCandidate({
    required this.name,
    required this.bytes,
    required this.sourceRect,
  });

  final String name;
  final Uint8List bytes;
  final Map<String, double> sourceRect;
}

class _CropSpec {
  const _CropSpec({
    required this.name,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final String name;
  final double left;
  final double top;
  final double width;
  final double height;

  Map<String, double> toRectMap() => {
        'left': left,
        'top': top,
        'right': left + width,
        'bottom': top + height,
      };
}

final yoloBehaviorServiceProvider = Provider<YoloBehaviorService>((ref) {
  final service = YoloBehaviorService();
  ref.onDispose(service.dispose);
  return service;
});
