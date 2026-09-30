import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/services/supabase_provider.dart';

class Quiz {
  const Quiz({
    required this.id,
    required this.title,
    required this.attemptLimit,
    required this.showAnswersAfterSubmission,
    this.description,
    this.instructions,
    this.durationMinutes,
    this.opensAt,
    this.closesAt,
  });
  final String id;
  final String title;
  final String? description;
  final String? instructions;
  final int? durationMinutes;
  final DateTime? opensAt;
  final DateTime? closesAt;
  final int attemptLimit;
  final bool showAnswersAfterSubmission;

  factory Quiz.fromJson(Map<String, dynamic> json) => Quiz(
    id: json['id'] as String,
    title: json['title'] as String,
    description: json['description'] as String?,
    instructions: json['instructions'] as String?,
    durationMinutes: json['duration_minutes'] as int?,
    opensAt: json['opens_at'] == null
        ? null
        : DateTime.parse(json['opens_at'] as String).toLocal(),
    closesAt: json['closes_at'] == null
        ? null
        : DateTime.parse(json['closes_at'] as String).toLocal(),
    attemptLimit: json['attempt_limit'] as int? ?? 1,
    showAnswersAfterSubmission:
        json['show_answers_after_submission'] as bool? ?? false,
  );
}

class QuizOption {
  const QuizOption({required this.id, required this.label});
  final String id;
  final String label;
  factory QuizOption.fromJson(Map<String, dynamic> json) =>
      QuizOption(id: json['id'] as String, label: json['label'] as String);
}

class QuizQuestion {
  const QuizQuestion({
    required this.id,
    required this.kind,
    required this.prompt,
    required this.marks,
    required this.options,
  });
  final String id;
  final String kind;
  final String prompt;
  final num marks;
  final List<QuizOption> options;

  factory QuizQuestion.fromJson(Map<String, dynamic> json) => QuizQuestion(
    id: json['id'] as String,
    kind: json['kind'] as String,
    prompt: json['prompt'] as String,
    marks: json['marks'] as num,
    options:
        (json['options'] as List<dynamic>?)
            ?.map((item) => QuizOption.fromJson(item as Map<String, dynamic>))
            .toList() ??
        [],
  );
}

class SavedQuizAnswer {
  const SavedQuizAnswer({
    this.optionIds = const [],
    this.responseText,
    this.flagged = false,
  });
  final List<String> optionIds;
  final String? responseText;
  final bool flagged;

  SavedQuizAnswer copyWith({
    List<String>? optionIds,
    String? responseText,
    bool? flagged,
  }) => SavedQuizAnswer(
    optionIds: optionIds ?? this.optionIds,
    responseText: responseText ?? this.responseText,
    flagged: flagged ?? this.flagged,
  );

  factory SavedQuizAnswer.fromJson(Map<String, dynamic> json) =>
      SavedQuizAnswer(
        optionIds: List<String>.from(json['option_ids'] as List? ?? const []),
        responseText: json['response_text'] as String?,
        flagged: json['flagged'] as bool? ?? false,
      );

  bool get isAnswered =>
      optionIds.isNotEmpty || (responseText?.trim().isNotEmpty ?? false);
}

class QuizAttempt {
  const QuizAttempt({
    required this.id,
    required this.quizId,
    required this.startedAt,
    this.submittedAt,
    this.score,
  });
  final String id;
  final String quizId;
  final DateTime startedAt;
  final DateTime? submittedAt;
  final num? score;

  factory QuizAttempt.fromJson(Map<String, dynamic> json) => QuizAttempt(
    id: json['id'] as String,
    quizId: json['quiz_id'] as String,
    startedAt: DateTime.parse(json['started_at'] as String).toLocal(),
    submittedAt: json['submitted_at'] == null
        ? null
        : DateTime.parse(json['submitted_at'] as String).toLocal(),
    score: json['score'] as num?,
  );
}

class QuizSession {
  const QuizSession({
    required this.quiz,
    required this.attempt,
    required this.questions,
    required this.answers,
  });
  final Quiz quiz;
  final QuizAttempt attempt;
  final List<QuizQuestion> questions;
  final Map<String, SavedQuizAnswer> answers;
}

class QuizResult {
  const QuizResult({
    required this.score,
    required this.total,
    required this.correct,
    required this.incorrect,
    required this.unanswered,
    required this.pending,
    required this.timeSeconds,
    this.feedback,
    this.review,
  });
  final num score;
  final num total;
  final int correct;
  final int incorrect;
  final int unanswered;
  final int pending;
  final int timeSeconds;
  final String? feedback;
  final List<Map<String, dynamic>>? review;

