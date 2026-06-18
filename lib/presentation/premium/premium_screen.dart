import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

class PremiumScreen extends StatelessWidget {
  const PremiumScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('프리미엄 플랜'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          children: [
            // Header
            const Text(
              '나에게 맞는 플랜을\n선택하세요',
              style: AppTextStyles.h1,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '모든 플랜은 7일 무료 체험이 포함됩니다',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),

            // Free Plan
            _PlanCard(
              planName: '무료',
              price: '0',
              priceUnit: '원/월',
              color: AppColors.secondary,
              features: const [
                '월 10건 AI 일기',
                '기본 성장 기록',
                '1명 아이 등록',
              ],
              isCurrentPlan: true,
              onSubscribe: () => _showSchoolProjectSnackBar(context),
            ),
            const SizedBox(height: 16),

            // Premium Plan
            _PlanCard(
              planName: '프리미엄',
              price: '4,900',
              priceUnit: '원/월',
              color: AppColors.primary,
              features: const [
                '무제한 AI 일기',
                'AI 성장 리포트',
                '데이터 내보내기',
                '3명 아이 등록',
              ],
              isComingSoon: true,
              onSubscribe: () => _showSchoolProjectSnackBar(context),
            ),
            const SizedBox(height: 16),

            // Family Plan
            _PlanCard(
              planName: '패밀리',
              price: '7,900',
              priceUnit: '원/월',
              color: AppColors.emotionHappy,
              features: const [
                '프리미엄 전체 기능',
                '가족 공유 (최대 4명)',
                '5명 아이 등록',
              ],
              isComingSoon: true,
              onSubscribe: () => _showSchoolProjectSnackBar(context),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  static void _showSchoolProjectSnackBar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          '\u{1F393} 학교 프로젝트로 모든 기능이 무료입니다!',
          style: TextStyle(fontSize: 14),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

// ─── Plan Card Widget ─────────────────────────────────

class _PlanCard extends StatelessWidget {
  final String planName;
  final String price;
  final String priceUnit;
  final Color color;
  final List<String> features;
  final bool isCurrentPlan;
  final bool isComingSoon;
  final VoidCallback onSubscribe;

  const _PlanCard({
    required this.planName,
    required this.price,
    required this.priceUnit,
    required this.color,
    required this.features,
    this.isCurrentPlan = false,
    this.isComingSoon = false,
    required this.onSubscribe,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isCurrentPlan ? color : color.withValues(alpha: 0.3),
              width: isCurrentPlan ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.1),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Plan name
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      planName,
                      style: AppTextStyles.labelLarge.copyWith(color: color),
                    ),
                  ),
                  if (isCurrentPlan) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '현재 플랜',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.success,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),

              // Price
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    price,
                    style: AppTextStyles.h1.copyWith(
                      color: color,
                      fontSize: 32,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      priceUnit,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Features
              ...features.map(
                (feature) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        size: 18,
                        color: color,
                      ),
                      const SizedBox(width: 10),
                      Text(feature, style: AppTextStyles.bodyMedium),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Subscribe button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onSubscribe,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    isCurrentPlan ? '현재 사용 중' : '구독하기',
                    style: AppTextStyles.buttonText,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Coming Soon ribbon
        if (isComingSoon)
          Positioned(
            top: -4,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, color.withValues(alpha: 0.8)],
                ),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Text(
                'Coming Soon',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
