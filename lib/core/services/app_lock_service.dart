import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 앱 잠금 (생체 인증 / 디바이스 인증) 서비스
///
/// 흐름:
/// 1) 설정에서 "앱 잠금" 토글 ON → enable() 호출 → 1회 인증 후 활성화
/// 2) 앱 시작 시 [isEnabled] 체크 → true면 [authenticate] 강제
/// 3) 인증 실패 시 앱 진입 차단
class AppLockService {
  static const _kEnabledKey = 'app_lock_enabled';
  static final _auth = LocalAuthentication();

  /// 앱 잠금이 켜져 있는지
  static Future<bool> isEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_kEnabledKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// 디바이스가 생체/PIN 인증을 지원하는지
  static Future<bool> isAvailable() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final supported = await _auth.isDeviceSupported();
      return canCheck || supported;
    } catch (e) {
      debugPrint('[AppLock] 가용성 체크 실패: $e');
      return false;
    }
  }

  /// 인증 시도 — 성공 시 true
  static Future<bool> authenticate({
    String reason = '앱을 잠금 해제해주세요',
  }) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false, // PIN/패턴도 허용
        ),
      );
    } catch (e) {
      debugPrint('[AppLock] 인증 실패: $e');
      return false;
    }
  }

  /// 앱 잠금 활성화 — 활성화 전 1회 인증
  /// 반환: true 성공
  static Future<bool> enable() async {
    final ok = await authenticate(reason: '앱 잠금을 켜기 위해 인증해주세요');
    if (!ok) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kEnabledKey, true);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 앱 잠금 비활성화 — 비활성화 전 1회 인증
  /// 반환: true 성공
  static Future<bool> disable() async {
    final ok = await authenticate(reason: '앱 잠금을 끄기 위해 인증해주세요');
    if (!ok) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kEnabledKey, false);
      return true;
    } catch (_) {
      return false;
    }
  }
}

final appLockServiceProvider = Provider<AppLockService>((ref) {
  return AppLockService();
});
