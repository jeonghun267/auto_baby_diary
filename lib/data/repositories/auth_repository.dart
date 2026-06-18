import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/services/supabase_service.dart';

/// 인증 관련 Repository
class AuthRepository {
  /// 이메일 + 비밀번호 회원가입
  Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) async {
    return await SupabaseService.auth.signUp(
      email: email,
      password: password,
    );
  }

  /// 이메일 + 비밀번호 로그인
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await SupabaseService.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  /// 로그아웃
  Future<void> signOut() async {
    await SupabaseService.auth.signOut();
  }

  /// 현재 사용자
  User? get currentUser => SupabaseService.auth.currentUser;

  /// 인증 상태 스트림
  Stream<AuthState> get authStateChanges =>
      SupabaseService.auth.onAuthStateChange;
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

// authStateProvider는 core/providers/app_providers.dart에 정의됨
