import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/services/app_lock_service.dart';
import '../../core/services/supabase_service.dart';
import '../onboarding/onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _iconController;
  late final AnimationController _fadeController;
  late final AnimationController _slideController;

  late final Animation<double> _iconScale;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    // Icon scale-in + bounce animation
    _iconController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _iconScale = CurvedAnimation(
      parent: _iconController,
      curve: Curves.elasticOut,
    );

    // App name fade-in animation
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );

    // Tagline slide-up animation
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOut,
    ));

    _startAnimations();
  }

  Future<void> _startAnimations() async {
    // Start icon bounce
    await Future.delayed(const Duration(milliseconds: 200));
    _iconController.forward();

    // Start app name fade-in
    await Future.delayed(const Duration(milliseconds: 500));
    _fadeController.forward();

    // Start tagline slide-up
    await Future.delayed(const Duration(milliseconds: 300));
    _slideController.forward();

    // Wait and then navigate
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    _navigate();
  }

  Future<void> _navigate() async {
    final seen = await hasSeenOnboarding();
    if (!mounted) return;

    if (!seen) {
      context.go('/onboarding');
      return;
    }

    final currentUser = SupabaseService.auth.currentUser;
    if (currentUser == null) {
      context.go('/login');
      return;
    }

    // 앱 잠금이 켜져 있으면 인증 통과해야 진입
    final lockEnabled = await AppLockService.isEnabled();
    if (lockEnabled) {
      final ok = await AppLockService.authenticate(
        reason: '앱을 잠금 해제해주세요',
      );
      if (!mounted) return;
      if (!ok) {
        // 인증 실패 — 다시 시도하도록 splash 유지
        // 사용자가 앱을 다시 켜면 또 시도
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) _navigate();
        return;
      }
    }

    context.go('/home');
  }

  @override
  void dispose() {
    _iconController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.primary, // pink
              AppColors.primaryLight, // lighter pink
              AppColors.background, // cream
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Baby icon with scale-in + bounce
              ScaleTransition(
                scale: _iconScale,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryDark.withValues(alpha: 0.2),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.child_care_rounded,
                    size: 64,
                    color: AppColors.primary,
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // App name fade-in
              FadeTransition(
                opacity: _fadeAnimation,
                child: const Text(
                  AppStrings.appName,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 2.0,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Tagline slide-up
              SlideTransition(
                position: _slideAnimation,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Text(
                    AppStrings.appTagline,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: Colors.white.withValues(alpha: 0.85),
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
