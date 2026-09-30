import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/auth/auth_repository.dart';
import '../../features/auth/auth_screens.dart';
import '../../features/announcements/announcement_screens.dart';
import '../../features/assignments/assignment_screens.dart';
import '../../features/home/home_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/quizzes/quiz_screens.dart';
import '../../features/resources/resource_library_screen.dart';
import '../../features/resources/resource_viewer_screen.dart';
import '../../features/schedule/schedule_screen.dart';
import '../services/supabase_provider.dart';
import '../theme/app_tokens.dart';
import '../widgets/app_components.dart';

class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(SupabaseClient client) {
    subscription = client.auth.onAuthStateChange.listen(
      (_) => notifyListeners(),
    );
  }
  late final StreamSubscription<AuthState> subscription;
  @override
  void dispose() {
    subscription.cancel();
    super.dispose();
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final client = ref.watch(supabaseProvider);
  final refresh = _AuthRefresh(client);
  ref.onDispose(refresh.dispose);
  final router = GoRouter(
    initialLocation: '/home',
    refreshListenable: refresh,
    redirect: (context, state) async {
      final signedIn = client.auth.currentUser != null;
      final authPage =
          state.matchedLocation == '/sign-in' ||
          state.matchedLocation == '/forgot-password';
      if (!signedIn && !authPage) return '/sign-in';
      if (signedIn && authPage) return '/home';
      if (signedIn && state.matchedLocation.startsWith('/teacher')) {
        try {
          final profile = await ref.read(authRepositoryProvider).profile();
          if (profile.role == AppRole.student) return '/home';
        } catch (_) {
          return '/home';
        }
      }
      return null;
    },
    routes: [
      GoRoute(path: '/sign-in', builder: (_, _) => const SignInScreen()),
      GoRoute(
        path: '/forgot-password',
        builder: (_, _) => const ForgotPasswordScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => StudentShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/learn',
                builder: (_, _) => const ResourceLibraryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/schedule',
                builder: (_, _) => const ScheduleScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/quizzes',
                builder: (_, _) => const QuizListScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (_, _) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/learn/:id',
        builder: (_, state) =>
            ResourceViewerScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/quizzes/:id',
        builder: (_, state) => QuizIntroScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/quiz-attempts/:id',
        builder: (_, state) =>
            QuizAttemptScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/quiz-results/:id',
        builder: (_, state) =>
            QuizResultScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/quiz-history',
        builder: (_, _) => const QuizHistoryScreen(),
      ),
      GoRoute(
        path: '/announcements',
        builder: (_, _) => const AnnouncementListScreen(),
        routes: [
          GoRoute(
            path: ':id',
            builder: (_, state) =>
                AnnouncementDetailScreen(id: state.pathParameters['id']!),
          ),
        ],
      ),
      GoRoute(
        path: '/assignments',
        builder: (_, _) => const AssignmentListScreen(),
        routes: [
          GoRoute(
            path: ':id',
            builder: (_, state) =>
                AssignmentDetailScreen(id: state.pathParameters['id']!),
          ),
        ],
      ),
      GoRoute(
        path: '/notifications',
        builder: (_, _) => const _PendingPage(
          title: 'Notifications',
          message: 'Updates from your class will appear here.',
        ),
      ),
      GoRoute(
        path: '/teacher',
        builder: (_, _) => const _PendingPage(
          title: 'Teacher',
          message: 'Your teaching overview will appear here.',
        ),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

class StudentShell extends StatelessWidget {
  const StudentShell({super.key, required this.shell});
  final StatefulNavigationShell shell;
  static const labels = ['Home', 'Learn', 'Schedule', 'Quizzes', 'Profile'];
  static const icons = [
    Icons.house_outlined,
    Icons.menu_book_outlined,
    Icons.calendar_today_outlined,
    Icons.check_circle_outline,
    Icons.person_outline,
  ];
  static const activeIcons = [
    Icons.house_rounded,
    Icons.menu_book_rounded,
    Icons.calendar_today_rounded,
    Icons.check_circle_rounded,
    Icons.person_rounded,
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    body: shell,
    bottomNavigationBar: SafeArea(
      top: false,
      child: Container(
        color: context.palette.surface,
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
        child: Row(
          children: List.generate(labels.length, (index) {
            final selected = shell.currentIndex == index;
            return Expanded(
              child: Semantics(
                selected: selected,
                label: '${labels[index]} tab',
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => shell.goBranch(
                    index,
                    initialLocation: index == shell.currentIndex,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          selected ? activeIcons[index] : icons[index],
                          size: 24,
                          color: selected
                              ? context.palette.accent
                              : context.palette.secondary,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          labels[index],
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: selected
                                ? context.palette.accent
                                : context.palette.secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    ),
  );
}

class _PendingPage extends StatelessWidget {
  const _PendingPage({required this.title, required this.message});
  final String title;
  final String message;
  @override
  Widget build(BuildContext context) => AppPage(
    title: title,
    children: [EmptyState(title: 'Nothing here yet', message: message)],
  );
}
