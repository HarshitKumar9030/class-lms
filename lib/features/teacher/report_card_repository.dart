import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/services/supabase_provider.dart';

typedef ReportRequest = (String studentId, int days);

class ReportEntry {
  const ReportEntry(this.title, this.detail, this.date, this.percent);
  final String title;
  final String detail;
  final DateTime date;
  final double? percent;
}

class ReportCard {
  const ReportCard({
    required this.studentName,
    required this.studentEmail,
    required this.generatedAt,
    required this.periodDays,
    required this.quizEntries,
    required this.assignmentEntries,
    required this.quizAverage,
    required this.quizTrend,
    required this.assignedAssignments,
    required this.submittedAssignments,
    required this.onTimeAssignments,
    required this.resourcesOpened,
    required this.insights,
  });
  final String studentName;
  final String studentEmail;
  final DateTime generatedAt;
  final int periodDays;
  final List<ReportEntry> quizEntries;
  final List<ReportEntry> assignmentEntries;
  final double? quizAverage;
  final double? quizTrend;
  final int assignedAssignments;
  final int submittedAssignments;
  final int onTimeAssignments;
  final int resourcesOpened;
  final List<String> insights;
  double? get submissionRate => assignedAssignments == 0
      ? null
      : 100 * submittedAssignments / assignedAssignments;
  double? get onTimeRate => submittedAssignments == 0
      ? null
      : 100 * onTimeAssignments / submittedAssignments;
}

class ReportCardRepository {
  const ReportCardRepository(this.client);
  final SupabaseClient client;

  Future<ReportCard> generate(String studentId, int days) async {
    final student = await client
        .from('profiles')
        .select('full_name,email,role')
        .eq('id', studentId)
        .single();
    if (student['role'] != 'student') {
      throw StateError('Report cards are for students.');
    }
    final memberRows = await client
        .from('batch_members')
        .select('batch_id')
        .eq('student_id', studentId);
    final batches = memberRows.map((row) => row['batch_id'] as String).toSet();
    final quizzes = await client
        .from('quizzes')
        .select('id,title,batch_ids,is_published')
        .limit(1000);
    final questions = await client
        .from('quiz_questions')
        .select('quiz_id,marks')
        .limit(2000);
    final attempts = await client
        .from('quiz_attempts')
        .select('id,quiz_id,submitted_at,score')
        .eq('student_id', studentId)
        .not('submitted_at', 'is', null)
        .order('submitted_at')
        .limit(1000);
    final assignments = await client
        .from('assignments')
        .select('id,title,due_at,maximum_marks,batch_ids,is_published')
        .limit(1000);
    final submissions = await client
        .from('assignment_submissions')
        .select('assignment_id,submitted_at,marks,status')
        .eq('student_id', studentId)
        .limit(1000);
    final progress = await client
        .from('resource_progress')
        .select('resource_id,last_opened_at')
        .eq('student_id', studentId)
        .limit(1000);
    final resources = await client
        .from('resources')
        .select('id,batch_ids,is_published')
        .limit(1000);
    return calculateReport(
      student: student,
      batches: batches,
      quizzes: quizzes,
      questions: questions,
      attempts: attempts,
      assignments: assignments,
      submissions: submissions,
      progress: progress,
      resources: resources,
      days: days,
      now: DateTime.now(),
    );
  }
}

bool _forStudent(Map<String, dynamic> row, Set<String> batches) {
  if (row['is_published'] != true || batches.isEmpty) return false;
  final target = List<String>.from(row['batch_ids'] as List? ?? const []);
  return target.isEmpty || target.any(batches.contains);
}

