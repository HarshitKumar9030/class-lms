import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_components.dart';
import '../auth/auth_repository.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    return AppPage(
      title: 'Profile',
      children: [
        profile.when(
          loading: () => const LoadingRows(count: 1),
          error: (_, _) => ErrorState(
            message: 'Check your connection and try again.',
            onRetry: () => ref.invalidate(profileProvider),
          ),
          data: (value) => AppSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value.fullName.isEmpty ? 'Your account' : value.fullName,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  value.role.name.toUpperCase(),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
        const SectionHeader(title: 'Learning'),
        const AppRow(title: 'Bookmarks', icon: Icons.bookmark_outline),
        const AppRow(title: 'Downloads', icon: Icons.download_outlined),
        const AppRow(title: 'Quiz history', icon: Icons.history_rounded),
        const AppRow(title: 'Assignments', icon: Icons.task_alt_rounded),
        const SectionHeader(title: 'Preferences'),
        const AppRow(
          title: 'Notifications',
          icon: Icons.notifications_none_rounded,
        ),
        AppRow(
          title: 'Appearance',
          subtitle: 'Follows your device setting',
          icon: Icons.brightness_6_outlined,
        ),
        const SectionHeader(title: 'Account'),
        AppRow(
          title: 'Sign out',
          icon: Icons.logout_rounded,
          onTap: () async {
            await ref.read(authRepositoryProvider).signOut();
            ref.invalidate(profileProvider);
            if (context.mounted) context.go('/sign-in');
          },
        ),
        const SizedBox(height: AppSpacing.section),
      ],
    );
  }
}
