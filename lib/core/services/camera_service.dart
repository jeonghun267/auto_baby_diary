import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

/// 카메라 제어 서비스 (사진/동영상 촬영)
class CameraService {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];

  CameraController? get controller => _controller;
  bool get isInitialized => _controller?.value.isInitialized ?? false;

  Future<void> initialize({
    CameraLensDirection direction = CameraLensDirection.back,
  }) async {
    _cameras = await availableCameras();
    if (_cameras.isEmpty) throw Exception('카메라를 찾을 수 없습니다.');

    final camera = _cameras.firstWhere(
      (c) => c.lensDirection == direction,
      orElse: () => _cameras.first,
    );

    _controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
    );

    await _controller!.initialize();
  }

  /// 사진 촬영 후 파일 경로 반환
  Future<String> takePhoto() async {
    if (!isInitialized) throw Exception('카메라가 초기화되지 않았습니다.');

    final file = await _controller!.takePicture();
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await File(file.path).copy(path);
    return path;
  }

  bool _isRecordingVideo = false;
  bool get isRecordingVideo => _isRecordingVideo;

  /// 동영상 녹화 시작
  Future<void> startVideoRecording() async {
    if (!isInitialized) throw Exception('카메라가 초기화되지 않았습니다.');
    if (_isRecordingVideo) throw Exception('이미 녹화 중입니다.');
    await _controller!.startVideoRecording();
    _isRecordingVideo = true;
  }

  /// 동영상 녹화 중지 후 파일 경로 반환
  Future<String> stopVideoRecording() async {
    if (!isInitialized) throw Exception('카메라가 초기화되지 않았습니다.');
    if (!_isRecordingVideo) throw Exception('녹화가 진행 중이 아닙니다.');

    final file = await _controller!.stopVideoRecording();
    _isRecordingVideo = false;
    return file.path;
  }

  /// 전면/후면 카메라 전환
  Future<void> switchCamera() async {
    if (_cameras.length < 2) return;

    final currentDirection = _controller?.description.lensDirection;
    final newDirection = currentDirection == CameraLensDirection.back
        ? CameraLensDirection.front
        : CameraLensDirection.back;

    await dispose();
    await initialize(direction: newDirection);
  }

  Future<void> dispose() async {
    await _controller?.dispose();
    _controller = null;
  }
}

final cameraServiceProvider = Provider<CameraService>((ref) {
  final service = CameraService();
  ref.onDispose(() => service.dispose());
  return service;
});
