import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;

/// 디바이스 시간대 추정
/// DateTime.now().timeZoneName 은 'KST', 'JST' 같은 약자라
/// timezone 패키지가 인식 못 함. 그래서 offset 으로 매핑.
String _detectLocalTimezone() {
  final offset = DateTime.now().timeZoneOffset;
  final hours = offset.inHours;
  // 자주 쓰이는 timezone 매핑
  switch (hours) {
    case 9:
      return 'Asia/Seoul'; // KST/JST
    case 8:
      return 'Asia/Shanghai';
    case 0:
      return 'Europe/London';
    case -5:
      return 'America/New_York';
    case -8:
      return 'America/Los_Angeles';
    case 1:
      return 'Europe/Paris';
    case 2:
      return 'Europe/Berlin';
    default:
      // 매핑 없는 시간대는 Etc/GMT (offset 기반 fallback)
      // 주의: Etc/GMT는 부호가 반대 — Etc/GMT-9 가 UTC+9
      final etcOffset = -hours;
      return 'Etc/GMT${etcOffset >= 0 ? '+' : ''}$etcOffset';
  }
}

/// 로컬 알림 관리 서비스
/// - 일기 작성 리마인더 (매일 정해진 시간)
/// - 마일스톤 알림 (달성 시)
class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  /// 알림 ID
  static const int reminderId = 1001;
  static const int milestoneIdBase = 2000; // 마일스톤은 base + index

  /// 채널 ID/이름
  static const String _reminderChannelId = 'diary_reminder';
  static const String _reminderChannelName = '일기 리마인더';
  static const String _milestoneChannelId = 'milestone_alert';
  static const String _milestoneChannelName = '마일스톤 알림';

  /// 앱 시작 시 한 번만 호출 — 채널 생성, 시간대 초기화, 권한 요청
  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      // 시간대 초기화 (zonedSchedule 에 필요)
      tz_data.initializeTimeZones();
      // 디바이스 시간대 자동 감지 (실패 시 Asia/Seoul fallback)
      try {
        final tzName = _detectLocalTimezone();
        tz.setLocalLocation(tz.getLocation(tzName));
        debugPrint('[Notification] 시간대: $tzName');
      } catch (e) {
        debugPrint('[Notification] 시간대 감지 실패, Asia/Seoul 로 fallback: $e');
        tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
      }

      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: false, // 권한은 별도로 요청
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _plugin.initialize(initSettings);

      // Android 채널 등록
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            _reminderChannelId,
            _reminderChannelName,
            description: '오늘의 일기를 잊지 않도록 알려드려요',
            importance: Importance.defaultImportance,
          ),
        );
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            _milestoneChannelId,
            _milestoneChannelName,
            description: '아이의 발달 마일스톤 달성을 축하해요',
            importance: Importance.high,
          ),
        );
      }

      _initialized = true;
    } catch (e) {
      debugPrint('[Notification] 초기화 실패: $e');
    }
  }

  /// 알림 권한 요청 (Android 13+ / iOS)
  /// 반환: true = 허용, false = 거부 또는 미정
  static Future<bool> requestPermission() async {
    try {
      // iOS
      final iosPlugin = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (iosPlugin != null) {
        final granted = await iosPlugin.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        if (granted == true) return true;
      }

      // Android 13+
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        final granted = await androidPlugin.requestNotificationsPermission();
        return granted ?? false;
      }
      return true;
    } catch (e) {
      debugPrint('[Notification] 권한 요청 실패: $e');
      return false;
    }
  }

  /// 매일 정해진 시각에 일기 리마인더 스케줄
  /// [hour]: 0-23, [minute]: 0-59
  static Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
  }) async {
    try {
      // 기존 리마인더 취소 후 새로 등록
      await _plugin.cancel(reminderId);

      final now = tz.TZDateTime.now(tz.local);
      var scheduled = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );
      // 오늘 시각이 이미 지났으면 내일로
      if (scheduled.isBefore(now)) {
        scheduled = scheduled.add(const Duration(days: 1));
      }

      await _plugin.zonedSchedule(
        reminderId,
        '오늘 우리 아이는 어땠나요? 💝',
        '잠깐 여유를 내서 오늘의 순간을 기록해보세요',
        scheduled,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _reminderChannelId,
            _reminderChannelName,
            channelDescription: '오늘의 일기를 잊지 않도록 알려드려요',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time, // 매일 같은 시각 반복
      );
      debugPrint(
          '[Notification] 일기 리마인더 예약: 매일 ${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}');
    } catch (e) {
      debugPrint('[Notification] 리마인더 스케줄 실패: $e');
      rethrow;
    }
  }

  /// 일기 리마인더 취소
  static Future<void> cancelReminder() async {
    try {
      await _plugin.cancel(reminderId);
      debugPrint('[Notification] 일기 리마인더 취소');
    } catch (e) {
      debugPrint('[Notification] 리마인더 취소 실패: $e');
    }
  }

  /// 마일스톤 달성 즉시 알림
  static Future<void> showMilestoneAchieved({
    required String childName,
    required String milestoneTitle,
  }) async {
    try {
      final id = milestoneIdBase +
          DateTime.now().millisecondsSinceEpoch.remainder(1000);
      await _plugin.show(
        id,
        '🎉 $childName의 새로운 발자국!',
        '"$milestoneTitle" 마일스톤을 달성했어요',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _milestoneChannelId,
            _milestoneChannelName,
            channelDescription: '아이의 발달 마일스톤 달성을 축하해요',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
    } catch (e) {
      debugPrint('[Notification] 마일스톤 알림 실패: $e');
    }
  }

  /// 모든 알림 취소
  static Future<void> cancelAll() async {
    try {
      await _plugin.cancelAll();
    } catch (_) {}
  }

  /// 현재 예약된 알림 목록 (디버그용)
  static Future<List<PendingNotificationRequest>> getPending() async {
    try {
      return await _plugin.pendingNotificationRequests();
    } catch (_) {
      return [];
    }
  }
}

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});
