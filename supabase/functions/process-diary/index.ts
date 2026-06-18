import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const GEMINI_API_URL =
  "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent";

const DIARY_SCHEMA = {
  type: "OBJECT",
  properties: {
    stt_transcript: { type: "STRING" },
    diary_draft: { type: "STRING" },
    development_report: { type: "STRING" },
    parenting_tips: {
      type: "ARRAY",
      items: { type: "STRING" },
    },
    milestone_detected: { type: "STRING", nullable: true },
  },
  required: ["diary_draft", "development_report", "parenting_tips"],
};

// ArrayBuffer → base64 (Deno)
function toBase64(buf: ArrayBuffer): string {
  const bytes = new Uint8Array(buf);
  let binary = "";
  for (let i = 0; i < bytes.length; i++) binary += String.fromCharCode(bytes[i]);
  return btoa(binary);
}

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

interface ProcessDiaryRequest {
  audioUrl: string;
  mediaUrl: string;
  visionData: Record<string, unknown>;
  childAgeMonths: number;
  userId: string;
  childId: string;
  // Optional 컨텍스트 — Flutter PromptBuilder와 동기화
  childName?: string;
  childGender?: string;
  recentDiaryExcerpts?: string[];
}

// PromptBuilder._summarizeVision (Dart) 미러
function summarizeVision(visionData: Record<string, unknown>): string {
  if (!visionData || Object.keys(visionData).length === 0) {
    return "(사진 없음 또는 분석 실패)";
  }
  const emotion = (visionData["emotion"] as string) ?? "neutral";
  const details = (visionData["details"] as Record<string, unknown>) ?? {};
  const faces = (details["faces_detected"] as number) ?? 0;
  if (faces === 0) {
    return "얼굴 미감지 — 아이의 뒷모습/손/발/사물 사진일 가능성. 표정 단정 금지.";
  }
  const smile = Number(details["smile_probability"] ?? 0);
  const leftEye = Number(details["left_eye_open"] ?? 0);
  const rightEye = Number(details["right_eye_open"] ?? 0);
  const eyesAvg = (leftEye + rightEye) / 2;
  const emotionKo =
    emotion === "happy"
      ? "웃는 표정"
      : emotion === "sleeping"
      ? "눈 감음 + 미소 적음 (잠든 가능성 높음)"
      : emotion === "surprised"
      ? "눈 크게 뜬 표정"
      : "평온한 표정";
  return `${emotionKo} (smile=${smile.toFixed(2)}, eyes_open_avg=${eyesAvg.toFixed(2)}, 얼굴 ${faces}개)`;
}

// PromptBuilder._milestoneReferenceFor (Dart) 미러
function milestoneReferenceFor(months: number): string {
  if (months <= 3) {
    return "- 고개 들기 (배 깔고)\n- 사물 눈으로 따라가기\n- 옹알이/사회적 미소\n- 소리에 반응하기";
  }
  if (months <= 6) {
    return "- 뒤집기\n- 손으로 사물 잡기\n- 큰 소리 내기/웃기\n- 사람 알아보기";
  }
  if (months <= 9) {
    return "- 혼자 앉기\n- 배밀이/기기 시작\n- 까꿍 놀이 반응\n- 음절 옹알이 (마마/바바)";
  }
  if (months <= 12) {
    return "- 잡고 일어서기/걷기\n- 손가락으로 가리키기\n- \"엄마/아빠\" 의미 있게\n- 컵으로 마시기 시도";
  }
  if (months <= 18) {
    return "- 혼자 걷기/계단 오르기\n- 단어 5~10개 사용\n- 숟가락 사용 시도\n- 신체 부위 가리키기";
  }
  if (months <= 24) {
    return "- 두 단어 문장 (\"물 줘\")\n- 뛰기/공 차기\n- 책 페이지 넘기기\n- 간단한 지시 따르기";
  }
  if (months <= 36) {
    return "- 문장으로 대화\n- 한 발로 잠깐 서기\n- 색깔/모양 구분\n- 가상 놀이 (소꿉)";
  }
  return "- 자기 이름 쓰기 시도\n- 가위질·블록 쌓기 정교화\n- 또래와 협동 놀이\n- 감정 단어 표현";
}

