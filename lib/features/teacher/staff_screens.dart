import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_components.dart';
import '../announcements/announcement_repository.dart';
import '../assignments/assignment_repository.dart';
import '../auth/auth_repository.dart';
import '../home/home_repository.dart';
import '../resources/resource_repository.dart';
import '../schedule/schedule_repository.dart';
import 'staff_repository.dart';

const staffSections = <String, (String, String, IconData)>{
  'courses': (
    'Courses & topics',
    'Organize your lessons',
    Icons.menu_book_outlined,
  ),
  'batches': ('Batches', 'Group and enroll students', Icons.groups_outlined),
  'resources': (
    'Resources',
    'Upload files and useful links',
    Icons.folder_outlined,
  ),
  'announcements': (
    'Announcements',
    'Share class updates',
    Icons.campaign_outlined,
  ),
  'schedule_events': (
    'Schedule',
    'Plan classes and tests',
    Icons.calendar_today_outlined,
  ),
  'assignments': ('Assignments', 'Set homework', Icons.assignment_outlined),
  'quizzes': ('Quizzes', 'Write and publish questions', Icons.quiz_outlined),
};

class StaffWorkspaceScreen extends ConsumerWidget {
  const StaffWorkspaceScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => AppPage(
    title: 'Teacher workspace',
    children: [
      Text(
        'Create and manage class content',
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: 8),
      Text(
        'Choose what you want to add. Published items become available to the selected batches.',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: context.palette.secondary),
      ),
      const SectionHeader(title: 'Content'),
      for (final entry in staffSections.entries)
        AppRow(
          title: entry.value.$1,
          subtitle: entry.value.$2,
          icon: entry.value.$3,
          onTap: () => context.push('/teacher/sections/${entry.key}'),
        ),
      const SizedBox(height: 20),
    ],
  );
}

