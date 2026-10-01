import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_components.dart';
import '../home/home_repository.dart';
import '../auth/auth_repository.dart';
import '../quizzes/quiz_repository.dart';
import 'staff_repository.dart';

class StaffQuizEditorScreen extends ConsumerStatefulWidget {
  const StaffQuizEditorScreen({super.key, required this.quizId});
  final String quizId;
  @override
  ConsumerState<StaffQuizEditorScreen> createState() => _StaffQuizEditorState();
}

class _StaffQuizEditorState extends ConsumerState<StaffQuizEditorScreen> {
  bool publishing = false;

  Future<void> manageQuestion(Map<String, dynamic> question) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: Text(question['prompt'] as String)),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit question'),
              onTap: () => Navigator.pop(context, 'edit'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Delete question'),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (action == null) return;
    final repo = ref.read(staffRepositoryProvider);
    final locked = await repo.quizHasAttempts(widget.quizId);
    if (!mounted) return;
    if (locked) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Questions are locked after a student starts the quiz.',
            ),
          ),
        );
      }
      return;
    }
    if (action == 'delete') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete question?'),
          content: const Text('This cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      try {
        await repo.deleteQuizQuestion(widget.quizId, question['id'] as String);
        ref.invalidate(staffQuizQuestionsProvider(widget.quizId));
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Couldn’t delete question.')),
          );
        }
      }
      return;
    }
    final controller = TextEditingController(
      text: question['prompt'] as String,
    );
    final updated = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit question'),
        content: TextField(
          controller: controller,
          minLines: 2,
          maxLines: 5,
          decoration: const InputDecoration(labelText: 'Question text'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (updated == null || updated.isEmpty) return;
    try {
      await repo.updateQuizPrompt(
        widget.quizId,
        question['id'] as String,
        updated,
      );
      ref.invalidate(staffQuizQuestionsProvider(widget.quizId));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Couldn’t update question.')),
        );
      }
    }
  }

  Future<void> publish() async {
    final questions = ref.read(staffQuizQuestionsProvider(widget.quizId)).value;
    if (questions == null || questions.isEmpty) return;
    setState(() => publishing = true);
    try {
      await ref.read(staffRepositoryProvider).publishQuiz(widget.quizId);
      ref.invalidate(staffItemsProvider('quizzes'));
      ref.invalidate(quizzesProvider);
      ref.invalidate(homeOverviewProvider);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Quiz published.')));
        context.pop();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Couldn’t publish the quiz.')),
        );
      }
    } finally {
      if (mounted) setState(() => publishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final questions = ref.watch(staffQuizQuestionsProvider(widget.quizId));
    final items =
        ref.watch(staffItemsProvider('quizzes')).value ?? const <StaffItem>[];
    final ownId = ref.read(staffRepositoryProvider).userId;
    final isAdmin = ref.watch(profileProvider).value?.role == AppRole.admin;
    final matching = items.where((item) => item.id == widget.quizId);
    final canManage =
        matching.isNotEmpty && (isAdmin || matching.first.ownerId == ownId);
    return AppPage(
      title: 'Quiz questions',
      trailing: IconButton(
        tooltip: 'Edit quiz',
        icon: const Icon(Icons.edit_outlined),
        onPressed: canManage
            ? () => context.push('/teacher/edit/quizzes/${widget.quizId}')
            : null,
      ),
      children: [
        Text(
          'Add questions, then publish the quiz for its selected batches.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: context.palette.secondary),
        ),
        const SizedBox(height: 20),
        PrimaryButton(
          label: 'Add question',
          onPressed: canManage
              ? () => context.push(
                  '/teacher/quizzes/${widget.quizId}/questions/new',
                )
              : null,
        ),
        const SectionHeader(title: 'Questions'),
        questions.when(
          loading: () => const LoadingRows(),
          error: (_, _) => ErrorState(
            message: 'Couldn’t load questions.',
            onRetry: () =>
                ref.invalidate(staffQuizQuestionsProvider(widget.quizId)),
          ),
          data: (items) => items.isEmpty
              ? const CompactEmptyState(
                  title: 'No questions yet',
                  message: 'Add at least one question before publishing.',
                  icon: Icons.quiz_outlined,
                )
              : Column(
                  children: [
                    for (var index = 0; index < items.length; index++)
                      AppRow(
                        title: '${index + 1}. ${items[index]['prompt']}',
                        subtitle:
                            '${(items[index]['kind'] as String).replaceAll('_', ' ')} · ${items[index]['marks']} marks',
                        icon: Icons.help_outline_rounded,
                        onTap: canManage
                            ? () => manageQuestion(items[index])
                            : null,
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 20),
        PrimaryButton(
          label: 'Publish quiz',
          onPressed: canManage && questions.value?.isNotEmpty == true
              ? publish
              : null,
          busy: publishing,
        ),
      ],
    );
  }
}

class StaffQuestionScreen extends ConsumerStatefulWidget {
  const StaffQuestionScreen({super.key, required this.quizId});
  final String quizId;
  @override
  ConsumerState<StaffQuestionScreen> createState() => _StaffQuestionState();
}

class _StaffQuestionState extends ConsumerState<StaffQuestionScreen> {
  final prompt = TextEditingController();
  final marks = TextEditingController(text: '1');
  final answer = TextEditingController();
  final options = List.generate(4, (_) => TextEditingController());
  String kind = 'single_choice';
  final selected = <int>{};
  bool busy = false;
  String? error;

  @override
  void dispose() {
    prompt.dispose();
    marks.dispose();
    answer.dispose();
    for (final option in options) {
      option.dispose();
    }
    super.dispose();
  }

  bool get hasOptions =>
      const ['single_choice', 'multiple_choice', 'true_false'].contains(kind);
  bool get hasAnswer => const ['one_word', 'fill_blank'].contains(kind);

  Future<void> save() async {
    final markValue = num.tryParse(marks.text.trim());
    final labels = kind == 'true_false'
        ? ['True', 'False']
        : options.map((value) => value.text.trim()).toList();
    String? issue;
    if (prompt.text.trim().isEmpty) issue = 'Enter the question.';
    if (markValue == null || markValue <= 0) issue = 'Marks must be positive.';
    if (hasOptions &&
        (labels.any((label) => label.isEmpty) || selected.isEmpty)) {
      issue = 'Complete every option and choose the correct answer.';
    }
    if (hasAnswer && answer.text.trim().isEmpty) {
      issue = 'Enter the correct answer.';
    }
    if (issue != null) {
      setState(() => error = issue);
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await ref
          .read(staffRepositoryProvider)
          .addQuizQuestion(
            quizId: widget.quizId,
            prompt: prompt.text,
            kind: kind,
            marks: markValue!,
            options: hasOptions ? labels : const [],
            correctIndexes: hasOptions ? selected : const {},
            answerText: hasAnswer ? answer.text.trim() : null,
          );
      ref.invalidate(staffQuizQuestionsProvider(widget.quizId));
      if (mounted) context.pop();
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Couldn’t save the question. Try again.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Add question')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.page),
            children: [
              DropdownButtonFormField<String>(
                initialValue: kind,
                decoration: const InputDecoration(labelText: 'Question type'),
                items: const [
                  DropdownMenuItem(
                    value: 'single_choice',
                    child: Text('Single choice'),
                  ),
                  DropdownMenuItem(
                    value: 'multiple_choice',
                    child: Text('Multiple choice'),
                  ),
                  DropdownMenuItem(
                    value: 'true_false',
                    child: Text('True or false'),
                  ),
                  DropdownMenuItem(value: 'one_word', child: Text('One word')),
                  DropdownMenuItem(
                    value: 'fill_blank',
                    child: Text('Fill in the blank'),
                  ),
                  DropdownMenuItem(
                    value: 'short_answer',
                    child: Text('Short answer (manual review)'),
                  ),
                ],
                onChanged: (value) => setState(() {
                  kind = value ?? 'single_choice';
                  selected.clear();
                }),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: prompt,
                minLines: 2,
                maxLines: 5,
                decoration: const InputDecoration(labelText: 'Question'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: marks,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Marks'),
              ),
              if (hasOptions) ...[
                const SectionHeader(title: 'Answers'),
                Text(
                  kind == 'multiple_choice'
                      ? 'Select every correct answer.'
                      : 'Select the correct answer.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                for (
                  var index = 0;
                  index < (kind == 'true_false' ? 2 : 4);
                  index++
                )
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Checkbox(
                          value: selected.contains(index),
                          onChanged: (checked) => setState(() {
                            if (kind != 'multiple_choice') selected.clear();
                            if (checked == true) {
                              selected.add(index);
                            } else {
                              selected.remove(index);
                            }
                          }),
                        ),
                        Expanded(
                          child: kind == 'true_false'
                              ? Text(index == 0 ? 'True' : 'False')
                              : TextField(
                                  controller: options[index],
                                  decoration: InputDecoration(
                                    labelText: 'Option ${index + 1}',
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
              ],
              if (hasAnswer) ...[
                const SectionHeader(title: 'Correct answer'),
                TextField(
                  controller: answer,
                  decoration: const InputDecoration(labelText: 'Answer text'),
                ),
              ],
              if (kind == 'short_answer') ...[
                const SizedBox(height: 20),
                Text(
                  'Short answers need a teacher to review and award marks.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              if (error != null) ...[
                const SizedBox(height: 16),
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 28),
              PrimaryButton(
                label: 'Save question',
                onPressed: save,
                busy: busy,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