function buildDiaryPrompt(opts: {
  visionData: Record<string, unknown>;
  childAgeMonths: number;
  hasAudio: boolean;
  hasImage: boolean;
  childName?: string;
  childGender?: string;
  recentDiaryExcerpts?: string[];
}): string {
  const visionHint = summarizeVision(opts.visionData);
  const hasName = !!(opts.childName && opts.childName.trim().length > 0);
  const nameLine = hasName
    ? `${opts.childName} (${opts.childGender ?? "미상"})`
    : `우리 아기 (${opts.childGender ?? "미상"})`;
  const addressing = hasName
    ? `"${opts.childName}이/가"처럼 이름을 자연스럽게 사용`
    : `"우리 아기" 호칭 사용`;
  const excerpts = opts.recentDiaryExcerpts ?? [];
  const recentSection =
    excerpts.length === 0
      ? "(이전 일기 없음)"
      : excerpts.map((e, i) => `- (${i + 1}) ${e}`).join("\n");
  const milestoneTable = milestoneReferenceFor(opts.childAgeMonths);
  const audioSection = opts.hasAudio
    ? "첨부된 오디오는 부모가 직접 남긴 음성 메모입니다. 한국어로 정확히 받아쓰기(STT)한 뒤, 그 텍스트를 stt_transcript 필드에 그대로 넣으세요. 일기는 이 받아쓴 내용을 핵심 근거로 작성합니다."
    : "음성 메모 없음. stt_transcript는 빈 문자열로 두세요.";
  const imageSection = opts.hasImage
    ? "첨부된 사진은 오늘의 아이 모습입니다. 장면(표정·사물·상황)을 직접 보고 일기에 자연스럽게 반영하세요."
    : "사진 없음.";

  return `당신은 한국 부모를 위한 육아일기 작가입니다.
부모의 음성 메모와 사진을 바탕으로, 그날 하루의 따뜻한 일기를 부모 1인칭 시점에서 한국어로 작성하세요.

[아이 정보]
- 이름·성별: ${nameLine}
- 개월수: ${opts.childAgeMonths}개월

[음성 메모 처리]
${audioSection}

[사진 처리]
${imageSection}

[사진 분석 요약(ML Kit)]
${visionHint}

[원본 Vision 데이터(참고용)]
${JSON.stringify(opts.visionData)}

[최근 일기 발췌 — 누적 흐름·반복 표현 피하기]
${recentSection}

[이 개월수의 표준 발달 신호(한국 영유아 기준)]
${milestoneTable}

[작성 규칙]
1. 부모 1인칭 시점, 자연스러운 한국어 존댓말 또는 평어(반말체 일기) 중 하나로 일관되게.
2. ${addressing}.
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
}`;
}

serve(async (req) => {
  // CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const {
      audioUrl,
      mediaUrl,
      visionData,
      childAgeMonths,
      userId,
      childId,
      childName,
      childGender,
      recentDiaryExcerpts,
    }: ProcessDiaryRequest = await req.json();

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    // 1단계: 멀티모달 파트 준비 — 오디오/사진을 Gemini에 직접 전달
    const parts: Array<Record<string, unknown>> = [];
    const hasAudio = !!audioUrl;
    const hasImage = !!mediaUrl;

    const prompt = buildDiaryPrompt({
      visionData,
      childAgeMonths,
      hasAudio,
      hasImage,
      childName,
      childGender,
      recentDiaryExcerpts,
    });
    parts.push({ text: prompt });

    if (hasImage) {
      const imgRes = await fetch(mediaUrl);
      if (imgRes.ok) {
        const buf = await imgRes.arrayBuffer();
        parts.push({
          inline_data: { mime_type: "image/jpeg", data: toBase64(buf) },
        });
      }
    }
    if (hasAudio) {
      const audRes = await fetch(audioUrl);
      if (audRes.ok) {
        const buf = await audRes.arrayBuffer();
        parts.push({
          inline_data: { mime_type: "audio/wav", data: toBase64(buf) },
        });
      }
    }

    // 2단계: Gemini API로 STT+일기 생성 (멀티모달)
    const geminiResponse = await fetch(
      `${GEMINI_API_URL}?key=${Deno.env.get("GEMINI_API_KEY")}`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          contents: [{ parts }],
          generationConfig: {
            temperature: 0.8,
            topP: 0.9,
            maxOutputTokens: 1024,
            responseMimeType: "application/json",
            responseSchema: DIARY_SCHEMA,
          },
        }),
      }
    );

    if (!geminiResponse.ok) {
      throw new Error(
        `Gemini API error: ${geminiResponse.status} ${await geminiResponse.text()}`
      );
    }

    const geminiResult = await geminiResponse.json();
    const candidates = geminiResult.candidates;
    if (!candidates || candidates.length === 0 || !candidates[0].content?.parts?.[0]?.text) {
      throw new Error("Gemini 응답에 유효한 결과가 없습니다.");
    }
    const generatedText = candidates[0].content.parts[0].text;
    // responseMimeType=application/json 이라 응답이 곧 JSON
    const diaryResult = JSON.parse(generatedText);
    const sttTranscript = diaryResult.stt_transcript || "";

    // 3단계: diary_entries 테이블에 저장
    const { data: entry, error: insertError } = await supabase
      .from("diary_entries")
      .insert({
        user_id: userId,
        child_id: childId,
        recorded_at: new Date().toISOString(),
        vision_data: visionData,
        stt_transcript: sttTranscript,
        llm_draft: diaryResult.diary_draft,
        final_text: diaryResult.diary_draft,
        media_urls: mediaUrl ? [mediaUrl] : [],
        audio_url: audioUrl || null,
        emotion_summary: visionData?.emotion || null,
        milestone_detected: diaryResult.milestone_detected || null,
        development_report: diaryResult.development_report || null,
        parenting_tips: diaryResult.parenting_tips || [],
      })
      .select()
      .single();

    if (insertError) {
      throw new Error(`DB 저장 오류: ${insertError.message}`);
    }

    return new Response(
      JSON.stringify({
        success: true,
        diary_entry: entry,
        diary_draft: diaryResult.diary_draft,
        development_report: diaryResult.development_report,
        parenting_tips: diaryResult.parenting_tips,
        milestone_detected: diaryResult.milestone_detected,
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      }
    );
  } catch (error) {
    return new Response(
      JSON.stringify({
        success: false,
        error: error instanceof Error ? error.message : String(error),
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 500,
      }
    );
  }
});