class StaffSectionScreen extends ConsumerWidget {
  const StaffSectionScreen({super.key, required this.section});
  final String section;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final details = staffSections[section];
    if (details == null) {
      return const Scaffold(body: Center(child: Text('Section unavailable')));
    }
    final value = ref.watch(staffItemsProvider(section));
    return AppPage(
      title: details.$1,
      trailing: IconButton(
        tooltip: 'Add ${details.$1}',
        icon: const Icon(Icons.add_rounded),
        onPressed: () => context.push('/teacher/new/$section'),
      ),
      onRefresh: () async => ref.invalidate(staffItemsProvider(section)),
      children: [
        Text(
          details.$2,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: context.palette.secondary),
        ),
        const SizedBox(height: 20),
        PrimaryButton(
          label: section == 'courses'
              ? 'Add course'
              : 'Add ${details.$1.toLowerCase()}',
          onPressed: () => context.push('/teacher/new/$section'),
        ),
        const SectionHeader(title: 'Existing'),
        value.when(
          loading: () => const LoadingRows(),
          error: (_, _) => ErrorState(
            message: 'Couldn’t load content.',
            onRetry: () => ref.invalidate(staffItemsProvider(section)),
          ),
          data: (items) => items.isEmpty
              ? CompactEmptyState(
                  title: 'Nothing added yet',
                  message: 'Your ${details.$1.toLowerCase()} will appear here.',
                  icon: details.$3,
                )
              : Column(
                  children: [
                    for (final item in items)
                      AppRow(
                        title: item.title,
                        subtitle: switch (section) {
                          'courses' => 'Course',
                          'batches' => 'Batch',
                          'schedule_events' => 'Scheduled',
                          _ => item.published ? 'Published' : 'Draft',
                        },
                        icon: details.$3,
                        onTap: switch (section) {
                          'courses' => () => context.push(
                            '/teacher/courses/${item.id}',
                          ),
                          'batches' => () => context.push(
                            '/teacher/batches/${item.id}',
                          ),
                          'quizzes' => () => context.push(
                            '/teacher/quizzes/${item.id}',
                          ),
                          _ => null,
                        },
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class StaffCourseScreen extends ConsumerWidget {
  const StaffCourseScreen({super.key, required this.courseId});
  final String courseId;

  Future<void> addTopic(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add topic'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Topic name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (title == null || title.isEmpty) return;
    try {
      await ref.read(staffRepositoryProvider).createTopic(courseId, title);
      ref.invalidate(staffTopicsProvider(courseId));
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Couldn’t add topic.')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => AppPage(
    title: 'Topics',
    trailing: IconButton(
      tooltip: 'Add topic',
      icon: const Icon(Icons.add_rounded),
      onPressed: () => addTopic(context, ref),
    ),
    children: [
      PrimaryButton(
        label: 'Add topic',
        onPressed: () => addTopic(context, ref),
      ),
      const SectionHeader(title: 'In this course'),
      ref
          .watch(staffTopicsProvider(courseId))
          .when(
            loading: () => const LoadingRows(),
            error: (_, _) => ErrorState(
              message: 'Couldn’t load topics.',
              onRetry: () => ref.invalidate(staffTopicsProvider(courseId)),
            ),
            data: (topics) => topics.isEmpty
                ? const CompactEmptyState(
                    title: 'No topics yet',
                    message: 'Topics help organize resources.',
                    icon: Icons.topic_outlined,
                  )
                : Column(
                    children: [
                      for (final topic in topics)
                        AppRow(title: topic.title, icon: Icons.topic_outlined),
                    ],
                  ),
          ),
    ],
  );
}

class StaffBatchScreen extends ConsumerWidget {
  const StaffBatchScreen({super.key, required this.batchId});
  final String batchId;

  Future<void> enroll(
    BuildContext context,
    WidgetRef ref,
    String studentId,
  ) async {
    try {
      await ref.read(staffRepositoryProvider).addStudent(batchId, studentId);
      ref.invalidate(staffBatchStudentIdsProvider(batchId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Student added to batch.')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Couldn’t add student. Admin access is required.'),
          ),
        );
      }
    }
  }

  Future<void> remove(
    BuildContext context,
    WidgetRef ref,
    String studentId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove student?'),
        content: const Text(
          'This student will lose access to content for this batch.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(staffRepositoryProvider).removeStudent(batchId, studentId);
      ref.invalidate(staffBatchStudentIdsProvider(batchId));
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Couldn’t remove student.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(profileProvider).value?.role == AppRole.admin;
    final students = ref.watch(staffStudentsProvider);
    final members = ref.watch(staffBatchStudentIdsProvider(batchId));
    return AppPage(
      title: 'Batch students',
      children: [
        Text(
          isAdmin
              ? 'Choose students to add to this batch.'
              : 'Only admins can change batch enrollment.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SectionHeader(title: 'Students'),
        students.when(
          loading: () => const LoadingRows(),
          error: (_, _) => ErrorState(
            message: 'Couldn’t load students.',
            onRetry: () => ref.invalidate(staffStudentsProvider),
          ),
          data: (all) => members.when(
            loading: () => const LoadingRows(),
            error: (_, _) => ErrorState(
              message: 'Couldn’t load enrollment.',
              onRetry: () =>
                  ref.invalidate(staffBatchStudentIdsProvider(batchId)),
            ),
            data: (ids) => all.isEmpty
                ? const CompactEmptyState(
                    title: 'No student accounts yet',
                    message:
                        'Students can create accounts from the sign-up screen.',
                    icon: Icons.person_add_alt_outlined,
                  )
                : Column(
                    children: [
                      for (final student in all)
                        AppRow(
                          title: student.title.isEmpty
                              ? 'Student'
                              : student.title,
                          subtitle: ids.contains(student.id)
                              ? 'Enrolled'
                              : 'Not enrolled',
                          icon: ids.contains(student.id)
                              ? Icons.check_circle_rounded
                              : Icons.person_outline,
                          onTap: !isAdmin
                              ? null
                              : ids.contains(student.id)
                              ? () => remove(context, ref, student.id)
                              : () => enroll(context, ref, student.id),
                        ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

class StaffCreateScreen extends ConsumerStatefulWidget {
  const StaffCreateScreen({super.key, required this.section});
  final String section;
  @override
  ConsumerState<StaffCreateScreen> createState() => _StaffCreateScreenState();
}

class _StaffCreateScreenState extends ConsumerState<StaffCreateScreen> {
  final title = TextEditingController();
  final description = TextEditingController();
  final detail = TextEditingController();
  final location = TextEditingController();
  final url = TextEditingController();
  final number = TextEditingController();
  final batchIds = <String>{};
  String? courseId;
  String? topicId;
  String resourceKind = 'pdf';
  String scheduleKind = 'class';
  bool pinned = false;
  bool fileMode = true;
  int priority = 0;
  PlatformFile? file;
  DateTime startsAt = DateTime.now().add(const Duration(days: 1));
  DateTime endsAt = DateTime.now().add(const Duration(days: 1, hours: 1));
  DateTime dueAt = DateTime.now().add(const Duration(days: 7));
  bool busy = false;
  String? error;

  @override
  void dispose() {
    for (final controller in [
      title,
      description,
      detail,
      location,
      url,
      number,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<DateTime?> chooseDateTime(DateTime current) async {
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> pickFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'pdf',
        'doc',
        'docx',
        'jpg',
        'jpeg',
        'png',
        'mp3',
        'm4a',
        'mp4',
        'ppt',
        'pptx',
      ],
    );
    if (result.isNotEmpty) setState(() => file = result.first);
  }

  String? validate() {
    if (title.text.trim().isEmpty) return 'Enter a title.';
    switch (widget.section) {
      case 'resources':
        if (courseId == null) return 'Create and select a course first.';
        if (fileMode && file == null) return 'Choose a file to upload.';
        final link = Uri.tryParse(url.text.trim());
        if (!fileMode &&
            (link == null || link.scheme != 'https' || link.host.isEmpty)) {
          return 'Enter a valid HTTPS link.';
        }
      case 'announcements':
        if (detail.text.trim().isEmpty) return 'Enter the content.';
      case 'schedule_events':
        if (!endsAt.isAfter(startsAt)) {
          return 'End time must be after start time.';
        }
      case 'assignments':
        if (detail.text.trim().isEmpty) return 'Enter the instructions.';
        if (number.text.trim().isNotEmpty &&
            (num.tryParse(number.text.trim()) ?? 0) <= 0) {
          return 'Maximum marks must be positive.';
        }
      case 'quizzes':
        if (number.text.trim().isNotEmpty &&
            (int.tryParse(number.text) ?? 0) <= 0) {
          return 'Duration must be a positive number.';
        }
    }
    return null;
  }

  Future<void> save() async {
    final issue = validate();
    if (issue != null) {
      setState(() => error = issue);
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final repo = ref.read(staffRepositoryProvider);
      switch (widget.section) {
        case 'courses':
          await repo.createCourse(title.text);
        case 'batches':
          await repo.createBatch(title.text, description.text);
        case 'announcements':
          await repo.createAnnouncement(
            title: title.text,
            content: detail.text,
            batchIds: batchIds.toList(),
            pinned: pinned,
            priority: priority,
          );
        case 'schedule_events':
          await repo.createSchedule(
            title: title.text,
            subtitle: detail.text,
            startsAt: startsAt,
            endsAt: endsAt,
            kind: scheduleKind,
            location: location.text,
            batchIds: batchIds.toList(),
          );
        case 'assignments':
          await repo.createAssignment(
            title: title.text,
            instructions: detail.text,
            dueAt: dueAt,
            batchIds: batchIds.toList(),
            maximumMarks: num.tryParse(number.text),
          );
        case 'resources':
          if (fileMode) {
            await repo.createFileResource(
              title: title.text,
              description: description.text,
              courseId: courseId!,
              topicId: topicId,
              kind: resourceKind,
              file: file!,
              batchIds: batchIds.toList(),
            );
          } else {
            await repo.createLinkResource(
              title: title.text,
              description: description.text,
              courseId: courseId!,
              topicId: topicId,
              kind: resourceKind,
              url: url.text,
              batchIds: batchIds.toList(),
            );
          }
        case 'quizzes':
          final id = await repo.createQuiz(
            title: title.text,
            description: description.text,
            batchIds: batchIds.toList(),
            durationMinutes: int.tryParse(number.text),
          );
          ref.invalidate(staffItemsProvider('quizzes'));
          if (mounted) context.pushReplacement('/teacher/quizzes/$id');
          return;
      }
      ref.invalidate(staffItemsProvider(widget.section));
      ref.invalidate(staffCoursesProvider);
      ref.invalidate(staffBatchesProvider);
      ref.invalidate(resourcesProvider);
      ref.invalidate(announcementsProvider);
      ref.invalidate(assignmentsProvider);
      ref.invalidate(scheduleWeekProvider);
      ref.invalidate(homeOverviewProvider);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Content saved.')));
        context.pop();
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Couldn’t save this content. Check your connection and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget field(
    TextEditingController controller,
    String label, {
    int lines = 1,
    TextInputType? keyboardType,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: controller,
      minLines: lines,
      maxLines: lines == 1 ? 1 : lines + 3,
      keyboardType: keyboardType,
      decoration: InputDecoration(labelText: label),
    ),
  );

  Widget batchSelector() => ref
      .watch(staffBatchesProvider)
      .when(
        loading: () => const LoadingRows(count: 1),
        error: (_, _) => ErrorState(
          message: 'Couldn’t load batches.',
          onRetry: () => ref.invalidate(staffBatchesProvider),
        ),
        data: (batches) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(title: 'Audience'),
            Text(
              batchIds.isEmpty
                  ? 'All enrolled students'
                  : 'Only selected batches',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final batch in batches)
                  FilterChip(
                    label: Text(batch.title),
                    selected: batchIds.contains(batch.id),
                    onSelected: (value) => setState(
                      () => value
                          ? batchIds.add(batch.id)
                          : batchIds.remove(batch.id),
                    ),
                  ),
              ],
            ),
          ],
        ),
      );

  Widget dateRow(String label, DateTime value, ValueChanged<DateTime> update) =>
      AppRow(
        title: label,
        subtitle: DateFormat.yMMMd().add_jm().format(value),
        icon: Icons.event_outlined,
        onTap: () async {
          final picked = await chooseDateTime(value);
          if (picked != null) setState(() => update(picked));
        },
      );

  @override
  Widget build(BuildContext context) {
    final section = widget.section;
    final details = staffSections[section];
    if (details == null) {
      return const Scaffold(body: Center(child: Text('Section unavailable')));
    }
    final courseData = ref.watch(staffCoursesProvider);
    final topics = courseId == null
        ? null
        : ref.watch(staffTopicsProvider(courseId!));
    return Scaffold(
      appBar: AppBar(
        title: Text(
          section == 'courses'
              ? 'Add course'
              : 'Add ${details.$1.toLowerCase()}',
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.page),
              children: [
                field(title, section == 'batches' ? 'Batch name' : 'Title'),
                if (section == 'batches' ||
                    section == 'resources' ||
                    section == 'quizzes')
                  field(description, 'Description', lines: 2),
                if (section == 'announcements') ...[
                  field(detail, 'Announcement', lines: 5),
                  SwitchListTile(
                    title: const Text('Pin announcement'),
                    value: pinned,
                    onChanged: (value) => setState(() => pinned = value),
                  ),
                  DropdownButtonFormField<int>(
                    initialValue: priority,
                    decoration: const InputDecoration(labelText: 'Priority'),
                    items: const [
                      DropdownMenuItem(value: 0, child: Text('Normal')),
                      DropdownMenuItem(value: 1, child: Text('Important')),
                      DropdownMenuItem(value: 2, child: Text('Urgent')),
                    ],
                    onChanged: (value) => setState(() => priority = value ?? 0),
                  ),
                ],
                if (section == 'resources') ...[
                  const SectionHeader(title: 'Placement'),
                  courseData.when(
                    loading: () => const LoadingRows(count: 1),
                    error: (_, _) => ErrorState(
                      message: 'Couldn’t load courses.',
                      onRetry: () => ref.invalidate(staffCoursesProvider),
                    ),
                    data: (courses) => courses.isEmpty
                        ? const CompactEmptyState(
                            title: 'Create a course first',
                            message: 'Resources need a course.',
                            icon: Icons.menu_book_outlined,
                          )
                        : DropdownButtonFormField<String>(
                            initialValue: courseId,
                            decoration: const InputDecoration(
                              labelText: 'Course',
                            ),
                            items: [
                              for (final course in courses)
                                DropdownMenuItem(
                                  value: course.id,
                                  child: Text(course.title),
                                ),
                            ],
                            onChanged: (value) => setState(() {
                              courseId = value;
                              topicId = null;
                            }),
                          ),
                  ),
                  const SizedBox(height: 12),
                  if (topics != null)
                    topics.when(
                      loading: () => const LoadingRows(count: 1),
                      error: (_, _) => ErrorState(
                        message: 'Couldn’t load topics.',
                        onRetry: () =>
                            ref.invalidate(staffTopicsProvider(courseId!)),
                      ),
                      data: (values) => DropdownButtonFormField<String>(
                        initialValue: topicId,
                        decoration: const InputDecoration(
                          labelText: 'Topic (optional)',
                        ),
                        items: [
                          for (final topic in values)
                            DropdownMenuItem(
                              value: topic.id,
                              child: Text(topic.title),
                            ),
                        ],
                        onChanged: (value) => setState(() => topicId = value),
                      ),
                    ),
                  const SectionHeader(title: 'Material'),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: true, label: Text('File')),
                      ButtonSegment(value: false, label: Text('Link')),
                    ],
                    selected: {fileMode},
                    onSelectionChanged: (value) => setState(() {
                      fileMode = value.first;
                      resourceKind = fileMode ? 'pdf' : 'web_link';
                    }),
                  ),
                  const SizedBox(height: 14),
                  if (fileMode) ...[
                    DropdownButtonFormField<String>(
                      initialValue: resourceKind,
                      decoration: const InputDecoration(labelText: 'Type'),
                      items: const [
                        DropdownMenuItem(value: 'pdf', child: Text('PDF')),
                        DropdownMenuItem(
                          value: 'document',
                          child: Text('Document'),
                        ),
                        DropdownMenuItem(value: 'image', child: Text('Image')),
                        DropdownMenuItem(value: 'audio', child: Text('Audio')),
                        DropdownMenuItem(
                          value: 'presentation',
                          child: Text('Presentation'),
                        ),
                        DropdownMenuItem(
                          value: 'worksheet',
                          child: Text('Worksheet'),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => resourceKind = value ?? 'pdf'),
                    ),
                    const SizedBox(height: 12),
                    AppRow(
                      title: file?.name ?? 'Choose file',
                      icon: Icons.upload_file_rounded,
                      onTap: pickFile,
                    ),
                  ] else ...[
                    DropdownButtonFormField<String>(
                      initialValue: resourceKind,
                      decoration: const InputDecoration(labelText: 'Type'),
                      items: const [
                        DropdownMenuItem(
                          value: 'web_link',
                          child: Text('Website'),
                        ),
                        DropdownMenuItem(
                          value: 'video_link',
                          child: Text('Video link'),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => resourceKind = value ?? 'web_link'),
                    ),
                    const SizedBox(height: 12),
                    field(url, 'HTTPS URL', keyboardType: TextInputType.url),
                  ],
                ],
                if (section == 'schedule_events') ...[
                  field(detail, 'Subtitle'),
                  DropdownButtonFormField<String>(
                    initialValue: scheduleKind,
                    decoration: const InputDecoration(labelText: 'Event type'),
                    items: const [
                      DropdownMenuItem(value: 'class', child: Text('Class')),
                      DropdownMenuItem(value: 'test', child: Text('Test')),
                      DropdownMenuItem(
                        value: 'special',
                        child: Text('Special event'),
                      ),
                      DropdownMenuItem(
                        value: 'holiday',
                        child: Text('Holiday'),
                      ),
                    ],
                    onChanged: (value) =>
                        setState(() => scheduleKind = value ?? 'class'),
                  ),
                  const SizedBox(height: 12),
                  field(location, 'Location or meeting link'),
                  const SectionHeader(title: 'When'),
                  dateRow('Starts', startsAt, (value) => startsAt = value),
                  dateRow('Ends', endsAt, (value) => endsAt = value),
                ],
                if (section == 'assignments') ...[
                  field(detail, 'Instructions', lines: 5),
                  dateRow('Due', dueAt, (value) => dueAt = value),
                  field(
                    number,
                    'Maximum marks (optional)',
                    keyboardType: TextInputType.number,
                  ),
                ],
                if (section == 'quizzes')
                  field(
                    number,
                    'Duration in minutes (optional)',
                    keyboardType: TextInputType.number,
                  ),
                if (!const ['courses', 'batches'].contains(section))
                  batchSelector(),
                if (error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                PrimaryButton(
                  label: section == 'quizzes'
                      ? 'Create draft and add questions'
                      : const ['courses', 'batches'].contains(section)
                      ? 'Create'
                      : 'Publish',
                  onPressed: save,
                  busy: busy,
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
