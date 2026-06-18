import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/growth_record.dart';
import '../../data/models/milestone_record.dart';
import '../../data/models/vaccination_record.dart';
import '../services/supabase_service.dart';

// ─── Growth Records ───────────────────────────────────

/// 특정 아이의 성장 기록 목록
final growthRecordsProvider = FutureProvider.autoDispose
    .family<List<GrowthRecord>, String>((ref, childId) async {
  final response = await SupabaseService.client
      .from('growth_records')
      .select()
      .eq('child_id', childId)
      .order('recorded_at', ascending: true);
  return (response as List).map((e) => GrowthRecord.fromJson(e)).toList();
});

// ─── Milestones ───────────────────────────────────────

/// 특정 아이의 발달 마일스톤 목록
final milestonesProvider = FutureProvider.autoDispose
    .family<List<MilestoneRecord>, String>((ref, childId) async {
  final response = await SupabaseService.client
      .from('milestone_records')
      .select()
      .eq('child_id', childId)
      .order('expected_month');
  return (response as List).map((e) => MilestoneRecord.fromJson(e)).toList();
});

// ─── Vaccinations ─────────────────────────────────────

/// 특정 아이의 예방접종 기록 목록
final vaccinationsProvider = FutureProvider.autoDispose
    .family<List<VaccinationRecord>, String>((ref, childId) async {
  final response = await SupabaseService.client
      .from('vaccination_records')
      .select()
      .eq('child_id', childId)
      .order('recommended_month');
  return (response as List).map((e) => VaccinationRecord.fromJson(e)).toList();
});
