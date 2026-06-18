import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../../data/models/vision_result.dart';

/// ML Kit 기반 얼굴 감지 + 감정 분류 서비스
class VisionService {
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true, // 웃음 확률, 눈 뜨기 확률
      enableTracking: true,
      enableLandmarks: true,
      enableContours: false,
      performanceMode: FaceDetectorMode.accurate,
    ),
  );

  /// 이미지에서 얼굴을 분석하고 감정을 분류
  Future<VisionResult> analyzeImage(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final faces = await _faceDetector.processImage(inputImage);

    if (faces.isEmpty) {
      return VisionResult(
        emotion: 'neutral',
        confidence: 0.0,
        timestamp: DateTime.now(),
        details: {'faces_detected': 0},
      );
    }

    // 가장 큰 얼굴 기준으로 분석
    final face = faces.reduce((a, b) =>
        (a.boundingBox.width * a.boundingBox.height) >
                (b.boundingBox.width * b.boundingBox.height)
            ? a
            : b);

    final emotion = _classifyEmotion(face);
    final confidence = _calculateConfidence(face, emotion);

    return VisionResult(
      emotion: emotion,
      confidence: confidence,
      timestamp: DateTime.now(),
      details: {
        'faces_detected': faces.length,
        'smile_probability': face.smilingProbability ?? 0.0,
        'left_eye_open': face.leftEyeOpenProbability ?? 0.0,
        'right_eye_open': face.rightEyeOpenProbability ?? 0.0,
        'head_euler_x': face.headEulerAngleX ?? 0.0,
        'head_euler_y': face.headEulerAngleY ?? 0.0,
        'head_euler_z': face.headEulerAngleZ ?? 0.0,
      },
    );
  }

  /// 얼굴 특성을 기반으로 감정 분류
  ///
  /// ML Kit FaceDetector는 표정 단서로 `smilingProbability`와 `*EyeOpenProbability`
  /// 두 가지만 제공하므로 "울음"을 신뢰성 있게 분류할 수 없습니다(입 벌림 정보 없음).
  /// 눈 감음 + 낮은 미소는 잠일 가능성이 더 높아 `sleeping`으로 분류합니다.
  /// 실제 정서(울음/짜증 등)는 부모 음성 메모로 LLM이 해석.
  String _classifyEmotion(Face face) {
    final smileProb = face.smilingProbability ?? 0.0;
    final leftEyeOpen = face.leftEyeOpenProbability ?? 0.0;
    final rightEyeOpen = face.rightEyeOpenProbability ?? 0.0;

    if (smileProb > 0.7) return 'happy';

    if (leftEyeOpen < 0.3 && rightEyeOpen < 0.3 && smileProb < 0.2) {
      return 'sleeping';
    }

    if (leftEyeOpen > 0.9 && rightEyeOpen > 0.9 && smileProb < 0.3) {
      return 'surprised';
    }

    return 'neutral';
  }

  /// 감정 분류의 신뢰도 계산
  double _calculateConfidence(Face face, String emotion) {
    final smileProb = face.smilingProbability ?? 0.0;
    final leftEyeOpen = face.leftEyeOpenProbability ?? 0.0;
    final rightEyeOpen = face.rightEyeOpenProbability ?? 0.0;

    switch (emotion) {
      case 'happy':
        return smileProb;
      case 'sleeping':
        return (1 - leftEyeOpen + 1 - rightEyeOpen + 1 - smileProb) / 3;
      case 'surprised':
        return (leftEyeOpen + rightEyeOpen) / 2;
      default:
        return 0.5;
    }
  }

  void dispose() {
    _faceDetector.close();
  }
}

final visionServiceProvider = Provider<VisionService>((ref) {
  final service = VisionService();
  ref.onDispose(() => service.dispose());
  return service;
});
