import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/supabase_constants.dart';
import '../../core/services/supabase_service.dart';
import '../models/vaccination_record.dart';

/// 예방접종 기록 CRUD Repository
class VaccinationRepository {
  final _uuid = const Uuid();

  /// 예방접종 목록 조회 (특정 아이)
  Future<List<VaccinationRecord>> getVaccinations(String childId) async {
    final response = await SupabaseService.client
        .from(SupabaseConstants.tableVaccinationRecords)
        .select()
        .eq('child_id', childId)
        .order('recommended_month', ascending: true)
        .order('dose_number', ascending: true);

    return (response as List)
        .map((e) => VaccinationRecord.fromJson(e))
        .toList();
  }

  /// 기본 예방접종 일괄 등록 (앱에서 정의한 default 리스트로 호출)
  Future<void> initializeVaccinations(
    String childId,
    List<Map<String, dynamic>> defaults,
  ) async {
    final rows = defaults.map((v) {
      return {
        'id': _uuid.v4(),
        'child_id': childId,
        'name': v['name'],
        'description': v['description'],
        'recommended_month': v['recommended_month'],
        'dose_number': v['dose'] ?? v['dose_number'],
        'completed_at': null,
        'hospital': null,
      };
    }).toList();

    await SupabaseService.client
        .from(SupabaseConstants.tableVaccinationRecords)
        .insert(rows);
  }

  /// 개별 예방접종 추가 (사용자 직접 추가)
  Future<VaccinationRecord> addVaccination({
    required String childId,
    required String name,
    String? description,
    required int recommendedMonth,
    required int doseNumber,
  }) async {
    final response = await SupabaseService.client
        .from(SupabaseConstants.tableVaccinationRecords)
        .insert({
          'id': _uuid.v4(),
          'child_id': childId,
          'name': name,
          'description': description,
          'recommended_month': recommendedMonth,
          'dose_number': doseNumber,
          'completed_at': null,
          'hospital': null,
        })
        .select()
        .single();
    return VaccinationRecord.fromJson(response);
  }

  /// 접종 완료 처리
  Future<VaccinationRecord> markCompleted({
    required String id,
    required DateTime completedAt,
    String? hospital,
  }) async {
    final response = await SupabaseService.client
        .from(SupabaseConstants.tableVaccinationRecords)
        .update({
          'completed_at': completedAt.toIso8601String(),
          'hospital': hospital,
        })
        .eq('id', id)
        .select()
        .single();

    return VaccinationRecord.fromJson(response);
  }

  /// 접종 완료 취소
  Future<VaccinationRecord> unmarkCompleted(String id) async {
    final response = await SupabaseService.client
        .from(SupabaseConstants.tableVaccinationRecords)
        .update({
          'completed_at': null,
          'hospital': null,
        })
        .eq('id', id)
        .select()
        .single();

    return VaccinationRecord.fromJson(response);
  }
}

final vaccinationRepositoryProvider = Provider<VaccinationRepository>((ref) {
  return VaccinationRepository();
});
