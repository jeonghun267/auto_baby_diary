import 'dart:convert';

/// Gemini에 전달할 구조화된 프롬프트 빌더
class PromptBuilder {
  PromptBuilder._();

  /// 육아일기 생성 프롬프트 (Gemini 멀티모달)
  ///
  /// 부모 음성은 별도 STT 없이 첨부 오디오로 직접 전달 → Gemini가 받아쓰기 후
  /// 받아쓴 텍스트를 `stt_transcript`에 그대로 채우고 일기를 작성한다.
  /// [hasAudio]/[hasImage]는 실제 첨부 여부. [childName]이 비면 "우리 아기" 호칭.
  static String buildDiaryPrompt({
    required Map<String, dynamic> visionData,
    required int childAgeMonths,
    bool hasAudio = false,
    bool hasImage = false,
    String? existingTranscript,
    String? childName,
    String? childGender,
    List<String> recentDiaryExcerpts = const [],
  }) {
    final visionHint = _summarizeVision(visionData);
    final nameLine = (childName != null && childName.trim().isNotEmpty)
        ? '$childName (${childGender ?? '미상'})'
        : '우리 아기 (${childGender ?? '미상'})';
    final addressing = (childName != null && childName.trim().isNotEmpty)
        ? '"$childName이/가"처럼 이름을 자연스럽게 사용'
        : '"우리 아기" 호칭 사용';

    final recentSection = recentDiaryExcerpts.isEmpty
        ? '(이전 일기 없음)'
        : recentDiaryExcerpts
            .asMap()
            .entries
            .map((e) => '- (${e.key + 1}) ${e.value}')
            .join('\n');

    final milestoneTable = _milestoneReferenceFor(childAgeMonths);

    final hasExistingText =
        existingTranscript != null && existingTranscript.trim().isNotEmpty;
    final hasVideoBehavior = visionData['video_behavior'] is Map ||
        visionData.containsKey('video_behavior_error');
    final audioSection = hasAudio
        ? '첨부된 오디오는 부모가 직접 남긴 음성 메모입니다. 한국어로 정확히 받아쓰기(STT)한 뒤, 그 텍스트를 stt_transcript 필드에 그대로 넣으세요. 일기는 이 받아쓴 내용을 핵심 근거로 작성합니다.'
        : hasExistingText
            ? '부모 음성 메모(이미 받아쓴 텍스트): "${existingTranscript.trim()}"\n이 텍스트를 stt_transcript에 그대로 넣고, 핵심 근거로 일기를 작성하세요.'
            : '음성 메모 없음. stt_transcript는 빈 문자열로 두세요.';
    final imageSection = hasImage
        ? '첨부된 사진은 오늘의 아이 모습입니다. 장면(표정·행동·상황)을 직접 보고 일기에 자연스럽게 반영하세요.'
        : hasVideoBehavior
            ? '동영상은 직접 첨부하지 않고 YOLO 프레임 분석 요약으로 전달됩니다.'
            : '사진 없음.';

    return '''
당신은 한국 부모를 위한 육아일기 작가입니다.
부모의 음성 메모와 사진을 바탕으로, 그날 하루의 따뜻한 일기를 부모 1인칭 시점에서 한국어로 작성하세요.

[아이 정보]
- 이름·성별: $nameLine
- 개월수: $childAgeMonths개월

[음성 메모 처리]
$audioSection

[사진 처리]
$imageSection

[사진 분석 요약(ML Kit + YOLO)]
$visionHint

[원본 Vision 데이터(참고용)]
${jsonEncode(visionData)}

[최근 일기 발췌 — 누적 흐름·반복 표현 피하기]
$recentSection

[이 개월수의 표준 발달 신호(한국 영유아 기준)]
$milestoneTable

[작성 규칙]
1. 부모 1인칭 시점, 자연스러운 한국어 존댓말 또는 평어(반말체 일기) 중 하나로 일관되게.
2. $addressing.
3. 사실 위주로, 사진/음성에 없는 정보는 만들어내지 말 것. 추측은 "~인 것 같다" 정도로 약하게.
4. 이모지·해시태그·광고체("최고예요!", "강추")·의학적 단정 금지.
5. diary_draft는 200~300자, development_report는 80~120자.
6. parenting_tips는 부모가 오늘 바로 시도할 수 있는 구체 행동 3개 (단정형, 각 40자 이내).
7. milestone_detected: 음성·사진에서 위 발달 신호 중 하나가 명확히 관찰되면 그 항목명만, 아니면 null.
8. 최근 일기와 표현·소재가 겹치지 않게 다른 결로 작성.
9. stt_transcript: 첨부 오디오를 받아쓴 원문 그대로(일기체로 다듬지 말 것). 오디오 없으면 빈 문자열.

다음 JSON 형식으로만 응답하세요(다른 텍스트·코드블록 없이):
{
  "stt_transcript": "...",
  "diary_draft": "...",
  "development_report": "...",
  "parenting_tips": ["...", "...", "..."],
  "milestone_detected": "발달 신호명 또는 null"
}
''';
  }

