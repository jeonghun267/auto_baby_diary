import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../constants/supabase_constants.dart';
import 'supabase_service.dart';

/// Supabase Storage 업로드/다운로드/삭제 서비스
class StorageService {
  final _uuid = const Uuid();

  /// 미디어 파일(사진/동영상) 업로드 후 public URL 반환
  Future<String> uploadMedia(String filePath, String userId) async {
    final file = File(filePath);
    final extension = filePath.split('.').last;
    final fileName = '$userId/${_uuid.v4()}.$extension';

    await SupabaseService.storage
        .from(SupabaseConstants.bucketMedia)
        .upload(fileName, file);

    final url = SupabaseService.storage
        .from(SupabaseConstants.bucketMedia)
        .getPublicUrl(fileName);

    return url;
  }

  /// 오디오 파일 업로드 후 public URL 반환
  Future<String> uploadAudio(String filePath, String userId) async {
    final file = File(filePath);
    final extension = filePath.split('.').last;
    final fileName = '$userId/${_uuid.v4()}.$extension';

    await SupabaseService.storage.from(SupabaseConstants.bucketAudio).upload(
          fileName,
          file,
          fileOptions: const FileOptions(contentType: 'audio/wav'),
        );

    final url = SupabaseService.storage
        .from(SupabaseConstants.bucketAudio)
        .getPublicUrl(fileName);

    return url;
  }

  /// 단일 파일 삭제 (bucket, path 직접 지정)
  Future<void> deleteFile(String bucket, String path) async {
    await SupabaseService.storage.from(bucket).remove([path]);
  }

  /// public URL 에서 bucket + path 추출
  /// 형식: https://{ref}.supabase.co/storage/v1/object/public/{bucket}/{path}
  /// 또는: https://{ref}.supabase.co/storage/v1/object/sign/{bucket}/{path}?token=...
  ({String bucket, String path})? _parseStorageUrl(String url) {
    try {
      final uri = Uri.parse(url);
      // segments: ['storage', 'v1', 'object', 'public', '{bucket}', ...path]
      final segs = uri.pathSegments;
      final objIndex = segs.indexOf('object');
      if (objIndex < 0 || objIndex + 2 >= segs.length) return null;
      // 'public' 또는 'sign' 다음이 bucket
      final bucket = segs[objIndex + 2];
      final pathParts = segs.sublist(objIndex + 3);
      if (pathParts.isEmpty) return null;
      final path = pathParts.join('/');
      return (bucket: bucket, path: path);
    } catch (e) {
      debugPrint('[Storage] URL 파싱 실패: $url ($e)');
      return null;
    }
  }

  /// public URL 목록을 받아서 bucket별로 묶어 한 번에 삭제
  /// 일부 실패해도 나머지는 계속 진행 (best-effort)
  Future<void> deleteByUrls(List<String> urls) async {
    if (urls.isEmpty) return;

    // bucket → [path...] 그룹핑
    final byBucket = <String, List<String>>{};
    for (final url in urls) {
      if (url.isEmpty) continue;
      final parsed = _parseStorageUrl(url);
      if (parsed == null) continue;
      byBucket.putIfAbsent(parsed.bucket, () => []).add(parsed.path);
    }

    // 각 bucket별 일괄 삭제
    for (final entry in byBucket.entries) {
      try {
        await SupabaseService.storage.from(entry.key).remove(entry.value);
        debugPrint(
            '[Storage] 삭제 완료: bucket=${entry.key}, count=${entry.value.length}');
      } catch (e) {
        // 삭제 실패해도 다른 bucket은 계속 진행
        debugPrint('[Storage] 삭제 실패: bucket=${entry.key}, error=$e');
      }
    }
  }
}

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});
