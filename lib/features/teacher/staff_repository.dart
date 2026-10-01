import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/services/supabase_provider.dart';

class StaffChoice {
  const StaffChoice(this.id, this.title);
  final String id;
  final String title;
  factory StaffChoice.fromJson(
    Map<String, dynamic> row, {
    String label = 'title',
  }) => StaffChoice(row['id'] as String, row[label] as String);
}

class StaffItem {
  const StaffItem({
    required this.id,
    required this.title,
    required this.published,
    this.subtitle,
  });
  final String id;
  final String title;
  final bool published;
  final String? subtitle;
}

class StaffRepository {
  const StaffRepository(this.client);
  final SupabaseClient client;
  String get userId => client.auth.currentUser!.id;

  Future<List<StaffChoice>> courses() async {
    final rows = await client
        .from('courses')
        .select('id,title')
        .order('sort_order')
        .limit(100);
    return rows.map(StaffChoice.fromJson).toList();
  }

  Future<List<StaffChoice>> topics(String courseId) async {
    final rows = await client
        .from('topics')
        .select('id,title')
        .eq('course_id', courseId)
        .order('sort_order')
        .limit(100);
    return rows.map(StaffChoice.fromJson).toList();
  }

  Future<List<StaffChoice>> batches() async {
    final rows = await client
        .from('batches')
        .select('id,name')
        .order('name')
        .limit(100);
    return rows.map((row) => StaffChoice.fromJson(row, label: 'name')).toList();
  }

  Future<List<StaffChoice>> students() async {
    final rows = await client
        .from('profiles')
        .select('id,full_name')
        .eq('role', 'student')
        .order('full_name')
        .limit(200);
    return rows
        .map((row) => StaffChoice.fromJson(row, label: 'full_name'))
        .toList();
  }

  Future<List<StaffItem>> items(String section) async {
    final titleColumn = section == 'batches' ? 'name' : 'title';
    final hasPublication = const [
      'resources',
      'announcements',
      'quizzes',
      'assignments',
    ].contains(section);
    final rows = await client
        .from(section)
        .select('id,$titleColumn${hasPublication ? ',is_published' : ''}')
        .limit(100);
    return rows
        .map(
          (row) => StaffItem(
            id: row['id'] as String,
            title: row[titleColumn] as String,
            published: hasPublication ? row['is_published'] as bool : true,
          ),
        )
        .toList();
  }

  Future<void> createCourse(String title) async =>
      client.from('courses').insert({'title': title.trim()});

  Future<void> createTopic(String courseId, String title) async => client
      .from('topics')
      .insert({'course_id': courseId, 'title': title.trim()});

  Future<void> createBatch(String name, String description) async =>
      client.from('batches').insert({
        'name': name.trim(),
        'description': description.trim().isEmpty ? null : description.trim(),
      });

  Future<void> addStudent(String batchId, String studentId) async =>
      client.from('batch_members').upsert({
        'batch_id': batchId,
        'student_id': studentId,
      }, onConflict: 'batch_id,student_id');

  Future<List<String>> batchStudentIds(String batchId) async {
    final rows = await client
        .from('batch_members')
        .select('student_id')
        .eq('batch_id', batchId);
    return rows.map((row) => row['student_id'] as String).toList();
  }

  Future<void> removeStudent(String batchId, String studentId) async => client
      .from('batch_members')
      .delete()
      .eq('batch_id', batchId)
      .eq('student_id', studentId);

  Future<void> createAnnouncement({
    required String title,
    required String content,
    required List<String> batchIds,
    required bool pinned,
    required int priority,
  }) async {
    await client.from('announcements').insert({
      'title': title.trim(),
      'content': content.trim(),
      'batch_ids': batchIds,
      'priority': priority,
      'is_pinned': pinned,
      'is_published': true,
      'author_id': userId,
    });
  }

  Future<void> createSchedule({
    required String title,
    required String subtitle,
    required DateTime startsAt,
    required DateTime endsAt,
    required String kind,
    required String location,
    required List<String> batchIds,
  }) async {
    await client.from('schedule_events').insert({
      'title': title.trim(),
      'subtitle': subtitle.trim().isEmpty ? null : subtitle.trim(),
      'starts_at': startsAt.toUtc().toIso8601String(),
      'ends_at': endsAt.toUtc().toIso8601String(),
      'kind': kind,
      'location': location.trim().isEmpty ? null : location.trim(),
      'batch_ids': batchIds,
      'created_by': userId,
    });
  }

  Future<void> createAssignment({
    required String title,
    required String instructions,
    required DateTime dueAt,
    required List<String> batchIds,
    num? maximumMarks,
  }) async {
    await client.from('assignments').insert({
      'title': title.trim(),
      'instructions': instructions.trim(),
      'due_at': dueAt.toUtc().toIso8601String(),
      'batch_ids': batchIds,
      'maximum_marks': maximumMarks,
      'is_published': true,
      'created_by': userId,
    });
  }

