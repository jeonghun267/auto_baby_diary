import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('개인정보 처리방침'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '개인정보 처리방침',
              style: AppTextStyles.h2,
            ),
            const SizedBox(height: 8),
            Text(
              '시행일: 2026년 4월 1일',
              style: AppTextStyles.bodySmall,
            ),
            const SizedBox(height: 24),
            _buildSection(
              '1. 수집하는 개인정보 항목',
              '자동 육아일기(이하 "서비스")는 서비스 제공을 위해 다음과 같은 개인정보를 수집합니다.\n\n'
                  '가. 회원가입 시\n'
                  '  - 이메일 주소, 비밀번호\n\n'
                  '나. 아이 프로필 등록 시\n'
                  '  - 아이의 이름, 생년월일, 성별, 프로필 사진\n\n'
                  '다. 서비스 이용 과정에서\n'
                  '  - 사진, 음성 녹음, 일기 내용\n'
                  '  - 성장 기록 (키, 몸무게, 머리둘레)\n'
                  '  - 예방접종 기록, 마일스톤 기록\n'
                  '  - 일상 기록 (수유, 수면, 기저귀 등)',
            ),
            _buildSection(
              '2. 개인정보의 수집 및 이용 목적',
              '수집된 개인정보는 다음의 목적을 위해 이용됩니다.\n\n'
                  '  - 회원 관리 및 본인 확인\n'
                  '  - AI 기반 육아일기 자동 생성\n'
                  '  - 아이의 성장 발달 분석 및 기록\n'
                  '  - 맞춤형 육아 정보 제공\n'
                  '  - 서비스 개선 및 통계 분석',
            ),
            _buildSection(
              '3. 개인정보의 보유 및 이용 기간',
              '이용자의 개인정보는 서비스 이용 기간 동안 보유하며, '
                  '회원 탈퇴 시 지체 없이 파기합니다.\n\n'
                  '다만, 관련 법령에 따라 보존이 필요한 경우 해당 기간 동안 보관합니다.\n'
                  '  - 계약 또는 청약철회 등에 관한 기록: 5년\n'
                  '  - 소비자의 불만 또는 분쟁처리에 관한 기록: 3년',
            ),
            _buildSection(
              '4. 개인정보의 제3자 제공',
              '서비스는 이용자의 개인정보를 원칙적으로 제3자에게 제공하지 않습니다. '
                  '다만, 서비스 운영을 위해 다음의 외부 서비스를 이용하며, '
                  '해당 서비스의 개인정보 처리방침이 적용됩니다.\n\n'
                  '가. Supabase (데이터베이스 및 인증)\n'
                  '  - 제공 항목: 이메일, 비밀번호(암호화), 사용자 데이터\n'
                  '  - 목적: 회원 인증 및 데이터 저장\n'
                  '  - 보유 기간: 회원 탈퇴 시까지\n\n'
                  '나. Google Gemini (AI 분석)\n'
                  '  - 제공 항목: 사진, 일기 텍스트\n'
                  '  - 목적: AI 기반 사진 분석 및 일기 생성\n'
                  '  - 보유 기간: 분석 완료 후 즉시 삭제\n\n'
                  '다. OpenAI Whisper (음성 인식)\n'
                  '  - 제공 항목: 음성 녹음 파일\n'
                  '  - 목적: 음성을 텍스트로 변환\n'
                  '  - 보유 기간: 변환 완료 후 즉시 삭제',
            ),
            _buildSection(
              '5. 이용자의 권리',
              '이용자는 다음과 같은 권리를 행사할 수 있습니다.\n\n'
                  '  - 개인정보 열람 요청\n'
                  '  - 개인정보 수정 요청\n'
                  '  - 개인정보 삭제 요청\n'
                  '  - 개인정보 처리 정지 요청\n'
                  '  - 회원 탈퇴 요청\n\n'
                  '위 권리는 앱 내 설정 메뉴를 통해 직접 행사하거나, '
                  '아래 연락처를 통해 요청하실 수 있습니다.',
            ),
            _buildSection(
              '6. 개인정보의 안전성 확보 조치',
              '서비스는 개인정보의 안전성 확보를 위해 다음과 같은 조치를 취하고 있습니다.\n\n'
                  '  - 비밀번호 암호화 저장\n'
                  '  - SSL/TLS를 통한 데이터 전송 암호화\n'
                  '  - 데이터베이스 접근 권한 관리\n'
                  '  - 정기적인 보안 점검',
            ),
            _buildSection(
              '7. 개인정보의 파기',
              '이용자가 회원 탈퇴를 요청하면 다음과 같이 개인정보를 파기합니다.\n\n'
                  '  - 전자적 파일: 복구할 수 없는 방법으로 영구 삭제\n'
                  '  - 아이 프로필, 일기, 사진 등 모든 데이터 삭제\n'
                  '  - 외부 저장소(Supabase Storage)의 미디어 파일 삭제',
            ),
            _buildSection(
              '8. 연락처',
              '개인정보 관련 문의사항이 있으시면 아래로 연락해주세요.\n\n'
                  '  - 이메일: support@autobabydiary.com\n'
                  '  - 개인정보 보호책임자: 운영팀',
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTextStyles.h3,
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: AppTextStyles.bodyMedium.copyWith(height: 1.8),
          ),
        ],
      ),
    );
  }
}
