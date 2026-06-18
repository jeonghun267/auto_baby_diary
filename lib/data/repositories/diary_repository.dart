import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/supabase_constants.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/supabase_service.dart';
import '../models/diary_entry.dart';

/// 일기 CRUD Repository
class DiaryRepository {
  final StorageService _storage;

  DiaryRepository(this._storage);

  /// 일기 목록 조회 (특정 아이) — 전체
  /// ⚠️ 일기가 많으면 비용↑. 가능하면 [getDiaryEntriesPaged]를 사용하세요.
  Future<List<DiaryEntry>> getDiaryEntries(String childId) async {
    final response = await SupabaseService.client
        .from(SupabaseConstants.tableDiaryEntries)
        .select()
        .eq('child_id', childId)
        .order('recorded_at', ascending: false);

    return (response as List).map((e) => DiaryEntry.fromJson(e)).toList();
  }

  /// 일기 목록 페이지네이션 조회
  /// [offset]: 시작 인덱스 (0-based), [limit]: 가져올 개수
  Future<List<DiaryEntry>> getDiaryEntriesPaged(
    String childId, {
    required int offset,
    required int limit,
  }) async {
    final response = await SupabaseService.client
        .from(SupabaseConstants.tableDiaryEntries)
        .select()
        .eq('child_id', childId)
        .order('recorded_at', ascending: false)
        .range(offset, offset + limit - 1);

    return (response as List).map((e) => DiaryEntry.fromJson(e)).toList();
  }

  /// 특정 날짜의 일기 조회
  Future<List<DiaryEntry>> getDiaryEntriesByDate(
    String childId,
    DateTime date,
  ) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final response = await SupabaseService.client
        .from(SupabaseConstants.tableDiaryEntries)
        .select()
        .eq('child_id', childId)
        .gte('recorded_at', startOfDay.toIso8601String())
        .lt('recorded_at', endOfDay.toIso8601String())
        .order('recorded_at', ascending: false);

    return (response as List).map((e) => DiaryEntry.fromJson(e)).toList();
  }

  /// 일기가 있는 날짜 목록 조회 (달력 표시용)
  Future<List<DateTime>> getDatesWithEntries(
    String childId,
    int year,
    int month,
  ) async {
    final startOfMonth = DateTime(year, month, 1);
    final endOfMonth = DateTime(year, month + 1, 1);

    final response = await SupabaseService.client
        .from(SupabaseConstants.tableDiaryEntries)
        .select('recorded_at')
        .eq('child_id', childId)
        .gte('recorded_at', startOfMonth.toIso8601String())
        .lt('recorded_at', endOfMonth.toIso8601String());

    return (response as List)
        .map((e) => DateTime.parse(e['recorded_at'] as String))
        .map((d) => DateTime(d.year, d.month, d.day))
        .toSet()
        .toList();
  }

  /// 일기 단건 조회
  Future<DiaryEntry?> getDiaryEntry(String id) async {
    final response = await SupabaseService.client
        .from(SupabaseConstants.tableDiaryEntries)
        .select()
        .eq('id', id)
        .maybeSingle();

    if (response == null) return null;
    return DiaryEntry.fromJson(response);
  }

  /// 일기 생성
  Future<DiaryEntry> createDiaryEntry(Map<String, dynamic> data) async {
    final response = await SupabaseService.client
        .from(SupabaseConstants.tableDiaryEntries)
        .insert(data)
        .select()
        .single();

    return DiaryEntry.fromJson(response);
  }

  /// 일기 수정 (final_text 업데이트 등)
  Future<DiaryEntry> updateDiaryEntry(
    String id,
    Map<String, dynamic> data,
  ) async {
    final response = await SupabaseService.client
        .from(SupabaseConstants.tableDiaryEntries)
        .update(data)
        .eq('id', id)
        .select()
        .single();

    return DiaryEntry.fromJson(response);
  }

  /// 일기 삭제 (관련 미디어 파일도 Storage에서 함께 삭제)
  /// Storage 삭제 실패는 무시(로그만) — DB row는 반드시 지움
  Future<void> deleteDiaryEntry(String id) async {
    // 1) 먼저 해당 일기 조회해서 media_urls 확보
    List<String> mediaUrls = const [];
    try {
      final entry = await getDiaryEntry(id);
      if (entry != null) {
        mediaUrls = entry.mediaUrls;
      }
    } catch (e) {
      debugPrint('[Diary] 삭제 전 조회 실패 (계속 진행): $e');
    }

    // 2) DB row 삭제
    await SupabaseService.client
        .from(SupabaseConstants.tableDiaryEntries)
        .delete()
        .eq('id', id);

    // 3) Storage 미디어 삭제 (best-effort, 실패해도 무시)
    if (mediaUrls.isNotEmpty) {
      try {
        await _storage.deleteByUrls(mediaUrls);
      } catch (e) {
        debugPrint('[Diary] Storage 정리 실패 (DB는 이미 삭제됨): $e');
      }
    }
  }
}

final diaryRepositoryProvider = Provider<DiaryRepository>((ref) {
  return DiaryRepository(ref.watch(storageServiceProvider));
});
