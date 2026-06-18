/// Vision AI 분석 결과 모델
class VisionResult {
  final String emotion;
  final double confidence;
  final DateTime timestamp;
  final Map<String, dynamic> details;

  VisionResult({
    required this.emotion,
    required this.confidence,
    required this.timestamp,
    this.details = const {},
  });

  factory VisionResult.fromJson(Map<String, dynamic> json) {
    return VisionResult(
      emotion: json['emotion'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      timestamp: DateTime.parse(json['timestamp'] as String),
      details: json['details'] as Map<String, dynamic>? ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'emotion': emotion,
      'confidence': confidence,
      'timestamp': timestamp.toIso8601String(),
      'details': details,
    };
  }
}
