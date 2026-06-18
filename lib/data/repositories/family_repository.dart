import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/supabase_service.dart';
import '../models/family_member.dart';

/// 가족 멤버 / 초대 관리 Repository
class FamilyRepository {
  /// 특정 아이의 가족 멤버 목록 조회
  Future<List<FamilyMember>> getMembers(String childId) async {
    final response = await SupabaseService.client
        .from('family_members')
        .select()
        .eq('child_id', childId)
        .order('created_at', ascending: true);

    return (response as List).map((e) => FamilyMember.fromJson(e)).toList();
  }

  /// 6자리 초대 코드 생성 (충돌 방지를 위해 랜덤 숫자)
  String _generateCode() {
    final random = Random.secure();
    return List.generate(6, (_) => random.nextInt(10)).join();
  }

  /// 초대 코드 생성 (24시간 유효)
  Future<String> createInvite({
    required String childId,
    required String inviterId,
    String role = 'family',
  }) async {
    final code = _generateCode();
    final now = DateTime.now();
    final expiresAt = now.add(const Duration(hours: 24));

    await SupabaseService.client.from('family_invites').insert({
      'code': code,
      'child_id': childId,
      'inviter_id': inviterId,
      'role': role,
      'expires_at': expiresAt.toIso8601String(),
    });

    return code;
  }

  /// 초대 코드로 가입
  /// 반환: 성공 시 추가된 가족 멤버, 실패 시 에러 throw
  Future<FamilyMember> joinByCode({
    required String code,
    required String userId,
    String? nickname,
  }) async {
    // 1) 초대 조회 (만료 / 사용 여부 확인)
    final invite = await SupabaseService.client
        .from('family_invites')
        .select()
        .eq('code', code)
        .maybeSingle();

    if (invite == null) {
      throw Exception('유효하지 않은 초대 코드입니다');
    }

    final expiresAt = DateTime.parse(invite['expires_at'] as String);
    if (expiresAt.isBefore(DateTime.now())) {
      throw Exception('만료된 초대 코드입니다');
    }
    if (invite['used_by'] != null) {
      throw Exception('이미 사용된 초대 코드입니다');
    }

    final childId = invite['child_id'] as String;
    final role = invite['role'] as String;

    // 2) 본인이 이미 멤버인지 확인
    final existing = await SupabaseService.client
        .from('family_members')
        .select()
        .eq('child_id', childId)
        .eq('user_id', userId)
        .maybeSingle();

    if (existing != null) {
      // 이미 가입된 경우, 초대 코드만 used 처리
      await SupabaseService.client.from('family_invites').update({
        'used_by': userId,
        'used_at': DateTime.now().toIso8601String(),
      }).eq('code', code);
      return FamilyMember.fromJson(existing);
    }

    // 3) 가족 멤버로 추가
    final inserted = await SupabaseService.client
        .from('family_members')
        .insert({
          'child_id': childId,
          'user_id': userId,
          'role': role,
          'nickname': nickname,
        })
        .select()
        .single();

    // 4) 초대 코드 사용 처리
    await SupabaseService.client.from('family_invites').update({
      'used_by': userId,
      'used_at': DateTime.now().toIso8601String(),
    }).eq('code', code);

    return FamilyMember.fromJson(inserted);
  }

  /// 멤버 제거 (소유자만 가능)
  Future<void> removeMember(String memberId) async {
    await SupabaseService.client
        .from('family_members')
        .delete()
        .eq('id', memberId);
  }

  /// 멤버 닉네임 수정
  Future<FamilyMember> updateNickname(String memberId, String nickname) async {
    final response = await SupabaseService.client
        .from('family_members')
        .update({'nickname': nickname})
        .eq('id', memberId)
        .select()
        .single();
    return FamilyMember.fromJson(response);
  }
}

final familyRepositoryProvider = Provider<FamilyRepository>((ref) {
  return FamilyRepository();
});

/// 특정 아이의 가족 멤버 목록 (family provider)
final familyMembersProvider = FutureProvider.autoDispose
    .family<List<FamilyMember>, String>((ref, childId) async {
  final repo = ref.read(familyRepositoryProvider);
  return repo.getMembers(childId);
});
