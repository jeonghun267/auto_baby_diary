import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/constants/app_strings.dart';
import 'core/services/supabase_service.dart';
import 'core/theme/app_theme.dart';
import 'core/providers/theme_provider.dart';

// Screens
import 'presentation/splash/splash_screen.dart';
import 'presentation/auth/login_screen.dart';
import 'presentation/auth/signup_screen.dart';
import 'presentation/home/home_screen.dart';
import 'presentation/record/record_screen.dart';
import 'presentation/timeline/timeline_screen.dart';
import 'presentation/profile/profile_screen.dart';
import 'presentation/profile/add_child_screen.dart';
import 'presentation/profile/edit_child_screen.dart';
import 'presentation/diary/diary_detail_screen.dart';
import 'presentation/diary/diary_edit_screen.dart';
import 'presentation/common/bottom_nav_shell.dart';
import 'presentation/onboarding/onboarding_screen.dart';
import 'presentation/settings/settings_screen.dart';
import 'presentation/search/search_screen.dart';
import 'presentation/gallery/gallery_screen.dart';
import 'presentation/growth/growth_screen.dart';
import 'presentation/growth/add_growth_screen.dart';
import 'presentation/milestone/milestone_screen.dart';
import 'presentation/vaccination/vaccination_screen.dart';
import 'presentation/daily_records/daily_records_screen.dart';
import 'presentation/legal/privacy_policy_screen.dart';
import 'presentation/legal/terms_screen.dart';
import 'presentation/premium/premium_screen.dart';
import 'presentation/diary/celebration_screen.dart';
import 'presentation/record/quick_record_screen.dart';
import 'presentation/family/family_screen.dart';
import 'presentation/report/monthly_report_screen.dart';
import 'presentation/export/export_screen.dart';
import 'presentation/stats/stats_screen.dart';

// ─── Navigator Keys ────────────────────────────────────
final _rootNavigatorKey = GlobalKey<NavigatorState>();

// ─── Auth State Listenable ─────────────────────────────
class AuthStateNotifier extends ChangeNotifier {
  AuthStateNotifier() {
    _subscription = SupabaseService.auth.onAuthStateChange.listen((data) {
      notifyListeners();
    });
  }

  late final StreamSubscription<AuthState> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

// ─── Route Transitions ─────────────────────────────────
CustomTransitionPage<void> _fadeTransitionPage({
  required LocalKey key,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: key,
    child: child,
    transitionDuration: const Duration(milliseconds: 300),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(opacity: animation, child: child);
    },
  );
}

CustomTransitionPage<void> _slideTransitionPage({
  required LocalKey key,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: key,
    child: child,
    transitionDuration: const Duration(milliseconds: 300),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final tween = Tween(begin: const Offset(1.0, 0.0), end: Offset.zero)
          .chain(CurveTween(curve: Curves.easeInOut));
      return SlideTransition(position: animation.drive(tween), child: child);
    },
  );
}

