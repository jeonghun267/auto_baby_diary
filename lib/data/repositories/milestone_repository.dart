import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/supabase_constants.dart';
import '../../core/services/supabase_service.dart';
import '../models/milestone_record.dart';

/// 발달 마일스톤 CRUD Repository
class MilestoneRepository {
  final _uuid = const Uuid();

  /// 마일스톤 목록 조회 (특정 아이)
  Future<List<MilestoneRecord>> getMilestones(String childId) async {
    final response = await SupabaseService.client
        .from(SupabaseConstants.tableMilestoneRecords)
        .select()
        .eq('child_id', childId)
        .order('expected_month', ascending: true);

    return (response as List).map((e) => MilestoneRecord.fromJson(e)).toList();
  }

  /// 기본 마일스톤 일괄 등록 (앱에서 정의한 default 리스트로 호출)
  Future<void> initializeMilestones(
    String childId,
    List<Map<String, dynamic>> defaults,
  ) async {
    final rows = defaults.map((d) {
      return {
        'id': _uuid.v4(),
        'child_id': childId,
        'title': d['title'],
        'category': d['category'],
        'expected_month': d['expected_month'],
        'achieved_at': null,
      };
    }).toList();

    await SupabaseService.client
        .from(SupabaseConstants.tableMilestoneRecords)
        .insert(rows);
  }

  /// 마일스톤 달성 토글
  Future<MilestoneRecord> toggleMilestone(
    String id,
    bool achieved,
  ) async {
    final response = await SupabaseService.client
        .from(SupabaseConstants.tableMilestoneRecords)
        .update({
          'achieved_at': achieved ? DateTime.now().toIso8601String() : null,
        })
        .eq('id', id)
        .select()
        .single();

    return MilestoneRecord.fromJson(response);
  }
}

final milestoneRepositoryProvider = Provider<MilestoneRepository>((ref) {
  return MilestoneRepository();
});