  /// Summarizes face and baby/video-behavior signals for the Gemini prompt.
  static String _summarizeVision(Map<String, dynamic> visionData) {
    final behaviorSummary = _summarizeBabyBehavior(visionData);
    final videoBehaviorSummary = _summarizeVideoBehavior(visionData);
    final summaries = <String>[];

    if (visionData.isEmpty) {
      return _joinVisionSummaries([
        '(no image or image analysis failed)',
        behaviorSummary,
        videoBehaviorSummary,
      ]);
    }

    final rawDetails = visionData['details'];
    final hasFaceDetails = rawDetails is Map;
    if (!hasFaceDetails) {
      return _joinVisionSummaries([
        'ML Kit face: not run for this media. Avoid guessing a facial expression.',
        behaviorSummary,
        videoBehaviorSummary,
      ]);
    }

    final emotion = visionData['emotion'] as String? ?? 'neutral';
    final details = rawDetails;
    final faces = (details['faces_detected'] as num?)?.toInt() ?? 0;
    if (faces == 0) {
      return _joinVisionSummaries([
        'ML Kit face: no face detected. Avoid guessing a facial expression.',
        behaviorSummary,
        videoBehaviorSummary,
      ]);
    }

    final smile = (details['smile_probability'] as num?)?.toDouble() ?? 0.0;
    final leftEye = (details['left_eye_open'] as num?)?.toDouble() ?? 0.0;
    final rightEye = (details['right_eye_open'] as num?)?.toDouble() ?? 0.0;
    final eyesAvg = (leftEye + rightEye) / 2;

    final emotionText = switch (emotion) {
      'happy' => 'happy or smiling',
      'sleeping' => 'eyes closed, likely sleeping',
      'surprised' => 'wide-eyed or alert',
      _ => 'neutral or unclear',
    };

    summaries.add(
      'ML Kit face: $emotionText '
      '(smile=${smile.toStringAsFixed(2)}, '
      'eyes_open_avg=${eyesAvg.toStringAsFixed(2)}, faces=$faces).',
    );
    summaries.add(behaviorSummary);
    summaries.add(videoBehaviorSummary);
    return _joinVisionSummaries(summaries);
  }

  static String _summarizeBabyBehavior(Map<String, dynamic> visionData) {
    final behavior = visionData['baby_behavior'];
    if (behavior is Map) {
      final action = behavior['primary_action']?.toString();
      final label = behavior['primary_label']?.toString();
      final confidence = (behavior['confidence'] as num?)?.toDouble();
      final detectionsRaw = behavior['detections'];
      final detectionCount = detectionsRaw is List ? detectionsRaw.length : 0;

      if (action == null || action == 'null' || action.isEmpty) {
        return 'YOLO baby behavior: no confident behavior detected.';
      }

      final confidenceText =
          confidence == null ? 'unknown' : confidence.toStringAsFixed(2);
      return 'YOLO baby behavior: $action '
          '(label=${label ?? 'unknown'}, confidence=$confidenceText, '
          'detections=$detectionCount).';
    }

    if (visionData.containsKey('baby_behavior_error')) {
      return 'YOLO baby behavior: analysis unavailable.';
    }

    return '';
  }

  static String _summarizeVideoBehavior(Map<String, dynamic> visionData) {
    final behavior = visionData['video_behavior'];
    if (behavior is Map) {
      final action = behavior['primary_action']?.toString();
      final label = behavior['primary_label']?.toString();
      final confidence = (behavior['confidence'] as num?)?.toDouble();
      final framesAnalyzed =
          (behavior['frames_analyzed'] as num?)?.toInt() ?? 0;
      final requestedFrames =
          (behavior['requested_frames'] as num?)?.toInt() ?? 0;
      final durationMs = (behavior['video_duration_ms'] as num?)?.toInt();

      if (action == null || action == 'null' || action.isEmpty) {
        return 'YOLO video behavior: analyzed $framesAnalyzed/$requestedFrames frames, no confident behavior detected.';
      }

      final confidenceText =
          confidence == null ? 'unknown' : confidence.toStringAsFixed(2);
      final durationText = durationMs == null
          ? 'unknown'
          : (durationMs / 1000).toStringAsFixed(1);
      return 'YOLO video behavior: $action '
          '(label=${label ?? 'unknown'}, confidence=$confidenceText, '
          'frames=$framesAnalyzed/$requestedFrames, duration=${durationText}s).';
    }

    if (visionData.containsKey('video_behavior_error')) {
      return 'YOLO video behavior: analysis unavailable.';
    }

    return '';
  }

