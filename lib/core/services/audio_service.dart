import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// 마이크 녹음 서비스 (음성 메모)
class AudioService {
  final AudioRecorder _recorder = AudioRecorder();

  bool _isRecording = false;
  bool get isRecording => _isRecording;

  /// 녹음 시작
  Future<void> startRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) throw Exception('마이크 권한이 없습니다.');

    final dir = await getTemporaryDirectory();
    // WAV(PCM)로 녹음 — Gemini 멀티모달 audio가 확실히 지원하는 포맷.
    final path =
        '${dir.path}/voice_memo_${DateTime.now().millisecondsSinceEpoch}.wav';

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: path,
    );

    _isRecording = true;
  }

  /// 녹음 중지 후 파일 경로 반환
  Future<String?> stopRecording() async {
    if (!_isRecording) return null;

    final path = await _recorder.stop();
    _isRecording = false;
    return path;
  }

  Future<void> dispose() async {
    if (_isRecording) await stopRecording();
    _recorder.dispose();
  }
}

final audioServiceProvider = Provider<AudioService>((ref) {
  final service = AudioService();
  ref.onDispose(() => service.dispose());
  return service;
});
