import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/supabase_constants.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/supabase_service.dart';
import '../models/child_profile.dart';

/// 아이 프로필 CRUD Repository
class ChildProfileRepository {
  final StorageService _storage;
  final _uuid = const Uuid();

  ChildProfileRepository(this._storage);

  /// 사용자의 모든 아이 프로필 조회
  Future<List<ChildProfile>> getMyChildren(String userId) async {
    final response = await SupabaseService.client
        .from(SupabaseConstants.tableChildProfiles)
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: true);
    return (response as List).map((e) => ChildProfile.fromJson(e)).toList();
  }

  /// 단건 조회
  Future<ChildProfile?> getChild(String id) async {
    final response = await SupabaseService.client
        .from(SupabaseConstants.tableChildProfiles)
        .select()
        .eq('id', id)
        .maybeSingle();
    if (response == null) return null;
    return ChildProfile.fromJson(response);
  }

  /// 아이 등록
  /// [profileImage]: 선택. 있으면 Storage에 업로드 후 photo_url 저장
  Future<ChildProfile> createChild({
    required String userId,
    required String name,
    required DateTime birthDate,
    String gender = '남아',
    File? profileImage,
  }) async {
    String? photoUrl;
    if (profileImage != null) {
      try {
        photoUrl = await _storage.uploadMedia(profileImage.path, userId);
      } catch (e) {
        // 사진 업로드 실패는 별도로 throw — 호출 측에서 분기 처리
        rethrow;
      }
    }

    final id = _uuid.v4();
    final data = <String, dynamic>{
      'id': id,
      'user_id': userId,
      'name': name,
      'birth_date': birthDate.toIso8601String().split('T')[0],
      'gender': gender,
    };
    if (photoUrl != null) data['photo_url'] = photoUrl;

    final response = await SupabaseService.client
        .from(SupabaseConstants.tableChildProfiles)
        .insert(data)
        .select()
        .single();
    return ChildProfile.fromJson(response);
  }

  /// 아이 정보 수정
  Future<ChildProfile> updateChild(
    String id,
    Map<String, dynamic> data,
  ) async {
    final response = await SupabaseService.client
        .from(SupabaseConstants.tableChildProfiles)
        .update(data)
        .eq('id', id)
        .select()
        .single();
    return ChildProfile.fromJson(response);
  }

  /// 아이 삭제 (관련 미디어도 함께 정리)
  /// CASCADE로 diary/growth/milestone/vaccination/daily_records 도 자동 삭제됨
  /// 단, Storage 미디어는 직접 정리해야 함
  Future<void> deleteChild(String id) async {
    // 1) 일기들의 media_urls 수집 (cascade 전에)
    final urlsToDelete = <String>[];
    try {
      final entries = await SupabaseService.client
          .from(SupabaseConstants.tableDiaryEntries)
          .select('media_urls, child_id')
          .eq('child_id', id);
      for (final row in entries as List) {
        final urls =
            (row['media_urls'] as List?)?.map((e) => e.toString()).toList() ??
                [];
        urlsToDelete.addAll(urls);
      }

      // 아이 프로필 사진도
      final child = await getChild(id);
      if (child?.photoUrl != null && child!.photoUrl!.isNotEmpty) {
        urlsToDelete.add(child.photoUrl!);
      }
    } catch (e) {
      debugPrint('[ChildProfile] 미디어 URL 수집 실패: $e');
    }

    // 2) DB 삭제 (cascade로 일기/성장/마일스톤/일상/접종 자동 삭제)
    await SupabaseService.client
        .from(SupabaseConstants.tableChildProfiles)
        .delete()
        .eq('id', id);

    // 3) Storage 정리 (best-effort)
    if (urlsToDelete.isNotEmpty) {
      try {
        await _storage.deleteByUrls(urlsToDelete);
      } catch (e) {
        debugPrint('[ChildProfile] Storage 정리 실패: $e');
      }
    }
  }
}

final childProfileRepositoryProvider = Provider<ChildProfileRepository>((ref) {
  return ChildProfileRepository(ref.watch(storageServiceProvider));
});
