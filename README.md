# 아기일기 (Auto Baby Diary)

AI가 기록하는 우리 아이의 하루 - 멀티모달 AI 기반 자동 육아일기 앱

## 주요 기능

- **Vision AI**: ML Kit 기반 얼굴 인식으로 아이의 감정(행복/울음/평온/놀람) 자동 감지
- **음성 메모 → 텍스트**: OpenAI Whisper API로 부모의 음성 메모를 텍스트로 변환
- **AI 일기 자동 생성**: Google Gemini API가 Vision 분석 + 음성 메모를 합쳐 따뜻한 육아일기 작성
- **발달 리포트**: 아이의 현재 발달 단계 분석 및 육아 팁 제공
- **캘린더 뷰**: 날짜별 일기 조회 및 관리

## 기술 스택

| 영역 | 기술 |
|------|------|
| 프론트엔드 | Flutter (iOS + Android) |
| 백엔드/DB | Supabase (PostgreSQL + Auth + Storage + Edge Functions) |
| 얼굴 인식 | Google ML Kit (on-device) |
| 음성 인식 | OpenAI Whisper API |
| 일기 생성 | Google Gemini API |
| 상태 관리 | Riverpod |
| 네비게이션 | GoRouter |

## 사전 준비

1. **Flutter SDK** 설치 (3.2.0 이상)
   - https://docs.flutter.dev/get-started/install
2. **Supabase 계정** 생성
   - https://supabase.com
3. **OpenAI API 키** 발급 (Whisper API용)
   - https://platform.openai.com
4. **Google AI Studio API 키** 발급 (Gemini API용)
   - https://aistudio.google.com

## Supabase 프로젝트 설정

### 1. 프로젝트 생성
1. Supabase Dashboard에서 새 프로젝트 생성
2. 프로젝트 URL과 anon key를 복사

### 2. 데이터베이스 마이그레이션
```bash
# Supabase CLI 설치
npm install -g supabase

# 로그인
supabase login

# 프로젝트 연결
supabase link --project-ref <your-project-ref>

# 마이그레이션 실행
supabase db push
```

또는 Supabase Dashboard > SQL Editor에서 `supabase/migrations/001_initial_schema.sql` 내용을 직접 실행

### 3. Storage 버킷 생성
Supabase Dashboard > Storage에서:
1. `diary-media` 버킷 생성 (Public)
2. `diary-audio` 버킷 생성 (Public)

### 4. Edge Function 배포
```bash
supabase functions deploy process-diary
```

Edge Function 환경변수 설정:
```bash
supabase secrets set WHISPER_API_KEY=your-openai-key
supabase secrets set GEMINI_API_KEY=your-gemini-key
```

## 환경변수 설정

`.env.example` 파일을 `.env`로 복사하고 값을 채워주세요:

```bash
cp .env.example .env
```

```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
WHISPER_API_KEY=your-openai-api-key
GEMINI_API_KEY=your-gemini-api-key
```

## 실행 방법

```bash
# 의존성 설치
flutter pub get

# iOS 실행
flutter run -d ios

# Android 실행
flutter run -d android

# 디버그 모드로 실행
flutter run --debug
```

## 프로젝트 구조

```
lib/
├── main.dart                    # 앱 진입점
├── app.dart                     # GoRouter 설정 + MaterialApp
├── core/
│   ├── constants/               # 색상, 문자열, 환경변수 상수
│   ├── services/                # Supabase, 카메라, AI 서비스
│   └── utils/                   # 프롬프트 빌더, 날짜 포맷
├── data/
│   ├── models/                  # 데이터 모델 (DiaryEntry, VisionResult 등)
│   └── repositories/            # 데이터 접근 레이어
└── presentation/
    ├── auth/                    # 로그인/회원가입 화면
    ├── home/                    # 홈 (캘린더) 화면
    ├── record/                  # 기록 (카메라/녹음) 화면
    ├── diary/                   # 일기 상세/편집 화면
    └── widgets/                 # 공통 위젯
```

## Edge Function 배포 명령어

```bash
# 로컬 테스트
supabase functions serve process-diary

# 배포
supabase functions deploy process-diary

# 로그 확인
supabase functions logs process-diary
```
