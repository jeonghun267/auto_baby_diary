import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/supabase_constants.dart';
import '../../core/services/supabase_service.dart';
import '../models/daily_record.dart';

/// 일상 기록 CRUD Repository (수유/수면/기저귀/이유식)
class DailyRecordRepository {
  final _uuid = const Uuid();

  /// 특정 날짜의 일상 기록 조회
  Future<List<DailyRecord>> getDailyRecords(
    String childId,
    DateTime date,
  ) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final response = await SupabaseService.client
        .from(SupabaseConstants.tableDailyRecords)
        .select()
        .eq('child_id', childId)
        .gte('start_time', startOfDay.toIso8601String())
        .lt('start_time', endOfDay.toIso8601String())
        .order('start_time', ascending: false);

    return (response as List).map((e) => DailyRecord.fromJson(e)).toList();
  }

  /// 기간별 일상 기록 조회
  Future<List<DailyRecord>> getDailyRecordsByRange(
    String childId,
    DateTime start,
    DateTime end,
  ) async {
    final response = await SupabaseService.client
        .from(SupabaseConstants.tableDailyRecords)
        .select()
        .eq('child_id', childId)
        .gte('start_time', start.toIso8601String())
        .lt('start_time', end.toIso8601String())
        .order('start_time', ascending: false);

    return (response as List).map((e) => DailyRecord.fromJson(e)).toList();
  }

  /// 일상 기록 추가 (Map 형태로 자유롭게)
  Future<DailyRecord> addDailyRecord(Map<String, dynamic> data) async {
    final payload = {'id': _uuid.v4(), ...data};
    final response = await SupabaseService.client
        .from(SupabaseConstants.tableDailyRecords)
        .insert(payload)
        .select()
        .single();
    return DailyRecord.fromJson(response);
  }

  /// 일상 기록 수정
  Future<DailyRecord> updateDailyRecord(
    String id,
    Map<String, dynamic> data,
  ) async {
    final response = await SupabaseService.client
        .from(SupabaseConstants.tableDailyRecords)
        .update(data)
        .eq('id', id)
        .select()
        .single();

    return DailyRecord.fromJson(response);
  }

  /// 일상 기록 삭제
  Future<void> deleteDailyRecord(String id) async {
    await SupabaseService.client
        .from(SupabaseConstants.tableDailyRecords)
        .delete()
        .eq('id', id);
  }
}

final dailyRecordRepositoryProvider = Provider<DailyRecordRepository>((ref) {
  return DailyRecordRepository();
});