  Future<void> createLinkResource({
    required String title,
    required String description,
    required String courseId,
    String? topicId,
    required String kind,
    required String url,
    required List<String> batchIds,
  }) async {
    await client.from('resources').insert({
      'title': title.trim(),
      'description': description.trim().isEmpty ? null : description.trim(),
      'course_id': courseId,
      'topic_id': topicId,
      'kind': kind,
      'external_url': url.trim(),
      'batch_ids': batchIds,
      'is_published': true,
      'created_by': userId,
    });
  }

  Future<void> createFileResource({
    required String title,
    required String description,
    required String courseId,
    String? topicId,
    required String kind,
    required PlatformFile file,
    required List<String> batchIds,
  }) async {
    final safeName = file.name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final path = '$userId/${DateTime.now().microsecondsSinceEpoch}_$safeName';
    final row = await client
        .from('resources')
        .insert({
          'title': title.trim(),
          'description': description.trim().isEmpty ? null : description.trim(),
          'course_id': courseId,
          'topic_id': topicId,
          'kind': kind,
          'storage_path': path,
          'batch_ids': batchIds,
          'is_published': false,
          'created_by': userId,
        })
        .select('id')
        .single();
    final resourceId = row['id'] as String;
    try {
      if (file.path == null) {
        throw StateError('Could not read the selected file.');
      }
      await client.storage.from('resources').upload(path, File(file.path!));
      await client
          .from('resources')
          .update({'is_published': true})
          .eq('id', resourceId);
    } catch (_) {
      await client.from('resources').delete().eq('id', resourceId);
      rethrow;
    }
  }

  Future<String> createQuiz({
    required String title,
    required String description,
    required List<String> batchIds,
    int? durationMinutes,
  }) async {
    final row = await client
        .from('quizzes')
        .insert({
          'title': title.trim(),
          'description': description.trim().isEmpty ? null : description.trim(),
          'batch_ids': batchIds,
          'duration_minutes': durationMinutes,
          'is_published': false,
          'created_by': userId,
        })
        .select('id')
        .single();
    return row['id'] as String;
  }

  Future<List<Map<String, dynamic>>> quizQuestions(String quizId) async =>
      await client
          .from('quiz_questions')
          .select('id,prompt,kind,marks,quiz_options(id,label,is_correct)')
          .eq('quiz_id', quizId)
          .order('sort_order');

  Future<void> addQuizQuestion({
    required String quizId,
    required String prompt,
    required String kind,
    required num marks,
    required List<String> options,
    required Set<int> correctIndexes,
    String? answerText,
  }) async {
    final existing = await client
        .from('quiz_questions')
        .select('id')
        .eq('quiz_id', quizId);
    final row = await client
        .from('quiz_questions')
        .insert({
          'quiz_id': quizId,
          'prompt': prompt.trim(),
          'kind': kind,
          'marks': marks,
          'answer_text': answerText,
          'sort_order': existing.length,
        })
        .select('id')
        .single();
    if (options.isNotEmpty) {
      await client.from('quiz_options').insert([
        for (var i = 0; i < options.length; i++)
          {
            'question_id': row['id'],
            'label': options[i].trim(),
            'is_correct': correctIndexes.contains(i),
            'sort_order': i,
          },
      ]);
    }
  }

  Future<void> publishQuiz(String quizId) async =>
      client.from('quizzes').update({'is_published': true}).eq('id', quizId);
}

final staffRepositoryProvider = Provider<StaffRepository>(
  (ref) => StaffRepository(ref.watch(supabaseProvider)),
);
final staffCoursesProvider = FutureProvider<List<StaffChoice>>(
  (ref) => ref.watch(staffRepositoryProvider).courses(),
);
final staffBatchesProvider = FutureProvider<List<StaffChoice>>(
  (ref) => ref.watch(staffRepositoryProvider).batches(),
);
final staffStudentsProvider = FutureProvider<List<StaffChoice>>(
  (ref) => ref.watch(staffRepositoryProvider).students(),
);
final staffItemsProvider = FutureProvider.family<List<StaffItem>, String>(
  (ref, section) => ref.watch(staffRepositoryProvider).items(section),
);
final staffTopicsProvider = FutureProvider.family<List<StaffChoice>, String>(
  (ref, courseId) => ref.watch(staffRepositoryProvider).topics(courseId),
);
final staffQuizQuestionsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
      (ref, quizId) => ref.watch(staffRepositoryProvider).quizQuestions(quizId),
    );
final staffBatchStudentIdsProvider =
    FutureProvider.family<List<String>, String>(
      (ref, batchId) =>
          ref.watch(staffRepositoryProvider).batchStudentIds(batchId),
    );