  factory QuizResult.fromJson(Map<String, dynamic> json) => QuizResult(
    score: json['score'] as num? ?? 0,
    total: json['total'] as num? ?? 0,
    correct: json['correct'] as int? ?? 0,
    incorrect: json['incorrect'] as int? ?? 0,
    unanswered: json['unanswered'] as int? ?? 0,
    pending: json['pending'] as int? ?? 0,
    timeSeconds: json['time_seconds'] as int? ?? 0,
    feedback: json['feedback'] as String?,
    review: (json['review'] as List<dynamic>?)?.cast<Map<String, dynamic>>(),
  );
}

class QuizHistoryItem {
  const QuizHistoryItem({required this.attempt, required this.title});
  final QuizAttempt attempt;
  final String title;
}

class QuizRepository {
  const QuizRepository(this.client);
  final SupabaseClient client;
  String get userId => client.auth.currentUser!.id;
  static const columns =
      'id,title,description,instructions,duration_minutes,opens_at,closes_at,attempt_limit,show_answers_after_submission';

  Future<List<Quiz>> list() async {
    final rows = await client
        .from('quizzes')
        .select(columns)
        .eq('is_published', true)
        .order('created_at', ascending: false)
        .limit(100);
    return rows.map(Quiz.fromJson).toList();
  }

  Future<Quiz> get(String id) async => Quiz.fromJson(
    await client.from('quizzes').select(columns).eq('id', id).single(),
  );

  Future<String> start(String id) async =>
      await client.rpc('start_quiz_attempt', params: {'target_quiz_id': id})
          as String;

  Future<QuizSession> session(String attemptId) async {
    final row = await client
        .from('quiz_attempts')
        .select('id,quiz_id,started_at,submitted_at,score')
        .eq('id', attemptId)
        .eq('student_id', userId)
        .single();
    final attempt = QuizAttempt.fromJson(row);
    final quiz = await get(attempt.quizId);
    final questionData =
        await client.rpc(
              'get_quiz_questions',
              params: {'target_attempt_id': attemptId},
            )
            as List<dynamic>;
    final savedData =
        await client.rpc(
              'get_saved_quiz_answers',
              params: {'target_attempt_id': attemptId},
            )
            as Map<String, dynamic>;
    return QuizSession(
      quiz: quiz,
      attempt: attempt,
      questions: questionData
          .map((item) => QuizQuestion.fromJson(item as Map<String, dynamic>))
          .toList(),
      answers: savedData.map(
        (key, value) => MapEntry(
          key,
          SavedQuizAnswer.fromJson(value as Map<String, dynamic>),
        ),
      ),
    );
  }

  Future<void> save(
    String attemptId,
    String questionId,
    SavedQuizAnswer answer,
  ) async {
    await client.rpc(
      'save_quiz_answer',
      params: {
        'target_attempt_id': attemptId,
        'target_question_id': questionId,
        'option_ids': answer.optionIds,
        'response_text': answer.responseText,
        'flagged': answer.flagged,
      },
    );
  }

  Future<void> submit(String attemptId) async => client.rpc(
    'submit_quiz_attempt',
    params: {'target_attempt_id': attemptId},
  );

  Future<QuizResult> result(String attemptId) async => QuizResult.fromJson(
    await client.rpc(
          'get_quiz_result',
          params: {'target_attempt_id': attemptId},
        )
        as Map<String, dynamic>,
  );

  Future<List<QuizHistoryItem>> history() async {
    final rows = await client
        .from('quiz_attempts')
        .select('id,quiz_id,started_at,submitted_at,score,quizzes(title)')
        .eq('student_id', userId)
        .not('submitted_at', 'is', null)
        .order('submitted_at', ascending: false)
        .limit(50);
    return rows
        .map(
          (row) => QuizHistoryItem(
            attempt: QuizAttempt.fromJson(row),
            title:
                (row['quizzes'] as Map<String, dynamic>?)?['title']
                    as String? ??
                'Quiz',
          ),
        )
        .toList();
  }
}

final quizRepositoryProvider = Provider<QuizRepository>(
  (ref) => QuizRepository(ref.watch(supabaseProvider)),
);
final quizzesProvider = FutureProvider<List<Quiz>>(
  (ref) => ref.watch(quizRepositoryProvider).list(),
);
final quizProvider = FutureProvider.family<Quiz, String>(
  (ref, id) => ref.watch(quizRepositoryProvider).get(id),
);
final quizSessionProvider = FutureProvider.family<QuizSession, String>(
  (ref, id) => ref.watch(quizRepositoryProvider).session(id),
);
final quizResultProvider = FutureProvider.family<QuizResult, String>(
  (ref, id) => ref.watch(quizRepositoryProvider).result(id),
);
final quizHistoryProvider = FutureProvider<List<QuizHistoryItem>>(
  (ref) => ref.watch(quizRepositoryProvider).history(),
);
