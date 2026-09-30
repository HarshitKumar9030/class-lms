import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_components.dart';
import 'resource_repository.dart';

IconData resourceIcon(ResourceKind kind) => switch (kind) {
  ResourceKind.pdf ||
  ResourceKind.worksheet ||
  ResourceKind.presentation => Icons.picture_as_pdf_outlined,
  ResourceKind.audio => Icons.headphones_rounded,
  ResourceKind.image => Icons.image_outlined,
  ResourceKind.videoLink => Icons.play_circle_outline_rounded,
  ResourceKind.webLink => Icons.link_rounded,
  _ => Icons.description_outlined,
};

class ResourceLibraryScreen extends ConsumerStatefulWidget {
  const ResourceLibraryScreen({super.key});
  @override
  ConsumerState<ResourceLibraryScreen> createState() =>
      _ResourceLibraryScreenState();
}

class _ResourceLibraryScreenState extends ConsumerState<ResourceLibraryScreen> {
  String search = '';
  String filter = 'All';
  static const filters = ['All', 'PDFs', 'Audio', 'Links', 'Saved'];

  bool matches(LearningResource resource) {
    final term = search.trim().toLowerCase();
    final text =
        '${resource.title} ${resource.courseTitle} ${resource.topicTitle ?? ''} ${resource.description ?? ''}'
            .toLowerCase();
    if (term.isNotEmpty && !text.contains(term)) return false;
    return switch (filter) {
      'PDFs' =>
        resource.kind == ResourceKind.pdf ||
            resource.kind == ResourceKind.worksheet,
      'Audio' => resource.kind == ResourceKind.audio,
      'Links' =>
        resource.kind == ResourceKind.webLink ||
            resource.kind == ResourceKind.videoLink,
      'Saved' => resource.isBookmarked,
      _ => true,
    };
  }

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(resourcesProvider);
    return AppPage(
      title: 'Learn',
      onRefresh: () async => ref.invalidate(resourcesProvider),
      children: [
        Text(
          'Find what you need to study.',
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: context.palette.secondary),
        ),
        const SizedBox(height: 24),
        TextField(
          onChanged: (value) => setState(() => search = value),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search_rounded),
            hintText: 'Search lessons and topics',
          ),
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: filters.map((name) {
              final selected = filter == name;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Material(
                  color: selected
                      ? context.palette.accent
                      : context.palette.muted,
                  borderRadius: BorderRadius.circular(AppRadius.small),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppRadius.small),
                    onTap: () => setState(() => filter = name),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: Text(
                        name,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: selected
                              ? (Theme.of(context).brightness == Brightness.dark
                                    ? Colors.black
                                    : Colors.white)
                              : context.palette.text,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),
        value.when(
          loading: () => const LoadingRows(count: 4),
          error: (_, _) => ErrorState(
            message: 'Check your connection and try again.',
            onRetry: () => ref.invalidate(resourcesProvider),
          ),
          data: (all) {
            final resources = all.where(matches).toList();
            if (resources.isEmpty) {
              return EmptyState(
                title: search.isNotEmpty
                    ? 'No matching resources'
                    : 'No resources yet',
                message: search.isNotEmpty
                    ? 'Try a different word or filter.'
                    : 'New lessons will appear here.',
                icon: Icons.menu_book_outlined,
              );
            }
            final groups = <String, List<LearningResource>>{};
            for (final resource in resources) {
              groups.putIfAbsent(resource.courseTitle, () => []).add(resource);
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final group in groups.entries) ...[
                  SectionHeader(title: group.key),
                  for (final resource in group.value)
                    AppRow(
                      title: resource.title,
                      subtitle:
                          '${resource.topicTitle ?? resource.kind.name} · ${resource.kind.name}',
                      icon: resourceIcon(resource.kind),
                      trailing: resource.isBookmarked
                          ? Icon(
                              Icons.bookmark_rounded,
                              color: context.palette.accent,
                            )
                          : null,
                      onTap: () => context.push('/learn/${resource.id}'),
                    ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}