// ─── Router Provider ───────────────────────────────────
final routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = AuthStateNotifier();
  ref.onDispose(() => authNotifier.dispose());

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    debugLogDiagnostics: false,
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final isLoggedIn = SupabaseService.auth.currentUser != null;
      final currentPath = state.matchedLocation;

      // 스플래시는 항상 허용
      if (currentPath == '/') return null;

      final isAuthRoute = currentPath == '/login' || currentPath == '/signup';
      final isOnboarding = currentPath == '/onboarding';

      // 온보딩은 항상 허용
      if (isOnboarding) return null;

      // 미인증 + 인증 페이지 아님 → 로그인으로
      if (!isLoggedIn && !isAuthRoute) return '/login';
      // 인증됨 + 인증 페이지 → 홈으로
      if (isLoggedIn && isAuthRoute) return '/home';

      // 인증됨 + add-child 페이지는 항상 허용
      if (isLoggedIn && currentPath == '/profile/add-child') return null;
      return null;
    },
    routes: [
      // ── 스플래시 ──
      GoRoute(
        path: '/',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => _fadeTransitionPage(
          key: state.pageKey,
          child: const SplashScreen(),
        ),
      ),

      // ── 온보딩 ──
      GoRoute(
        path: '/onboarding',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => _fadeTransitionPage(
          key: state.pageKey,
          child: const OnboardingScreen(),
        ),
      ),

      // ── 인증 라우트 (쉘 밖) ──
      GoRoute(
        path: '/login',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => _fadeTransitionPage(
          key: state.pageKey,
          child: const LoginScreen(),
        ),
      ),
      GoRoute(
        path: '/signup',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => _slideTransitionPage(
          key: state.pageKey,
          child: const SignupScreen(),
        ),
      ),

      // ── 메인 탭 쉘 라우트 (하단 네비게이션) ──
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return BottomNavShell(navigationShell: navigationShell);
        },
        branches: [
          // 탭 0: 홈
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                pageBuilder: (context, state) => _fadeTransitionPage(
                  key: state.pageKey,
                  child: const HomeScreen(),
                ),
              ),
            ],
          ),
          // 탭 1: 기록
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/record',
                pageBuilder: (context, state) => _fadeTransitionPage(
                  key: state.pageKey,
                  child: const RecordScreen(),
                ),
              ),
            ],
          ),
          // 탭 2: 타임라인
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/timeline',
                pageBuilder: (context, state) => _fadeTransitionPage(
                  key: state.pageKey,
                  child: const TimelineScreen(),
                ),
              ),
            ],
          ),
          // 탭 3: 프로필
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                pageBuilder: (context, state) => _fadeTransitionPage(
                  key: state.pageKey,
                  child: const ProfileScreen(),
                ),
                routes: [
                  GoRoute(
                    path: 'add-child',
                    parentNavigatorKey: _rootNavigatorKey,
                    pageBuilder: (context, state) => _slideTransitionPage(
                      key: state.pageKey,
                      child: const AddChildScreen(),
                    ),
                  ),
                  GoRoute(
                    path: 'edit-child/:id',
                    parentNavigatorKey: _rootNavigatorKey,
                    pageBuilder: (context, state) => _slideTransitionPage(
                      key: state.pageKey,
                      child: EditChildScreen(
                        childId: state.pathParameters['id']!,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),

      // ── 설정 ──
      GoRoute(
        path: '/settings',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => _slideTransitionPage(
          key: state.pageKey,
          child: const SettingsScreen(),
        ),
      ),

      // ── 이용약관 ──
      GoRoute(
        path: '/terms',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => _slideTransitionPage(
          key: state.pageKey,
          child: const TermsScreen(),
        ),
      ),

      // ── 개인정보 처리방침 ──
      GoRoute(
        path: '/privacy',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => _slideTransitionPage(
          key: state.pageKey,
          child: const PrivacyPolicyScreen(),
        ),
      ),

      // ── 검색 ──
      GoRoute(
        path: '/search',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => _slideTransitionPage(
          key: state.pageKey,
          child: const SearchScreen(),
        ),
      ),

      // ── 갤러리 ──
      GoRoute(
        path: '/gallery',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => _slideTransitionPage(
          key: state.pageKey,
          child: const GalleryScreen(),
        ),
      ),

      // ── 성장 기록 ──
      GoRoute(
        path: '/growth',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => _slideTransitionPage(
          key: state.pageKey,
          child: const GrowthScreen(),
        ),
        routes: [
          GoRoute(
            path: 'add',
            parentNavigatorKey: _rootNavigatorKey,
            pageBuilder: (context, state) => _slideTransitionPage(
              key: state.pageKey,
              child: const AddGrowthScreen(),
            ),
          ),
        ],
      ),

      // ── 마일스톤 ──
      GoRoute(
        path: '/milestones',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => _slideTransitionPage(
          key: state.pageKey,
          child: const MilestoneScreen(),
        ),
      ),

      // ── 예방접종 ──
      GoRoute(
        path: '/vaccination',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => _slideTransitionPage(
          key: state.pageKey,
          child: const VaccinationScreen(),
        ),
      ),

      // ── 일상 기록 ──
      GoRoute(
        path: '/daily-records',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => _slideTransitionPage(
          key: state.pageKey,
          child: const DailyRecordsScreen(),
        ),
      ),

      // ── 데이터 내보내기 ──
      GoRoute(
        path: '/export',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => _slideTransitionPage(
          key: state.pageKey,
          child: const ExportScreen(),
        ),
      ),

      // ── 통계 ──
      GoRoute(
        path: '/stats',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => _slideTransitionPage(
          key: state.pageKey,
          child: const StatsScreen(),
        ),
      ),

      // ── 프리미엄 ──
      GoRoute(
        path: '/premium',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => _slideTransitionPage(
          key: state.pageKey,
          child: const PremiumScreen(),
        ),
      ),

      // ── 퀵 레코드 ──
      GoRoute(
        path: '/quick-record',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => _fadeTransitionPage(
          key: state.pageKey,
          child: const QuickRecordScreen(),
        ),
      ),

      // ── 가족 관리 ──
      GoRoute(
        path: '/family',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => _slideTransitionPage(
          key: state.pageKey,
          child: const FamilyScreen(),
        ),
      ),

      // ── 월간 리포트 ──
      GoRoute(
        path: '/report',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => _slideTransitionPage(
          key: state.pageKey,
          child: const MonthlyReportScreen(),
        ),
      ),

      // ── 축하 화면 ──
      GoRoute(
        path: '/celebration',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          final extra = state.extra as Map<String, String>;
          return _slideTransitionPage(
            key: state.pageKey,
            child: CelebrationScreen(
              diaryId: extra['diaryId']!,
              diaryText: extra['diaryText']!,
              emotionSummary: extra['emotionSummary']!,
            ),
          );
        },
      ),

      // ── 전체 화면 라우트 (쉘 밖) ──
      GoRoute(
        path: '/diary/:id',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => _slideTransitionPage(
          key: state.pageKey,
          child: DiaryDetailScreen(
            diaryId: state.pathParameters['id']!,
          ),
        ),
        routes: [
          GoRoute(
            path: 'edit',
            parentNavigatorKey: _rootNavigatorKey,
            pageBuilder: (context, state) => _slideTransitionPage(
              key: state.pageKey,
              child: DiaryEditScreen(
                diaryId: state.pathParameters['id']!,
              ),
            ),
          ),
        ],
      ),
    ],
  );
});

// ─── App Widget ────────────────────────────────────────
class AutoBabyDiaryApp extends ConsumerWidget {
  const AutoBabyDiaryApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ref.watch(themeModeProvider),
      routerConfig: router,
    );
  }
}
