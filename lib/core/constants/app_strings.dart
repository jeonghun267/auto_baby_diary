class AppStrings {
  AppStrings._();

  // 앱 기본
  static const String appName = '아기일기';
  static const String appTagline = 'AI가 기록하는 우리 아이의 하루';

  // 인증
  static const String login = '로그인';
  static const String signup = '회원가입';
  static const String email = '이메일';
  static const String password = '비밀번호';
  static const String passwordConfirm = '비밀번호 확인';
  static const String forgotPassword = '비밀번호를 잊으셨나요?';
  static const String noAccount = '계정이 없으신가요?';
  static const String hasAccount = '이미 계정이 있으신가요?';

  // 홈
  static const String home = '홈';
  static const String record = '기록';
  static const String timeline = '타임라인';
  static const String profile = '프로필';
  static const String noDiaryForDate = '이 날의 일기가 없습니다.\n새로운 일기를 기록해보세요!';

  // 기록
  static const String startRecording = '기록 시작';
  static const String stopRecording = '기록 중지';
  static const String takePhoto = '사진 촬영';
  static const String recordVideo = '동영상 촬영';
  static const String voiceMemo = '음성 메모';
  static const String processing = 'AI가 일기를 작성하고 있어요...';

  // 일기
  static const String diaryDetail = '일기 상세';
  static const String editDiary = '일기 수정';
  static const String saveDiary = '저장';
  static const String regenerateDiary = '다시 작성';
  static const String developmentReport = '발달 리포트';
  static const String parentingTips = '육아 팁';
  static const String detectedEmotion = '감지된 감정';

  // 감정
  static const String emotionHappy = '행복';
  static const String emotionCrying = '울음';
  static const String emotionNeutral = '평온';
  static const String emotionSurprised = '놀람';
  static const String emotionSleeping = '잠';

  // 오류
  static const String errorGeneric = '오류가 발생했습니다. 다시 시도해주세요.';
  static const String errorNetwork = '네트워크 연결을 확인해주세요.';
  static const String errorCamera = '카메라에 접근할 수 없습니다.';
  static const String errorMicrophone = '마이크에 접근할 수 없습니다.';
}
