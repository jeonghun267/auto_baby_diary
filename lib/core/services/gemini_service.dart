import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../constants/env.dart';
import '../utils/prompt_builder.dart';

/// Gemini API를 이용한 일기 생성 서비스
class GeminiService {
  static const String _apiUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent';

  /// 일기 응답 구조화 출력 스키마 (Gemini responseSchema)
  static const Map<String, dynamic> _diarySchema = {
    'type': 'OBJECT',
    'properties': {
      'stt_transcript': {'type': 'STRING'},
      'diary_draft': {'type': 'STRING'},
      'development_report': {'type': 'STRING'},
      'parenting_tips': {
        'type': 'ARRAY',
        'items': {'type': 'STRING'},
      },
      'milestone_detected': {'type': 'STRING', 'nullable': true},
    },
    'required': ['diary_draft', 'development_report', 'parenting_tips'],
  };

  /// 음성(오디오)·사진을 Gemini 멀티모달로 직접 전달해 STT+일기를 한 번에 생성.
  ///
  /// [audioPath] WAV 음성 메모, [imagePath] JPEG 사진(동영상은 전달 안 함).
  /// [existingTranscript] 재생성처럼 오디오 파일이 없을 때 기존 받아쓴 텍스트를
  /// 음성 메모 대용으로 프롬프트에 넣는다.
  Future<DiaryGenerationResult> generateDiary({
    required Map<String, dynamic> visionData,
    required int childAgeMonths,
    String? audioPath,
    String? imagePath,
    String? existingTranscript,
    String? childName,
    String? childGender,
    List<String> recentDiaryExcerpts = const [],
  }) async {
    Object? firstError;
    StackTrace? firstStackTrace;
    final attemptedKeys = <String>{};

    Future<DiaryGenerationResult?> attempt({
      required String label,
      required String? candidateAudioPath,
      required String? candidateImagePath,
      Map<String, dynamic>? extraVisionData,
    }) async {
      final key = '$candidateAudioPath|$candidateImagePath';
      if (!attemptedKeys.add(key)) return null;

      try {
        return await _generateDiaryRequest(
          visionData: {
            ...visionData,
            if (extraVisionData != null) ...extraVisionData,
          },
          childAgeMonths: childAgeMonths,
          audioPath: candidateAudioPath,
          imagePath: candidateImagePath,
          existingTranscript: existingTranscript,
          childName: childName,
          childGender: childGender,
          recentDiaryExcerpts: recentDiaryExcerpts,
        );
      } catch (e, st) {
        firstError ??= e;
        firstStackTrace ??= st;
        debugPrint('[Gemini] diary generation attempt failed ($label): $e');
        debugPrint('$st');
        return null;
      }
    }

    final original = await attempt(
      label: 'original',
      candidateAudioPath: audioPath,
      candidateImagePath: imagePath,
    );
    if (original != null) return original;

    if (imagePath != null) {
      final withoutImage = await attempt(
        label: 'without image',
        candidateAudioPath: audioPath,
        candidateImagePath: null,
        extraVisionData: {
          'image_generation_fallback': true,
          'image_generation_error': firstError.toString(),
        },
      );
      if (withoutImage != null) return withoutImage;
    }

    if (audioPath != null) {
      final withoutAudio = await attempt(
        label: 'without audio',
        candidateAudioPath: null,
        candidateImagePath: imagePath,
        extraVisionData: {
          'audio_generation_fallback': true,
          'audio_generation_error': firstError.toString(),
        },
      );
      if (withoutAudio != null) return withoutAudio;
    }

    if (imagePath != null && audioPath != null) {
      final textOnly = await attempt(
        label: 'without image and audio',
        candidateAudioPath: null,
        candidateImagePath: null,
        extraVisionData: {
          'image_generation_fallback': true,
          'audio_generation_fallback': true,
          'media_generation_error': firstError.toString(),
        },
      );
      if (textOnly != null) return textOnly;
    }

    Error.throwWithStackTrace(firstError!, firstStackTrace!);
  }

  Future<DiaryGenerationResult> _generateDiaryRequest({
    required Map<String, dynamic> visionData,
    required int childAgeMonths,
    String? audioPath,
    String? imagePath,
    String? existingTranscript,
    String? childName,
    String? childGender,
    List<String> recentDiaryExcerpts = const [],
  }) async {
    final hasAudio = audioPath != null;
    final hasImage = imagePath != null;
    final prompt = PromptBuilder.buildDiaryPrompt(
      visionData: visionData,
      childAgeMonths: childAgeMonths,
      hasAudio: hasAudio,
      hasImage: hasImage,
      existingTranscript: existingTranscript,
      childName: childName,
      childGender: childGender,
      recentDiaryExcerpts: recentDiaryExcerpts,
    );

    final requestParts = <Map<String, dynamic>>[
      {'text': prompt},
    ];
    if (hasImage) {
      final bytes = await File(imagePath).readAsBytes();
      requestParts.add({
        'inline_data': {
          'mime_type': 'image/jpeg',
          'data': base64Encode(bytes),
        },
      });
    }
    if (hasAudio) {
      final bytes = await File(audioPath).readAsBytes();
      requestParts.add({
        'inline_data': {
          'mime_type': 'audio/wav',
          'data': base64Encode(bytes),
        },
      });
    }

    final response = await _postWithRetry(
      {
        'contents': [
          {'parts': requestParts},
        ],
        'generationConfig': {
          'temperature': 0.8,
          'topP': 0.9,
          'maxOutputTokens': 4096,
          'thinkingConfig': {'thinkingBudget': 1024},
          'responseMimeType': 'application/json',
          'responseSchema': _diarySchema,
        },
      },
      timeout: const Duration(seconds: 90),
    );

    final text = _extractText(response);
    final result = jsonDecode(text) as Map<String, dynamic>;
    return DiaryGenerationResult.fromJson(result);
  }

