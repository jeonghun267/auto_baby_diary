/// 모든 화면에서 공통으로 사용하는 에러 메시지 매핑
///
/// 각 화면에 흩어져있던 _humanError 함수들을 통합.
/// 새로운 에러 케이스가 발견되면 여기 한 군데만 수정하면 됨.
class ErrorMapper {
  ErrorMapper._();

  /// 일반 에러 → 사용자에게 보여줄 한국어 메시지
  /// [fallback]: 매칭되는 케이스가 없을 때 보여줄 기본 메시지
  static String map(Object error, {String? fallback}) {
    final raw = error.toString().toLowerCase();

    // 네트워크
    if (_isNetwork(raw)) {
      return '네트워크 연결이 불안정해요.\n인터넷을 확인해주세요.';
    }
    // 시간 초과
    if (raw.contains('timeout')) {
      return '응답이 지연되고 있어요. 잠시 후 다시 시도해주세요.';
    }
    // 권한 / RLS
    if (_isPermission(raw)) {
      return '권한이 없어요. 다시 로그인해주세요.';
    }
    // DB 스키마
    if (raw.contains('column') && raw.contains('does not exist')) {
      return '데이터베이스 업데이트가 필요해요. 관리자에게 문의해주세요.';
    }
    // Storage
    if (raw.contains('storage') || raw.contains('bucket')) {
      return '파일 업로드에 실패했어요. 다시 시도해주세요.';
    }
    // Rate limit
    if (raw.contains('rate') || raw.contains('too many')) {
      return '시도가 너무 많아요. 잠시 후 다시 시도해주세요.';
    }
    return fallback ?? '잠시 후 다시 시도해주세요.';
  }

  /// 인증(로그인) 관련 에러 메시지
  static String mapAuth(Object error) {
    final raw = error.toString().toLowerCase();

    if (raw.contains('invalid login') ||
        raw.contains('invalid_credentials') ||
        raw.contains('invalid grant')) {
      return '이메일 또는 비밀번호가 올바르지 않아요.';
    }
    if (raw.contains('email not confirmed') || raw.contains('not_confirmed')) {
      return '이메일 인증이 완료되지 않았어요. 받은 메일을 확인해주세요.';
    }
    if (raw.contains('user not found') || raw.contains('not found')) {
      return '존재하지 않는 계정이에요. 회원가입을 진행해주세요.';
    }
    if (raw.contains('rate') || raw.contains('too many')) {
      return '시도가 너무 많아요. 1분 후 다시 시도해주세요.';
    }
    if (_isNetwork(raw) || raw.contains('timeout')) {
      return '네트워크 연결을 확인해주세요.';
    }
    return '로그인에 실패했어요. 잠시 후 다시 시도해주세요.';
  }

  /// 회원가입 관련 에러
  static String mapSignup(Object error) {
    final raw = error.toString().toLowerCase();

    if (raw.contains('already registered') ||
        raw.contains('already exists') ||
        raw.contains('user already')) {
      return '이미 가입된 이메일이에요.';
    }
    if (raw.contains('invalid') && raw.contains('email')) {
      return '올바른 이메일 형식이 아니에요.';
    }
    if (raw.contains('weak password') ||
        (raw.contains('password') && raw.contains('short'))) {
      return '비밀번호가 너무 약해요. 더 강한 비밀번호를 사용해주세요.';
    }
    if (_isNetwork(raw)) {
      return '네트워크 연결을 확인해주세요.';
    }
    return '회원가입에 실패했어요. 잠시 후 다시 시도해주세요.';
  }

  /// 비밀번호 재설정 메일
  static String mapPasswordReset(Object error) {
    final raw = error.toString().toLowerCase();

    if (raw.contains('rate') || raw.contains('too many')) {
      return '시도가 너무 많아요. 1분 후 다시 시도해주세요.';
    }
    if (raw.contains('user not found') || raw.contains('not found')) {
      return '가입되지 않은 이메일이에요.';
    }
    if (_isNetwork(raw) || raw.contains('timeout')) {
      return '네트워크 연결을 확인해주세요.';
    }
    return '이메일 전송에 실패했어요. 잠시 후 다시 시도해주세요.';
  }

  /// 가족 초대 관련 에러
  static String mapFamilyInvite(Object error) {
    final raw = error.toString().toLowerCase();

    if (raw.contains('유효하지') || raw.contains('invalid invite')) {
      return '유효하지 않은 초대 코드예요.';
    }
    if (raw.contains('만료') || raw.contains('expired')) {
      return '만료된 초대 코드예요.';
    }
    if (raw.contains('이미 사용') || raw.contains('already used')) {
      return '이미 사용된 초대 코드예요.';
    }
    return map(error, fallback: '가족 기능에서 문제가 발생했어요.');
  }

  /// 미디어/사진 업로드 에러
  static String mapMedia(Object error) {
    final raw = error.toString().toLowerCase();

    if (raw.contains('storage') || raw.contains('bucket')) {
      return '사진 업로드에 실패했어요. 사진 없이 다시 시도해보세요.';
    }
    if (raw.contains('size') || raw.contains('large')) {
      return '파일이 너무 커요. 더 작은 파일을 선택해주세요.';
    }
    if (raw.contains('format') || raw.contains('type')) {
      return '지원하지 않는 파일 형식이에요.';
    }
    if (_isNetwork(raw)) {
      return '네트워크 연결을 확인해주세요.';
    }
    return '업로드에 실패했어요. 잠시 후 다시 시도해주세요.';
  }

  // ─── helpers ────────────────────────────────────────────

  static bool _isNetwork(String raw) =>
      raw.contains('socket') ||
      raw.contains('network') ||
      raw.contains('connection') ||
      raw.contains('host') ||
      raw.contains('unreachable');

  static bool _isPermission(String raw) =>
      raw.contains('row-level') ||
      raw.contains('rls') ||
      raw.contains('not authorized') ||
      raw.contains('permission denied');
}