ReportCard calculateReport({
  required Map<String, dynamic> student,
  required Set<String> batches,
  required List<Map<String, dynamic>> quizzes,
  required List<Map<String, dynamic>> questions,
  required List<Map<String, dynamic>> attempts,
  required List<Map<String, dynamic>> assignments,
  required List<Map<String, dynamic>> submissions,
  required List<Map<String, dynamic>> progress,
  required List<Map<String, dynamic>> resources,
  required int days,
  required DateTime now,
}) {
  final cutoff = days == 0 ? null : now.subtract(Duration(days: days));
  bool inPeriod(DateTime date) => cutoff == null || !date.isBefore(cutoff);
  final quizById = {for (final quiz in quizzes) quiz['id'] as String: quiz};
  final maxMarks = <String, double>{};
  for (final question in questions) {
    final id = question['quiz_id'] as String;
    maxMarks[id] = (maxMarks[id] ?? 0) + (question['marks'] as num).toDouble();
  }
  final latestAttempts = <String, Map<String, dynamic>>{};
  for (final attempt in attempts) {
    final date = DateTime.parse(attempt['submitted_at'] as String).toLocal();
    if (inPeriod(date)) latestAttempts[attempt['quiz_id'] as String] = attempt;
  }
  final quizEntries = <ReportEntry>[];
  for (final entry in latestAttempts.entries) {
    final quiz = quizById[entry.key];
    if (quiz == null) continue;
    final score = (entry.value['score'] as num?)?.toDouble();
    final total = maxMarks[entry.key] ?? 0;
    final percent = score == null || total <= 0
        ? null
        : (100 * score / total).clamp(0, 100).toDouble();
    quizEntries.add(
      ReportEntry(
        quiz['title'] as String,
        score == null
            ? 'Awaiting review'
            : '${score.toStringAsFixed(1)} / ${total.toStringAsFixed(1)} marks',
        DateTime.parse(entry.value['submitted_at'] as String).toLocal(),
        percent,
      ),
    );
  }
  quizEntries.sort((a, b) => a.date.compareTo(b.date));
  final scored = quizEntries.where((entry) => entry.percent != null).toList();
  final average = scored.isEmpty
      ? null
      : scored.map((entry) => entry.percent!).reduce((a, b) => a + b) /
            scored.length;
  double? trend;
  if (scored.length >= 4) {
    final split = scored.length ~/ 2;
    final older =
        scored
            .take(split)
            .map((entry) => entry.percent!)
            .reduce((a, b) => a + b) /
        split;
    final newer =
        scored
            .skip(split)
            .map((entry) => entry.percent!)
            .reduce((a, b) => a + b) /
        (scored.length - split);
    trend = newer - older;
  }

  final submissionByAssignment = {
    for (final row in submissions) row['assignment_id'] as String: row,
  };
  final assignmentEntries = <ReportEntry>[];
  var assigned = 0;
  var submitted = 0;
  var onTime = 0;
  for (final task in assignments) {
    if (!_forStudent(task, batches)) continue;
    final due = DateTime.parse(task['due_at'] as String).toLocal();
    if (due.isAfter(now) || !inPeriod(due)) continue;
    assigned++;
    final response = submissionByAssignment[task['id']];
    if (response == null) {
      assignmentEntries.add(
        ReportEntry(task['title'] as String, 'Not submitted', due, null),
      );
      continue;
    }
    submitted++;
    final submittedAt = DateTime.parse(
      response['submitted_at'] as String,
    ).toLocal();
    final timely = !submittedAt.isAfter(due);
    if (timely) onTime++;
    final marks = (response['marks'] as num?)?.toDouble();
    final maximum = (task['maximum_marks'] as num?)?.toDouble();
    final percent = marks == null || maximum == null || maximum <= 0
        ? null
        : (100 * marks / maximum).clamp(0, 100).toDouble();
    assignmentEntries.add(
      ReportEntry(
        task['title'] as String,
        '${timely ? 'On time' : 'Late'}${marks == null ? ' · Awaiting grade' : ' · ${marks.toStringAsFixed(1)} marks'}',
        due,
        percent,
      ),
    );
  }
  assignmentEntries.sort((a, b) => b.date.compareTo(a.date));

  final availableResourceIds = resources
      .where((row) => _forStudent(row, batches))
      .map((row) => row['id'] as String)
      .toSet();
  final opened = progress
      .where(
        (row) =>
            availableResourceIds.contains(row['resource_id']) &&
            inPeriod(DateTime.parse(row['last_opened_at'] as String).toLocal()),
      )
      .length;

  final insights = <String>[];
  if (average == null) {
    insights.add(
      'No scored quizzes in this period. Quiz performance cannot be assessed yet.',
    );
  } else {
    insights.add(
      'Average on ${scored.length} scored quiz${scored.length == 1 ? '' : 'zes'}: ${average.toStringAsFixed(0)}%.',
    );
    if (scored.length >= 2) {
      final best = scored.reduce((a, b) => a.percent! >= b.percent! ? a : b);
      final focus = scored.reduce((a, b) => a.percent! <= b.percent! ? a : b);
      insights.add(
        'Strongest quiz: ${best.title} (${best.percent!.toStringAsFixed(0)}%). Review ${focus.title} (${focus.percent!.toStringAsFixed(0)}%) next.',
      );
    }
    if (trend != null) {
      insights.add(
        trend >= 5
            ? 'Recent quiz scores improved by ${trend.toStringAsFixed(0)} percentage points.'
            : trend <= -5
            ? 'Recent quiz scores fell by ${trend.abs().toStringAsFixed(0)} percentage points; revisit earlier topics.'
            : 'Quiz scores have been broadly steady across the period.',
      );
    }
  }
  if (assigned == 0) {
    insights.add('No assignments were due in this period.');
  } else {
    final outstanding = math.max(0, assigned - submitted);
    insights.add(
      '$submitted of $assigned due assignments submitted${outstanding > 0 ? '; $outstanding remain outstanding' : ''}.',
    );
    if (submitted > 0) {
      insights.add('$onTime of $submitted submissions arrived on time.');
    }
  }
  insights.add(
    '$opened distinct assigned resource${opened == 1 ? '' : 's'} opened during this period. Opens indicate activity, not completion.',
  );
  return ReportCard(
    studentName: student['full_name'] as String? ?? '',
    studentEmail: student['email'] as String? ?? '',
    generatedAt: now,
    periodDays: days,
    quizEntries: quizEntries,
    assignmentEntries: assignmentEntries,
    quizAverage: average,
    quizTrend: trend,
    assignedAssignments: assigned,
    submittedAssignments: submitted,
    onTimeAssignments: onTime,
    resourcesOpened: opened,
    insights: insights,
  );
}

final reportCardRepositoryProvider = Provider<ReportCardRepository>(
  (ref) => ReportCardRepository(ref.watch(supabaseProvider)),
);
final reportCardProvider = FutureProvider.family<ReportCard, ReportRequest>(
  (ref, request) =>
      ref.watch(reportCardRepositoryProvider).generate(request.$1, request.$2),
);