  static String _joinVisionSummaries(List<String> summaries) {
    return summaries.where((summary) => summary.trim().isNotEmpty).join('\n');
  }

  /// 개월수별 한국 영유아검진 발달 신호 (압축)
  static String _milestoneReferenceFor(int months) {
    if (months <= 3) {
      return '- 고개 들기 (배 깔고)\n- 사물 눈으로 따라가기\n- 옹알이/사회적 미소\n- 소리에 반응하기';
    }
    if (months <= 6) {
      return '- 뒤집기\n- 손으로 사물 잡기\n- 큰 소리 내기/웃기\n- 사람 알아보기';
    }
    if (months <= 9) {
      return '- 혼자 앉기\n- 배밀이/기기 시작\n- 까꿍 놀이 반응\n- 음절 옹알이 (마마/바바)';
    }
    if (months <= 12) {
      return '- 잡고 일어서기/걷기\n- 손가락으로 가리키기\n- "엄마/아빠" 의미 있게\n- 컵으로 마시기 시도';
    }
    if (months <= 18) {
      return '- 혼자 걷기/계단 오르기\n- 단어 5~10개 사용\n- 숟가락 사용 시도\n- 신체 부위 가리키기';
    }
    if (months <= 24) {
      return '- 두 단어 문장 ("물 줘")\n- 뛰기/공 차기\n- 책 페이지 넘기기\n- 간단한 지시 따르기';
    }
    if (months <= 36) {
      return '- 문장으로 대화\n- 한 발로 잠깐 서기\n- 색깔/모양 구분\n- 가상 놀이 (소꿉)';
    }
    return '- 자기 이름 쓰기 시도\n- 가위질·블록 쌓기 정교화\n- 또래와 협동 놀이\n- 감정 단어 표현';
  }

  /// 주간 요약 프롬프트
  static String buildWeeklySummaryPrompt({
    required List<String> diaryTexts,
    required int childAgeMonths,
  }) {
    final diaryList = diaryTexts
        .asMap()
        .entries
        .map((e) => '${e.key + 1}. ${e.value}')
        .join('\n');

    return '''
당신은 따뜻하고 감성적인 육아 요약 작가입니다.
아래는 지난 한 주간의 육아일기 목록입니다.

[아이 나이]
$childAgeMonths개월

[이번 주 일기들]
$diaryList

위 일기들을 바탕으로 이번 한 주를 따뜻하게 요약해주세요.
- 150자 이내로 작성
- 한국어로 작성
- 아이의 성장과 일상의 소중한 순간을 담아주세요
- JSON이 아닌 일반 텍스트로만 응답하세요
''';
  }

  /// 월간 발달 리포트 프롬프트
  static String buildMonthlyReportPrompt({
    required List<String> diaryTexts,
    required int childAgeMonths,
    Map<String, dynamic>? growthData,
    List<String>? milestones,
  }) {
    final diaryList = diaryTexts
        .asMap()
        .entries
        .map((e) => '${e.key + 1}. ${e.value}')
        .join('\n');

    final growthSection =
        growthData != null ? '\n[성장 데이터]\n${jsonEncode(growthData)}' : '';

    final milestoneSection = milestones != null && milestones.isNotEmpty
        ? '\n[달성한 마일스톤]\n${milestones.join(', ')}'
        : '';

    return '''
당신은 전문적이고 따뜻한 아이 발달 분석가입니다.
아래 데이터를 바탕으로 이번 달의 종합 발달 리포트를 작성해주세요.

[아이 나이]
$childAgeMonths개월

[이번 달 일기들]
$diaryList
$growthSection
$milestoneSection

다음 내용을 포함하여 한국어로 종합 리포트를 작성해주세요:
1. 이번 달 주요 성장 포인트
2. 정서 발달 관찰
3. 신체 발달 상태 (성장 데이터가 있는 경우)
4. 다음 달 기대되는 발달 사항
5. 부모를 위한 격려 메시지

- 전체 500자 내외로 작성
- JSON이 아닌 일반 텍스트로만 응답하세요
''';
  }
}
