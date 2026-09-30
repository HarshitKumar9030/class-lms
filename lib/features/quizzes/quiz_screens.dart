import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_components.dart';
import 'quiz_repository.dart';

class QuizListScreen extends ConsumerWidget {
  const QuizListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => AppPage(
    title: 'Quizzes',
    trailing: IconButton(
      tooltip: 'Quiz history',
      onPressed: () => context.push('/quiz-history'),
      icon: const Icon(Icons.history_rounded),
    ),
    onRefresh: () async => ref.invalidate(quizzesProvider),
    children: [
      ref
          .watch(quizzesProvider)
          .when(
            loading: () => const LoadingRows(),
            error: (_, _) => ErrorState(
              message: 'Check your connection and try again.',
              onRetry: () => ref.invalidate(quizzesProvider),
            ),
            data: (quizzes) => quizzes.isEmpty
                ? const EmptyState(
                    title: 'No quizzes yet',
                    message: 'Your teacher’s quizzes will appear here.',
                    icon: Icons.quiz_outlined,
                  )
                : Column(
                    children: [
                      for (final quiz in quizzes)
                        AppRow(
                          title: quiz.title,
                          subtitle: quiz.closesAt == null
                              ? 'Ready when you are'
                              : 'Closes ${DateFormat.MMMd().add_jm().format(quiz.closesAt!)}',
                          icon: Icons.quiz_outlined,
                          onTap: () => context.push('/quizzes/${quiz.id}'),
                        ),
                    ],
                  ),
          ),
    ],
  );
}

class QuizIntroScreen extends ConsumerStatefulWidget {
  const QuizIntroScreen({super.key, required this.id});
  final String id;
  @override
  ConsumerState<QuizIntroScreen> createState() => _QuizIntroScreenState();
}

class _QuizIntroScreenState extends ConsumerState<QuizIntroScreen> {
  bool busy = false;
  String? error;

  Future<void> start() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final id = await ref.read(quizRepositoryProvider).start(widget.id);
      if (mounted) context.pushReplacement('/quiz-attempts/$id');
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Couldn’t start this quiz. It may be closed or your attempt limit has been reached.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Quiz')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.page),
        children: [
          ref
              .watch(quizProvider(widget.id))
              .when(
                loading: () => const LoadingRows(count: 2),
                error: (_, _) => ErrorState(
                  message: 'Quiz unavailable.',
                  onRetry: () => ref.invalidate(quizProvider(widget.id)),
                ),
                data: (quiz) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      quiz.title,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    if (quiz.description?.isNotEmpty ?? false) ...[
                      const SizedBox(height: 12),
                      Text(quiz.description!),
                    ],
                    const SizedBox(height: 28),
                    AppSurface(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Before you begin',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            quiz.durationMinutes == null
                                ? 'No time limit'
                                : '${quiz.durationMinutes} minute time limit',
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${quiz.attemptLimit} ${quiz.attemptLimit == 1 ? 'attempt' : 'attempts'} allowed',
                          ),
                          if (quiz.closesAt != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              'Closes ${DateFormat.yMMMd().add_jm().format(quiz.closesAt!)}',
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (quiz.instructions?.isNotEmpty ?? false) ...[
                      const SectionHeader(title: 'Instructions'),
                      Text(quiz.instructions!),
                    ],
                    if (error != null) ...[
                      const SizedBox(height: 20),
                      Text(
                        error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 28),
                    PrimaryButton(
                      label: 'Start quiz',
                      onPressed: start,
                      busy: busy,
                    ),
                  ],
                ),
              ),
        ],
      ),
    ),
  );
}

class QuizAttemptScreen extends ConsumerStatefulWidget {
  const QuizAttemptScreen({super.key, required this.id});
  final String id;
  @override
  ConsumerState<QuizAttemptScreen> createState() => _QuizAttemptScreenState();
}

class _QuizAttemptScreenState extends ConsumerState<QuizAttemptScreen> {
  final textController = TextEditingController();
  final answers = <String, SavedQuizAnswer>{};
  Timer? ticker;
  Timer? textDebounce;
  Future<void> pendingSave = Future.value();
  bool loaded = false;
  bool busy = false;
  bool submitting = false;
  int index = 0;
  DateTime now = DateTime.now();
  String? error;

  @override
  void dispose() {
    ticker?.cancel();
    textDebounce?.cancel();
    textController.dispose();
    super.dispose();
  }

