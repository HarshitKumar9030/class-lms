import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_components.dart';
import 'announcement_repository.dart';

class AnnouncementTile extends StatelessWidget {
  const AnnouncementTile({super.key, required this.announcement, this.onTap});
  final Announcement announcement;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: AppSurface(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (!announcement.isRead) ...[
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: context.palette.accent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  announcement.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (announcement.isPinned)
                Icon(
                  Icons.push_pin_rounded,
                  size: 16,
                  color: context.palette.secondary,
                ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            announcement.content,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: context.palette.secondary),
          ),
          const SizedBox(height: 12),
          Text(
            '${announcement.priority == 2 ? 'Important · ' : ''}${DateFormat.MMMd().format(announcement.createdAt)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    ),
  );
}

class AnnouncementListScreen extends ConsumerWidget {
  const AnnouncementListScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(announcementsProvider);
    return AppPage(
      title: 'Announcements',
      onRefresh: () async => ref.invalidate(announcementsProvider),
      children: [
        feed.when(
          loading: () => const LoadingRows(),
          error: (_, _) => ErrorState(
            message: 'Check your connection and try again.',
            onRetry: () => ref.invalidate(announcementsProvider),
          ),
          data: (items) => items.isEmpty
              ? const EmptyState(
                  title: 'You’re all caught up',
                  message: 'Announcements from your teacher will appear here.',
                  icon: Icons.campaign_outlined,
                )
              : Column(
                  children: items
                      .map(
                        (item) => AnnouncementTile(
                          announcement: item,
                          onTap: () =>
                              context.push('/announcements/${item.id}'),
                        ),
                      )
                      .toList(),
                ),
        ),
      ],
    );
  }
}

class AnnouncementDetailScreen extends ConsumerStatefulWidget {
  const AnnouncementDetailScreen({super.key, required this.id});
  final String id;
  @override
  ConsumerState<AnnouncementDetailScreen> createState() =>
      _AnnouncementDetailScreenState();
}

class _AnnouncementDetailScreenState
    extends ConsumerState<AnnouncementDetailScreen> {
  bool marked = false;
  @override
  Widget build(BuildContext context) {
    final value = ref.watch(announcementProvider(widget.id));
    value.whenData((_) {
      if (!marked) {
        marked = true;
        Future.microtask(() async {
          try {
            await ref.read(announcementRepositoryProvider).markRead(widget.id);
            ref.invalidate(announcementsProvider);
          } catch (_) {
            /* Reading remains available if the receipt fails. */
          }
        });
      }
    });
    return Scaffold(
      appBar: AppBar(title: const Text('Announcement')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.page),
          children: [
            value.when(
              loading: () => const LoadingRows(count: 2),
              error: (_, _) => ErrorState(
                message: 'This announcement may have been removed.',
                onRetry: () => ref.invalidate(announcementProvider(widget.id)),
              ),
              data: (item) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    DateFormat.yMMMMd().format(item.createdAt),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 32),
                  Text(
                    item.content,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  if (item.attachmentPaths.isNotEmpty) ...[
                    const SectionHeader(title: 'Attachments'),
                    ...item.attachmentPaths.map(
                      (path) => AppRow(
                        title: path.split('/').last,
                        icon: Icons.attach_file_rounded,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
