import 'package:class_lms/features/teacher/report_card_repository.dart';
import 'package:class_lms/features/teacher/report_card_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'report uses latest quiz result, due work, and distinct resource opens',
    () {
      final now = DateTime.utc(2026, 10, 1);
      final report = calculateReport(
        student: {'full_name': 'A Student', 'email': 'a@example.com'},
        batches: {'batch-1'},
        quizzes: [
          {
            'id': 'q1',
            'title': 'Grammar',
            'batch_ids': <String>[],
            'is_published': true,
          },
          {
            'id': 'q2',
            'title': 'Reading',
            'batch_ids': <String>['other'],
            'is_published': true,
          },
        ],
        questions: [
          {'quiz_id': 'q1', 'marks': 10},
          {'quiz_id': 'q2', 'marks': 10},
        ],
        attempts: [
          {'quiz_id': 'q1', 'submitted_at': '2026-09-10T10:00:00Z', 'score': 4},
          {'quiz_id': 'q1', 'submitted_at': '2026-09-20T10:00:00Z', 'score': 8},
        ],
        assignments: [
          {
            'id': 'a1',
            'title': 'Essay',
            'due_at': '2026-09-25T10:00:00Z',
            'maximum_marks': 20,
            'batch_ids': <String>['batch-1'],
            'is_published': true,
          },
          {
            'id': 'a2',
            'title': 'Other batch',
            'due_at': '2026-09-25T10:00:00Z',
            'maximum_marks': 20,
            'batch_ids': <String>['other'],
            'is_published': true,
          },
        ],
        submissions: [
          {
            'assignment_id': 'a1',
            'submitted_at': '2026-09-24T10:00:00Z',
            'marks': 16,
            'status': 'reviewed',
          },
        ],
        resources: [
          {'id': 'r1', 'batch_ids': <String>[], 'is_published': true},
          {
            'id': 'r2',
            'batch_ids': <String>['other'],
            'is_published': true,
          },
        ],
        progress: [
          {'resource_id': 'r1', 'last_opened_at': '2026-09-28T10:00:00Z'},
          {'resource_id': 'r2', 'last_opened_at': '2026-09-28T10:00:00Z'},
        ],
        days: 30,
        now: now,
      );
      expect(report.quizEntries.length, 1);
      expect(report.quizAverage, 80);
      expect(report.assignedAssignments, 1);
      expect(report.submittedAssignments, 1);
      expect(report.onTimeAssignments, 1);
      expect(report.resourcesOpened, 1);
    },
  );

  test('empty evidence stays unscored', () {
    final report = calculateReport(
      student: {'full_name': 'New Student'},
      batches: {},
      quizzes: [],
      questions: [],
      attempts: [],
      assignments: [],
      submissions: [],
      resources: [],
      progress: [],
      days: 90,
      now: DateTime.utc(2026, 10, 1),
    );
    expect(report.quizAverage, isNull);
    expect(report.submissionRate, isNull);
    expect(report.insights.first, contains('cannot be assessed'));
  });

  test('report exports as a PDF', () async {
    final report = calculateReport(
      student: {'full_name': 'A Student', 'email': 'a@example.com'},
      batches: {},
      quizzes: [],
      questions: [],
      attempts: [],
      assignments: [],
      submissions: [],
      resources: [],
      progress: [],
      days: 90,
      now: DateTime.utc(2026, 10, 1),
    );
    final bytes = await buildReportPdf(report);
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(bytes.length, greaterThan(1000));
  });
}
