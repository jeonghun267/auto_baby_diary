import 'package:flutter_dotenv/flutter_dotenv.dart';

/// 환경변수를 로드하여 제공하는 클래스
class Env {
  Env._();

  static String _require(String key) {
    final value = dotenv.env[key];
    if (value == null || value.isEmpty) {
      throw Exception('필수 환경변수 $key 가 설정되지 않았습니다. .env 파일을 확인해주세요.');
    }
    return value;
  }

  static String get supabaseUrl => _require('SUPABASE_URL');
  static String get supabaseAnonKey => _require('SUPABASE_ANON_KEY');
  static String get whisperApiKey => _require('WHISPER_API_KEY');
  static String get geminiApiKey => _require('GEMINI_API_KEY');
}