  void initialize(QuizSession session) {
    if (loaded) return;
    loaded = true;
    answers.addAll(session.answers);
    if (session.questions.isNotEmpty) syncText(session.questions.first);
    ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => now = DateTime.now());
      if (remaining(session) != null &&
          remaining(session)!.inSeconds <= 0 &&
          !submitting) {
        submit(session, confirm: false);
      }
    });
  }

  Duration? remaining(QuizSession session) {
    if (session.quiz.durationMinutes == null) return null;
    final end = session.attempt.startedAt.add(
      Duration(minutes: session.quiz.durationMinutes!),
    );
    final duration = end.difference(now);
    return duration.isNegative ? Duration.zero : duration;
  }

  void syncText(QuizQuestion question) {
    textController.text = answers[question.id]?.responseText ?? '';
  }

  void changeIndex(QuizSession session, int next) {
    textDebounce?.cancel();
    if (session.questions[index].kind == 'short_answer') {
      saveText(session.questions[index]);
    }
    setState(() => index = next);
    syncText(session.questions[next]);
  }

  void updateAnswer(QuizQuestion question, SavedQuizAnswer answer) {
    setState(() {
      answers[question.id] = answer;
      error = null;
    });
    pendingSave = pendingSave
        .catchError((Object _) {})
        .then((_) async {
          await ref
              .read(quizRepositoryProvider)
              .save(widget.id, question.id, answer);
        })
        .catchError((Object _) {
          if (mounted) {
            setState(
              () => error = 'Answer could not be saved. Check your connection.',
            );
          }
        });
  }

  void saveText(QuizQuestion question) => updateAnswer(
    question,
    (answers[question.id] ?? const SavedQuizAnswer()).copyWith(
      responseText: textController.text,
    ),
  );

  Future<void> submit(QuizSession session, {bool confirm = true}) async {
    if (submitting) return;
    if (confirm) {
      final approved = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Submit quiz?'),
          content: Text(
            '${session.questions.where((q) => !(answers[q.id]?.isAnswered ?? false)).length} questions unanswered. You cannot change answers after submitting.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep working'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Submit'),
            ),
          ],
        ),
      );
      if (approved != true || !mounted) return;
    }
    setState(() {
      submitting = true;
      busy = true;
      error = null;
    });
    ticker?.cancel();
    textDebounce?.cancel();
    try {
      if (session.questions.isNotEmpty &&
          session.questions[index].kind == 'short_answer') {
        saveText(session.questions[index]);
      }
      await pendingSave;
      if (error != null) throw StateError(error!);
      await ref.read(quizRepositoryProvider).submit(widget.id);
      ref.invalidate(quizHistoryProvider);
      if (mounted) context.go('/quiz-results/${widget.id}');
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Couldn’t submit. Check your connection and try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          submitting = false;
          busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(quizSessionProvider(widget.id));
    return Scaffold(
      appBar: AppBar(title: const Text('Quiz in progress')),
      body: SafeArea(
        child: value.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(AppSpacing.page),
            child: LoadingRows(),
          ),
          error: (_, _) => ErrorState(
            message: 'Couldn’t load this attempt.',
            onRetry: () => ref.invalidate(quizSessionProvider(widget.id)),
          ),
          data: (session) {
            if (session.attempt.submittedAt != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) context.go('/quiz-results/${widget.id}');
              });
              return const Center(child: CircularProgressIndicator());
            }
            initialize(session);
            if (session.questions.isEmpty) {
              return const EmptyState(
                title: 'No questions',
                message: 'Ask your teacher to add questions to this quiz.',
              );
            }
            final question = session.questions[index];
            final answer = answers[question.id] ?? const SavedQuizAnswer();
            final left = remaining(session);
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.page),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Question ${index + 1} of ${session.questions.length}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    if (left != null)
                      Text(
                        '${left.inMinutes.remainder(60).toString().padLeft(2, '0')}:${left.inSeconds.remainder(60).toString().padLeft(2, '0')}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: (index + 1) / session.questions.length,
                ),
                const SizedBox(height: 28),
                Text(
                  question.prompt,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  '${question.marks} marks · ${switch (question.kind) {
                    'multiple_select' => 'Select all that apply',
                    'short_answer' => 'Write your answer',
                    _ => 'Choose one answer',
                  }}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 24),
                if (question.kind == 'short_answer')
                  TextField(
                    controller: textController,
                    minLines: 4,
                    maxLines: 8,
                    decoration: const InputDecoration(hintText: 'Your answer'),
                    onChanged: (_) {
                      textDebounce?.cancel();
                      textDebounce = Timer(
                        const Duration(milliseconds: 600),
                        () => saveText(question),
                      );
                    },
                  )
                else
                  for (final option in question.options)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: AppSurface(
                        padding: EdgeInsets.zero,
                        child: question.kind == 'multiple_select'
                            ? CheckboxListTile(
                                title: Text(option.label),
                                value: answer.optionIds.contains(option.id),
                                onChanged: (selected) {
                                  final ids = [...answer.optionIds];
                                  selected == true
                                      ? ids.add(option.id)
                                      : ids.remove(option.id);
                                  updateAnswer(
                                    question,
                                    answer.copyWith(optionIds: ids),
                                  );
                                },
                              )
                            : ListTile(
                                title: Text(option.label),
                                leading: Icon(
                                  answer.optionIds.contains(option.id)
                                      ? Icons.radio_button_checked
                                      : Icons.radio_button_unchecked,
                                ),
                                onTap: () => updateAnswer(
                                  question,
                                  answer.copyWith(optionIds: [option.id]),
                                ),
                              ),
                      ),
                    ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () => updateAnswer(
                    question,
                    answer.copyWith(flagged: !answer.flagged),
                  ),
                  icon: Icon(
                    answer.flagged
                        ? Icons.flag_rounded
                        : Icons.outlined_flag_rounded,
                  ),
                  label: Text(
                    answer.flagged ? 'Flagged for review' : 'Flag for review',
                  ),
                ),
                const SectionHeader(title: 'Questions'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var i = 0; i < session.questions.length; i++)
                      ActionChip(
                        avatar: Icon(
                          answers[session.questions[i].id]?.flagged == true
                              ? Icons.flag_rounded
                              : (answers[session.questions[i].id]?.isAnswered ==
                                        true
                                    ? Icons.check_rounded
                                    : Icons.circle_outlined),
                          size: 16,
                        ),
                        label: Text('${i + 1}'),
                        onPressed: () => changeIndex(session, i),
                      ),
                  ],
                ),
                if (error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 30),
                Row(
                  children: [
                    if (index > 0)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => changeIndex(session, index - 1),
                          child: const Text('Previous'),
                        ),
                      ),
                    if (index > 0) const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: index + 1 < session.questions.length
                            ? () => changeIndex(session, index + 1)
                            : null,
                        child: const Text('Next'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                PrimaryButton(
                  label: 'Submit quiz',
                  onPressed: () => submit(session),
                  busy: busy,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class QuizResultScreen extends ConsumerWidget {
  const QuizResultScreen({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Quiz result')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.page),
        children: [
          ref
              .watch(quizResultProvider(id))
              .when(
                loading: () => const LoadingRows(count: 3),
                error: (_, _) => ErrorState(
                  message: 'Result unavailable.',
                  onRetry: () => ref.invalidate(quizResultProvider(id)),
                ),
                data: (result) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${result.score} / ${result.total}',
                      style: Theme.of(context).textTheme.displaySmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      result.pending > 0
                          ? 'Some answers are waiting for teacher review.'
                          : 'Quiz completed',
                    ),
                    const SectionHeader(title: 'Summary'),
                    AppSurface(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${result.correct} correct · ${result.incorrect} incorrect',
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${result.unanswered} unanswered · ${result.pending} pending review',
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Time: ${result.timeSeconds ~/ 60} min ${result.timeSeconds % 60} sec',
                          ),
                        ],
                      ),
                    ),
                    if (result.feedback?.isNotEmpty ?? false) ...[
                      const SectionHeader(title: 'Feedback'),
                      Text(result.feedback!),
                    ],
                    if (result.review?.isNotEmpty ?? false) ...[
                      const SectionHeader(title: 'Review'),
                      for (final item in result.review!)
                        AppRow(
                          title: item['prompt']?.toString() ?? 'Question',
                          subtitle:
                              item['feedback']?.toString() ??
                              item['status']?.toString() ??
                              '',
                          icon: Icons.fact_check_outlined,
                        ),
                    ],
                    const SizedBox(height: 24),
                    PrimaryButton(
                      label: 'Back to quizzes',
                      onPressed: () => context.go('/quizzes'),
                    ),
                  ],
                ),
              ),
        ],
      ),
    ),
  );
}

class QuizHistoryScreen extends ConsumerWidget {
  const QuizHistoryScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Quiz history')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.page),
        children: [
          ref
              .watch(quizHistoryProvider)
              .when(
                loading: () => const LoadingRows(),
                error: (_, _) => ErrorState(
                  message: 'Couldn’t load your history.',
                  onRetry: () => ref.invalidate(quizHistoryProvider),
                ),
                data: (items) => items.isEmpty
                    ? const EmptyState(
                        title: 'No results yet',
                        message: 'Your completed quizzes will appear here.',
                      )
                    : Column(
                        children: [
                          for (final item in items)
                            AppRow(
                              title: item.title,
                              subtitle:
                                  'Submitted ${DateFormat.yMMMd().format(item.attempt.submittedAt!)}${item.attempt.score == null ? '' : ' · ${item.attempt.score} marks'}',
                              icon: Icons.history_edu_outlined,
                              onTap: () => context.push(
                                '/quiz-results/${item.attempt.id}',
                              ),
                            ),
                        ],
                      ),
              ),
        ],
      ),
    ),
  );
}
