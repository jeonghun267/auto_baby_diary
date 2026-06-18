import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/env.dart';

/// Supabase 클라이언트 초기화 및 제공
class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      anonKey: Env.supabaseAnonKey,
    );
  }

  static GoTrueClient get auth => client.auth;
  static SupabaseStorageClient get storage => client.storage;

  /// Edge Function 호출
  static Future<Map<String, dynamic>> invokeFunction(
    String functionName, {
    Map<String, dynamic>? body,
  }) async {
    final response = await client.functions.invoke(
      functionName,
      body: body,
    );
    final data = response.data;
    if (data is Map<String, dynamic>) {
      return data;
    }
    throw Exception('Edge Function 응답 형식이 올바르지 않습니다.');
  }
}

final supabaseServiceProvider = Provider<SupabaseService>((ref) {
  return SupabaseService();
});

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return SupabaseService.client;
});
