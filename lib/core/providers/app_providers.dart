import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models/child_profile.dart';
import '../../data/models/diary_entry.dart';
import '../../data/repositories/diary_repository.dart';
import '../services/supabase_service.dart';

/// 선택된 아이 ID를 저장하는 SharedPreferences 키
const _kSelectedChildIdKey = 'selected_child_id';

// ─── Auth ──────────────────────────────────────────────

/// 인증 상태 스트림 (enhanced - 초기 세션 포함)
final authStateProvider = StreamProvider<AuthState>((ref) {
  return SupabaseService.auth.onAuthStateChange;
});

/// 현재 로그인된 사용자
final currentUserProvider = Provider<User?>((ref) {
  return SupabaseService.auth.currentUser;
});

/// 로그인 여부
final isLoggedInProvider = Provider<bool>((ref) {
  return ref.watch(currentUserProvider) != null;
});

// ─── User Profile ──────────────────────────────────────

/// 사용자 프로필 (Supabase profiles 테이블에서 가져옴)
final userProfileProvider =
    FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;

  final response = await SupabaseService.client
      .from('profiles')
      .select()
      .eq('id', user.id)
      .maybeSingle();

  return response;
});

// ─── Child Profiles ────────────────────────────────────

/// 현재 사용자의 아이 프로필 목록
final childProfilesProvider =
    FutureProvider.autoDispose<List<ChildProfile>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];

  final response = await SupabaseService.client
      .from('child_profiles')
      .select()
      .eq('user_id', user.id)
      .order('created_at', ascending: true);

  return (response as List).map((e) => ChildProfile.fromJson(e)).toList();
});

/// 현재 선택된 아이 프로필 ID (StateProvider로 사용자가 전환 가능)
/// 앱 시작 시 main.dart 에서 SharedPreferences 값으로 override 됨
final selectedChildIdProvider = StateProvider<String?>((ref) => null);

/// 아이를 전환하면서 SharedPreferences 에도 영속화
/// 사용처: 홈 AppBar 탭, 프로필 카드 탭, 가족 참여 후
Future<void> selectChild(WidgetRef ref, String childId) async {
  ref.read(selectedChildIdProvider.notifier).state = childId;
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSelectedChildIdKey, childId);
  } catch (_) {
    // 저장 실패해도 메모리 상의 선택은 유지
  }
}

/// 앱 시작 시 마지막으로 선택했던 아이 ID 로드
Future<String?> loadLastSelectedChildId() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kSelectedChildIdKey);
  } catch (_) {
    return null;
  }
}

/// 현재 선택된 아이 프로필 객체
final currentChildProvider = Provider.autoDispose<ChildProfile?>((ref) {
  final selectedId = ref.watch(selectedChildIdProvider);
  final profilesAsync = ref.watch(childProfilesProvider);

  return profilesAsync.whenOrNull(
    data: (profiles) {
      if (profiles.isEmpty) return null;
      if (selectedId != null) {
        return profiles.firstWhere(
          (p) => p.id == selectedId,
          orElse: () => profiles.first,
        );
      }
      return profiles.first;
    },
  );
});

// ─── Diary ─────────────────────────────────────────────

/// 특정 아이의 일기 목록 (family provider)
final diaryListProvider = FutureProvider.autoDispose
    .family<List<DiaryEntry>, String>((ref, childId) async {
  final diaryRepo = ref.read(diaryRepositoryProvider);
  return diaryRepo.getDiaryEntries(childId);
});

/// 현재 선택된 아이의 일기 목록 (편의 provider)
final currentChildDiaryListProvider =
    FutureProvider.autoDispose<List<DiaryEntry>>((ref) async {
  final child = ref.watch(currentChildProvider);
  if (child == null) return [];
  return ref.watch(diaryListProvider(child.id).future);
});

/// 단일 일기 조회
final diaryEntryProvider = FutureProvider.autoDispose
    .family<DiaryEntry?, String>((ref, diaryId) async {
  final diaryRepo = ref.read(diaryRepositoryProvider);
  return diaryRepo.getDiaryEntry(diaryId);
});

/// 특정 날짜의 일기 목록 (family provider)
final diaryByDateProvider = FutureProvider.autoDispose
    .family<List<DiaryEntry>, ({String childId, DateTime date})>(
        (ref, params) async {
  final diaryRepo = ref.read(diaryRepositoryProvider);
  return diaryRepo.getDiaryEntriesByDate(params.childId, params.date);
});
