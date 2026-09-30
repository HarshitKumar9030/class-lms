import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_components.dart';
import '../auth/auth_repository.dart';
import 'assignment_repository.dart';

String assignmentState(Assignment assignment) {
  if (assignment.submission != null) {
    return switch (assignment.submission!.status) {
      'reviewed' => 'Reviewed',
      'late' => 'Submitted late',
      _ => 'Submitted',
    };
  }
  return DateTime.now().isAfter(assignment.dueAt)
      ? 'Past due'
      : 'Not submitted';
}

class AssignmentListScreen extends ConsumerWidget {
  const AssignmentListScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(assignmentsProvider);
    return AppPage(
      title: 'Assignments',
      onRefresh: () async => ref.invalidate(assignmentsProvider),
      children: [
        value.when(
          loading: () => const LoadingRows(),
          error: (_, _) => ErrorState(
            message: 'Check your connection and try again.',
            onRetry: () => ref.invalidate(assignmentsProvider),
          ),
          data: (items) => items.isEmpty
              ? const EmptyState(
                  title: 'No homework yet',
                  message: 'Assignments from your teacher will appear here.',
                  icon: Icons.task_alt_rounded,
                )
              : Column(
                  children: items
                      .map(
                        (item) => AppRow(
                          title: item.title,
                          subtitle:
                              '${assignmentState(item)} · Due ${DateFormat.MMMd().add_jm().format(item.dueAt)}',
                          icon: Icons.assignment_outlined,
                          onTap: () => context.push('/assignments/${item.id}'),
                        ),
                      )
                      .toList(),
                ),
        ),
      ],
    );
  }
}

class AssignmentDetailScreen extends ConsumerStatefulWidget {
  const AssignmentDetailScreen({super.key, required this.id});
  final String id;
  @override
  ConsumerState<AssignmentDetailScreen> createState() =>
      _AssignmentDetailScreenState();
}

class _AssignmentDetailScreenState
    extends ConsumerState<AssignmentDetailScreen> {
  final response = TextEditingController();
  final files = <PlatformFile>[];
  bool busy = false;
  String? error;

  @override
  void dispose() {
    response.dispose();
    super.dispose();
  }

  Future<void> pickFiles() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'],
    );
    if (result.isNotEmpty) setState(() => files.addAll(result));
  }

  Future<void> submit(Assignment assignment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Submit assignment?'),
        content: const Text('Your answer will be sent to your teacher.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await ref
          .read(assignmentRepositoryProvider)
          .submit(assignment, response.text, files);
      ref.invalidate(assignmentProvider(widget.id));
      ref.invalidate(assignmentsProvider);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Assignment submitted.')));
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is StateError
              ? e.message
              : 'Couldn’t submit. Check your connection and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> openAttachment(
    String path, {
    String bucket = 'resources',
  }) async {
    try {
      final client = ref.read(authRepositoryProvider).client;
      final url = await client.storage.from(bucket).createSignedUrl(path, 3600);
      if (!await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      )) {
        throw StateError('Open failed');
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Couldn’t open the attachment.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(assignmentProvider(widget.id));
    return Scaffold(
      appBar: AppBar(title: const Text('Assignment')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.page),
          children: [
            value.when(
              loading: () => const LoadingRows(count: 3),
              error: (_, _) => ErrorState(
                message: 'This assignment may have been removed.',
                onRetry: () => ref.invalidate(assignmentProvider(widget.id)),
              ),
              data: (assignment) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    assignment.title,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${assignmentState(assignment)} · Due ${DateFormat.yMMMd().add_jm().format(assignment.dueAt)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 32),
                  Text(
                    assignment.instructions,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  if (assignment.attachmentPaths.isNotEmpty) ...[
                    const SectionHeader(title: 'Materials'),
                    for (final path in assignment.attachmentPaths)
                      AppRow(
                        title: path.split('/').last,
                        icon: Icons.attach_file_rounded,
                        onTap: () => openAttachment(path),
                      ),
                  ],
                  const SectionHeader(title: 'Your work'),
                  if (assignment.submission != null) ...[
                    AppSurface(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (assignment.submission!.responseText != null)
                            Text(assignment.submission!.responseText!),
                          Text(
                            'Submitted ${DateFormat.yMMMd().add_jm().format(assignment.submission!.submittedAt)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          if (assignment.submission!.marks != null) ...[
                            const SizedBox(height: 16),
                            Text(
                              'Marks: ${assignment.submission!.marks}${assignment.maximumMarks == null ? '' : ' / ${assignment.maximumMarks}'}',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                          if (assignment.submission!.feedback != null) ...[
                            const SizedBox(height: 8),
                            Text(assignment.submission!.feedback!),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (final path in assignment.submission!.attachmentPaths)
                      AppRow(
                        title: path.split('/').last,
                        icon: Icons.attach_file_rounded,
                        onTap: () =>
                            openAttachment(path, bucket: 'submissions'),
                      ),
                  ] else ...[
                    TextField(
                      controller: response,
                      minLines: 5,
                      maxLines: 10,
                      decoration: const InputDecoration(
                        hintText: 'Write your answer here…',
                      ),
                    ),
                    const SizedBox(height: 12),
                    AppRow(
                      title: 'Add PDF, document or images',
                      icon: Icons.attach_file_rounded,
                      onTap: pickFiles,
                    ),
                    for (final file in files)
                      AppRow(
                        title: file.name,
                        trailing: IconButton(
                          tooltip: 'Remove ${file.name}',
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => setState(() => files.remove(file)),
                        ),
                      ),
                    if (error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    PrimaryButton(
                      label: 'Submit assignment',
                      onPressed: () => submit(assignment),
                      busy: busy,
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
