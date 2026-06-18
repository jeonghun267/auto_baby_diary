import 'package:intl/intl.dart';

/// 날짜 포맷 유틸리티
class DateFormatter {
  DateFormatter._();

  static final _dateFormat = DateFormat('yyyy년 M월 d일');
  static final _dateTimeFormat = DateFormat('yyyy년 M월 d일 HH:mm');
  static final _timeFormat = DateFormat('HH:mm');
  static final _monthFormat = DateFormat('yyyy년 M월');

  static String formatDate(DateTime date) => _dateFormat.format(date);
  static String formatDateTime(DateTime date) => _dateTimeFormat.format(date);
  static String formatTime(DateTime date) => _timeFormat.format(date);
  static String formatMonth(DateTime date) => _monthFormat.format(date);

  /// 개월 수 계산
  static int calculateAgeInMonths(DateTime birthDate) {
    final now = DateTime.now();
    return (now.year - birthDate.year) * 12 + now.month - birthDate.month;
  }

  /// 상대적 시간 표시 (예: "3시간 전")
  static String relativeTime(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return formatDate(date);
  }
}