  /// Gemini POST + 일시적 오류(429/500/502/503) 지수 백오프 재시도
  Future<http.Response> _postWithRetry(
    Map<String, dynamic> body, {
    Duration timeout = const Duration(seconds: 60),
  }) async {
    const transient = {429, 500, 502, 503};
    const maxAttempts = 3;
    http.Response? last;
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      final response = await http
          .post(
        Uri.parse('$_apiUrl?key=${Env.geminiApiKey}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      )
          .timeout(timeout, onTimeout: () {
        throw Exception('Gemini API 응답 시간이 초과되었습니다.');
      });

      if (response.statusCode == 200) return response;
      last = response;
      if (transient.contains(response.statusCode) && attempt < maxAttempts) {
        await Future.delayed(Duration(seconds: attempt * 2)); // 2s, 4s
        continue;
      }
      break;
    }
    throw Exception('Gemini API 오류: ${last?.statusCode} - ${last?.body}');
  }

  /// Gemini 응답에서 첫 번째 텍스트 파트 추출
  static String _extractText(http.Response response) {
    final data = jsonDecode(response.body);
    final candidates = data['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      throw Exception('Gemini 응답에 유효한 결과가 없습니다.');
    }
    final finishReason = candidates[0]['finishReason'] as String?;
    final content = candidates[0]['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List?;
    if (parts == null || parts.isEmpty || parts[0]['text'] == null) {
      if (finishReason == 'MAX_TOKENS') {
        throw Exception('Gemini 출력이 토큰 한도로 잘렸습니다(MAX_TOKENS). '
            'maxOutputTokens/thinkingBudget을 조정하세요.');
      }
      throw Exception('Gemini 응답에서 텍스트를 찾을 수 없습니다.');
    }
    return parts[0]['text'] as String;
  }

  /// Gemini API에 텍스트 프롬프트를 보내고 응답 텍스트를 반환
  Future<String> _generateText(String prompt) async {
    final response = await _postWithRetry({
      'contents': [
        {
          'parts': [
            {'text': prompt},
          ],
        },
      ],
      'generationConfig': {
        'temperature': 0.8,
        'topP': 0.9,
        'maxOutputTokens': 2048,
        'thinkingConfig': {'thinkingBudget': 512},
      },
    });
    return _extractText(response);
  }

  /// 주간 요약 생성
  Future<String> generateWeeklySummary({
    required List<String> diaryTexts,
    required int childAgeMonths,
  }) async {
    final prompt = PromptBuilder.buildWeeklySummaryPrompt(
      diaryTexts: diaryTexts,
      childAgeMonths: childAgeMonths,
    );
    return _generateText(prompt);
  }

  /// 월간 발달 리포트 생성
  Future<String> generateMonthlyReport({
    required Map<String, dynamic> monthlyData,
  }) async {
    final diaryTexts = (monthlyData['diary_texts'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    final childAgeMonths = monthlyData['child_age_months'] as int? ?? 0;
    final growthData = monthlyData['growth_data'] as Map<String, dynamic>?;
    final milestones = (monthlyData['milestones'] as List<dynamic>?)
        ?.map((e) => e.toString())
        .toList();

    final prompt = PromptBuilder.buildMonthlyReportPrompt(
      diaryTexts: diaryTexts,
      childAgeMonths: childAgeMonths,
      growthData: growthData,
      milestones: milestones,
    );
    return _generateText(prompt);
  }
}

class DiaryGenerationResult {
  final String sttTranscript;
  final String diaryDraft;
  final String developmentReport;
  final List<String> parentingTips;
  final String? milestoneDetected;

  DiaryGenerationResult({
    this.sttTranscript = '',
    required this.diaryDraft,
    required this.developmentReport,
    required this.parentingTips,
    this.milestoneDetected,
  });

  factory DiaryGenerationResult.fromJson(Map<String, dynamic> json) {
    final milestoneRaw = json['milestone_detected'] as String?;
    return DiaryGenerationResult(
      sttTranscript: json['stt_transcript'] as String? ?? '',
      diaryDraft: json['diary_draft'] as String? ?? '',
      developmentReport: json['development_report'] as String? ?? '',
      parentingTips: (json['parenting_tips'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      milestoneDetected:
          (milestoneRaw != null && milestoneRaw.trim().isNotEmpty)
              ? milestoneRaw.trim()
              : null,
    );
  }
}

final geminiServiceProvider = Provider<GeminiService>((ref) {
  return GeminiService();
});
