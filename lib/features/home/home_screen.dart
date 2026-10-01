import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_components.dart';
import '../announcements/announcement_repository.dart';
import '../announcements/announcement_screens.dart';
import '../auth/auth_repository.dart';
import 'home_repository.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final overview = ref.watch(homeOverviewProvider);
    final announcements = ref.watch(announcementsProvider);
    final firstName = profile.value?.fullName.trim().split(' ').first;
    return AppPage(
      title: 'Today',
      trailing: IconButton(
        tooltip: 'Notifications',
        onPressed: () => context.push('/notifications'),
        icon: const Icon(Icons.notifications_none_rounded),
      ),
      onRefresh: () async {
        ref.invalidate(homeOverviewProvider);
        ref.invalidate(announcementsProvider);
        ref.invalidate(profileProvider);
      },
      children: [
        Text(
          '${_greeting()}${firstName == null || firstName.isEmpty ? '' : ', $firstName'}',
          style: Theme.of(context).textTheme.displaySmall,
        ),
        const SizedBox(height: 8),
        Text(
          DateFormat('EEEE, d MMMM').format(DateTime.now()),
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: context.palette.secondary),
        ),
        if (profile.value?.role != null &&
            profile.value!.role != AppRole.student) ...[
          const SectionHeader(title: 'Teaching'),
          AppRow(
            title: 'Manage class content',
            subtitle: 'Courses, lessons, classes, quizzes and more',
            icon: Icons.school_outlined,
            onTap: () => context.push('/teacher'),
          ),
        ],
        overview.when(
          loading: () => const Padding(
            padding: EdgeInsets.only(top: 32),
            child: LoadingRows(count: 3),
          ),
          error: (_, _) => Padding(
            padding: const EdgeInsets.only(top: 32),
            child: ErrorState(
              message: 'Check your connection and try again.',
              onRetry: () => ref.invalidate(homeOverviewProvider),
            ),
          ),
          data: (data) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(title: 'Next class'),
              data.nextClass == null
                  ? const CompactEmptyState(
                      title: 'No class coming up',
                      message: 'Your next class will appear here.',
                      icon: Icons.calendar_today_outlined,
                    )
                  : _HeroItem(
                      item: data.nextClass!,
                      icon: Icons.calendar_today_outlined,
                      footnote: data.nextClass!.date == null
                          ? null
                          : DateFormat(
                              'EEE, h:mm a',
                            ).format(data.nextClass!.date!),
                      onTap: () => context.go('/schedule'),
                    ),
              const SectionHeader(title: 'Continue learning'),
              data.recentResource == null
                  ? const CompactEmptyState(
                      title: 'Ready when you are',
                      message: 'New study resources will appear here.',
                      icon: Icons.menu_book_outlined,
                    )
                  : _HeroItem(
                      item: data.recentResource!,
                      icon: Icons.menu_book_outlined,
                      onTap: () => context.go('/learn'),
                    ),
              const SectionHeader(title: 'Upcoming'),
              if (data.upcomingQuiz == null && data.dueAssignment == null)
                const CompactEmptyState(
                  title: 'All clear',
                  message: 'No quizzes or assignments are due soon.',
                  icon: Icons.check_circle_outline,
                ),
              if (data.upcomingQuiz != null)
                AppRow(
                  title: data.upcomingQuiz!.title,
                  subtitle: data.upcomingQuiz!.date == null
                      ? 'Quiz'
                      : 'Quiz · closes ${DateFormat.MMMd().format(data.upcomingQuiz!.date!)}',
                  icon: Icons.quiz_outlined,
                  onTap: () => context.go('/quizzes'),
                ),
              if (data.dueAssignment != null)
                AppRow(
                  title: data.dueAssignment!.title,
                  subtitle:
                      'Assignment · due ${DateFormat.MMMd().format(data.dueAssignment!.date!)}',
                  icon: Icons.assignment_outlined,
                  onTap: () => context.push('/assignments'),
                ),
            ],
          ),
        ),
        SectionHeader(
          title: 'Announcements',
          action: 'See all',
          onAction: () => context.push('/announcements'),
        ),
        announcements.when(
          loading: () => const LoadingRows(count: 1),
          error: (_, _) => ErrorState(
            message: 'Couldn’t load announcements.',
            onRetry: () => ref.invalidate(announcementsProvider),
          ),
          data: (items) => items.isEmpty
              ? const CompactEmptyState(
                  title: 'You’re all caught up',
                  message: 'Nothing new from your teacher.',
                  icon: Icons.campaign_outlined,
                )
              : AnnouncementTile(
                  announcement: items.first,
                  onTap: () => context.push('/announcements/${items.first.id}'),
                ),
        ),
      ],
    );
  }
}

class _HeroItem extends StatelessWidget {
  const _HeroItem({
    required this.item,
    required this.icon,
    this.footnote,
    this.onTap,
  });
  final HomeItem item;
  final IconData icon;
  final String? footnote;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => AppSurface(
    onTap: onTap,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 24, color: context.palette.accent),
        const SizedBox(height: 16),
        Text(item.title, style: Theme.of(context).textTheme.titleLarge),
        if (item.subtitle != null && item.subtitle!.isNotEmpty) ...[
          const SizedBox(height: 5),
          Text(
            item.subtitle!,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: context.palette.secondary),
          ),
        ],
        if (footnote != null) ...[
          const SizedBox(height: 12),
          Text(
            footnote!,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: context.palette.accent),
          ),
        ],
      ],
    ),
  );
}
