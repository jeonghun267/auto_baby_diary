import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('이용약관'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '서비스 이용약관',
              style: AppTextStyles.h2,
            ),
            const SizedBox(height: 8),
            Text(
              '시행일: 2026년 4월 1일',
              style: AppTextStyles.bodySmall,
            ),
            const SizedBox(height: 24),
            _buildSection(
              '제1조 (목적)',
              '본 약관은 자동 육아일기(이하 "서비스")가 제공하는 모든 서비스의 이용조건 및 절차, '
                  '이용자와 서비스 제공자 간의 권리, 의무 및 책임사항 등을 규정하는 것을 목적으로 합니다.',
            ),
            _buildSection(
              '제2조 (서비스의 내용)',
              '서비스는 다음과 같은 기능을 제공합니다.\n\n'
                  '  1. 아이의 사진을 AI로 분석하여 자동으로 육아일기를 생성하는 기능\n'
                  '  2. 음성 녹음을 텍스트로 변환하여 일기에 반영하는 기능\n'
                  '  3. 아이의 성장 기록 (키, 몸무게, 머리둘레) 관리\n'
                  '  4. 예방접종 일정 관리\n'
                  '  5. 발달 마일스톤 추적\n'
                  '  6. 일상 기록 (수유, 수면, 기저귀 등) 관리\n'
                  '  7. 타임라인 및 갤러리를 통한 추억 열람',
            ),
            _buildSection(
              '제3조 (이용자의 의무)',
              '이용자는 서비스 이용 시 다음 사항을 준수해야 합니다.\n\n'
                  '  1. 타인의 개인정보나 사진을 무단으로 수집, 이용하지 않을 것\n'
                  '  2. 서비스의 안정적 운영을 방해하는 행위를 하지 않을 것\n'
                  '  3. 서비스를 통해 얻은 정보를 서비스 제공자의 사전 동의 없이 상업적으로 이용하지 않을 것\n'
                  '  4. 관련 법령 및 본 약관을 위반하지 않을 것\n'
                  '  5. 아이의 사진 등 민감한 정보를 등록할 때 보호자로서의 권한이 있을 것',
            ),
            _buildSection(
              '제4조 (지적재산권)',
              '1. 서비스가 제공하는 모든 콘텐츠(디자인, 소프트웨어, AI 모델 등)에 대한 '
                  '지적재산권은 서비스 제공자에게 있습니다.\n\n'
                  '2. 이용자가 작성한 일기 내용 및 업로드한 사진에 대한 권리는 이용자에게 있습니다.\n\n'
                  '3. AI가 생성한 일기 텍스트에 대해서는 이용자가 자유롭게 사용, 수정, 삭제할 수 있습니다.',
            ),
            _buildSection(
              '제5조 (서비스의 변경 및 중단)',
              '1. 서비스 제공자는 운영상, 기술상의 필요에 따라 서비스의 내용을 변경할 수 있으며, '
                  '변경 시 사전에 공지합니다.\n\n'
                  '2. 다음의 경우 서비스의 전부 또는 일부를 일시적으로 중단할 수 있습니다.\n'
                  '  - 시스템 점검, 보수, 교체 등\n'
                  '  - 천재지변, 국가비상사태 등 불가항력적 사유\n'
                  '  - 기타 서비스 운영에 중대한 지장이 있는 경우',
            ),
            _buildSection(
              '제6조 (책임의 제한)',
              '1. 서비스 제공자는 천재지변 또는 이에 준하는 불가항력으로 인하여 서비스를 제공할 수 '
                  '없는 경우에는 책임이 면제됩니다.\n\n'
                  '2. AI가 생성한 일기 내용은 참고용이며, 서비스 제공자는 AI 생성 콘텐츠의 정확성을 '
                  '보장하지 않습니다.\n\n'
                  '3. 이용자의 귀책사유로 인한 서비스 이용 장애에 대해서는 책임을 지지 않습니다.\n\n'
                  '4. 서비스는 무료로 제공되며, 서비스 이용과 관련하여 이용자에게 발생한 손해에 대해 '
                  '서비스 제공자의 고의 또는 중과실이 없는 한 책임을 지지 않습니다.',
            ),
            _buildSection(
              '제7조 (분쟁 해결)',
              '1. 서비스 이용과 관련하여 분쟁이 발생한 경우, 서비스 제공자와 이용자 간 원만한 '
                  '합의를 통해 해결하도록 노력합니다.\n\n'
                  '2. 합의가 이루어지지 않을 경우, 관련 법령에 따른 관할 법원에 소를 제기할 수 있습니다.\n\n'
                  '3. 본 약관에 명시되지 않은 사항은 관련 법령 및 상관례에 따릅니다.',
            ),
            _buildSection(
              '제8조 (약관의 변경)',
              '1. 서비스 제공자는 필요한 경우 본 약관을 변경할 수 있으며, 변경된 약관은 '
                  '서비스 내 공지를 통해 효력이 발생합니다.\n\n'
                  '2. 이용자가 변경된 약관에 동의하지 않는 경우 서비스 이용을 중단하고 '
                  '회원 탈퇴를 할 수 있습니다.',
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
