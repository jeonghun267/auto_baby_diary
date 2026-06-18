import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'core/providers/app_providers.dart';
import 'core/services/notification_service.dart';
import 'core/services/supabase_service.dart';
import 'core/services/video_frame_extractor_service.dart';
import 'core/services/yolo_behavior_service.dart';
import 'core/services/yolo_video_behavior_service.dart';
import 'app.dart';

void main() async {
  // ── 플랫폼 바인딩 초기화 ──
  WidgetsFlutterBinding.ensureInitialized();

  // ── 시스템 UI 오버레이 스타일 ──
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // ── 화면 방향 고정 (세로) ──
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // ── 에러 핸들링 ──
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('[FlutterError] ${details.exceptionAsString()}');
    debugPrint('[FlutterError] ${details.stack}');
  };

  // ── 초기화 (에러 안전) ──
  await _initializeApp();

  if (kDebugMode) {
    _registerDebugServiceExtensions();
  }

  // ── 마지막으로 선택된 아이 ID 로드 (앱 재시작 시 유지) ──
  final savedChildId = await loadLastSelectedChildId();

  // ── 앱 실행 ──
  runApp(
    ProviderScope(
      overrides: [
        selectedChildIdProvider.overrideWith((ref) => savedChildId),
      ],
      child: const AutoBabyDiaryApp(),
    ),
  );
}

/// 앱 초기화 - 환경변수, Supabase, 권한 요청
Future<void> _initializeApp() async {
  try {
    // 환경변수 로드
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('[Init] .env 로드 실패: $e');
  }

  try {
    // Supabase 초기화
    await SupabaseService.initialize();
    debugPrint('[Init] Supabase 초기화 완료');
  } catch (e) {
    debugPrint('[Init] Supabase 초기화 실패: $e');
  }

  try {
    // 로컬 알림 초기화 (채널 + 시간대)
    await NotificationService.initialize();
    debugPrint('[Init] 알림 초기화 완료');
  } catch (e) {
    debugPrint('[Init] 알림 초기화 실패: $e');
  }

  // 권한 요청 (비차단 - 실패해도 앱 실행에 영향 없음)
  unawaited(_requestPermissions());
}

/// 카메라, 마이크 권한 요청
Future<void> _requestPermissions() async {
  try {
    final statuses = await [
      Permission.camera,
      Permission.microphone,
    ].request();

    for (final entry in statuses.entries) {
      final name = entry.key.toString();
      final status = entry.value;
      if (status.isGranted) {
        debugPrint('[Permission] $name: 허용됨');
      } else if (status.isDenied) {
        debugPrint('[Permission] $name: 거부됨');
      } else if (status.isPermanentlyDenied) {
        debugPrint('[Permission] $name: 영구 거부됨 - 설정에서 변경 필요');
      }
    }
  } catch (e) {
    debugPrint('[Permission] 권한 요청 실패: $e');
  }
}

void _registerDebugServiceExtensions() {
  developer.registerExtension(
    'ext.autoBabyDiary.runYoloVideoTest',
    (method, parameters) async {
      final path = parameters['path'];
      if (path == null || path.isEmpty) {
        return developer.ServiceExtensionResponse.result(
          jsonEncode({
            'ok': false,
            'error': 'Missing required path parameter.',
          }),
        );
      }

      final maxFrames = int.tryParse(parameters['maxFrames'] ?? '') ?? 12;
      final behaviorService = YoloBehaviorService();

      try {
        final result = await YoloVideoBehaviorService(
          VideoFrameExtractorService(maxFrames: maxFrames),
          behaviorService,
        ).analyzeVideo(path);
        final payload = {
          'ok': true,
          'path': path,
          ...result.toJson(),
        };
        debugPrint('[YOLO VM Test] ${jsonEncode(payload)}');
        return developer.ServiceExtensionResponse.result(jsonEncode(payload));
      } catch (e, st) {
        final payload = {
          'ok': false,
          'path': path,
          'error': e.toString(),
          'stack': st.toString(),
        };
        debugPrint('[YOLO VM Test] ${jsonEncode(payload)}');
        return developer.ServiceExtensionResponse.result(jsonEncode(payload));
      } finally {
        behaviorService.dispose();
      }
    },
  );
}
