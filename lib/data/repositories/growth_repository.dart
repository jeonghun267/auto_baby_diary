import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/supabase_constants.dart';
import '../../core/services/supabase_service.dart';
import '../models/growth_record.dart';

/// 성장 기록 CRUD Repository
class GrowthRepository {
  final _uuid = const Uuid();

  /// 성장 기록 목록 조회 (특정 아이)
  Future<List<GrowthRecord>> getGrowthRecords(String childId) async {
    final response = await SupabaseService.client
        .from(SupabaseConstants.tableGrowthRecords)
        .select()
        .eq('child_id', childId)
        .order('recorded_at', ascending: false);

    return (response as List).map((e) => GrowthRecord.fromJson(e)).toList();
  }

  /// 성장 기록 추가
  Future<GrowthRecord> addGrowthRecord({
    required String childId,
    required DateTime recordedAt,
    double? height,
    double? weight,
    double? headCircumference,
    String? note,
  }) async {
    final response = await SupabaseService.client
        .from(SupabaseConstants.tableGrowthRecords)
        .insert({
          'id': _uuid.v4(),
          'child_id': childId,
          'recorded_at': recordedAt.toIso8601String(),
          'height': height,
          'weight': weight,
          'head_circumference': headCircumference,
          'note': note,
        })
        .select()
        .single();

    return GrowthRecord.fromJson(response);
  }

  /// 성장 기록 삭제
  Future<void> deleteGrowthRecord(String id) async {
    await SupabaseService.client
        .from(SupabaseConstants.tableGrowthRecords)
        .delete()
        .eq('id', id);
  }
}

final growthRepositoryProvider = Provider<GrowthRepository>((ref) {
  return GrowthRepository();
});
