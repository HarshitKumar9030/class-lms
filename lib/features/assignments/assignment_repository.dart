import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/services/supabase_provider.dart';

class Assignment {
  const Assignment({
    required this.id,
    required this.title,
    required this.instructions,
    required this.dueAt,
    required this.attachmentPaths,
    this.maximumMarks,
    this.submission,
  });
  final String id;
  final String title;
  final String instructions;
  final DateTime dueAt;
  final List<String> attachmentPaths;
  final num? maximumMarks;
  final AssignmentSubmission? submission;

  factory Assignment.fromJson(
    Map<String, dynamic> json,
    AssignmentSubmission? submission,
  ) => Assignment(
    id: json['id'] as String,
    title: json['title'] as String,
    instructions: json['instructions'] as String,
    dueAt: DateTime.parse(json['due_at'] as String).toLocal(),
    attachmentPaths: List<String>.from(
      json['attachment_paths'] as List? ?? const [],
    ),
    maximumMarks: json['maximum_marks'] as num?,
    submission: submission,
  );
}

class AssignmentSubmission {
  const AssignmentSubmission({
    required this.status,
    required this.submittedAt,
    required this.attachmentPaths,
    this.responseText,
    this.marks,
    this.feedback,
  });
  final String status;
  final DateTime submittedAt;
  final List<String> attachmentPaths;
  final String? responseText;
  final num? marks;
  final String? feedback;

  factory AssignmentSubmission.fromJson(Map<String, dynamic> json) =>
      AssignmentSubmission(
        status: json['status'] as String,
        submittedAt: DateTime.parse(json['submitted_at'] as String).toLocal(),
        attachmentPaths: List<String>.from(
          json['attachment_paths'] as List? ?? const [],
        ),
        responseText: json['response_text'] as String?,
        marks: json['marks'] as num?,
        feedback: json['feedback'] as String?,
      );
}

class AssignmentRepository {
  const AssignmentRepository(this.client);
  final SupabaseClient client;
  String get userId => client.auth.currentUser!.id;

  Future<List<Assignment>> list() async {
    final rows = await client
        .from('assignments')
        .select('id,title,instructions,due_at,attachment_paths,maximum_marks')
        .eq('is_published', true)
        .order('due_at')
        .limit(100);
    if (rows.isEmpty) return [];
    final submissions = await client
        .from('assignment_submissions')
        .select(
          'assignment_id,status,submitted_at,attachment_paths,response_text,marks,feedback',
        )
        .eq('student_id', userId)
        .inFilter(
          'assignment_id',
          rows.map((row) => row['id'] as String).toList(),
        );
    final byAssignment = {
      for (final row in submissions)
        row['assignment_id'] as String: AssignmentSubmission.fromJson(row),
    };
    return rows
        .map((row) => Assignment.fromJson(row, byAssignment[row['id']]))
        .toList();
  }

  Future<Assignment> get(String id) async {
    final row = await client
        .from('assignments')
        .select('id,title,instructions,due_at,attachment_paths,maximum_marks')
        .eq('id', id)
        .single();
    final submission = await client
        .from('assignment_submissions')
        .select(
          'status,submitted_at,attachment_paths,response_text,marks,feedback',
        )
        .eq('assignment_id', id)
        .eq('student_id', userId)
        .maybeSingle();
    return Assignment.fromJson(
      row,
      submission == null ? null : AssignmentSubmission.fromJson(submission),
    );
  }

  Future<void> submit(
    Assignment assignment,
    String response,
    List<PlatformFile> files,
  ) async {
    if (assignment.submission != null) throw StateError('Already submitted.');
    if (response.trim().isEmpty && files.isEmpty) {
      throw StateError('Add an answer or a file.');
    }
    final uploaded = <String>[];
    try {
      for (final file in files) {
        if (file.path == null) throw StateError('Couldn’t read ${file.name}.');
        final safeName = file.name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
        final path =
            '$userId/${assignment.id}/${DateTime.now().microsecondsSinceEpoch}_$safeName';
        await client.storage
            .from('submissions')
            .upload(
              path,
              File(file.path!),
              fileOptions: const FileOptions(upsert: false),
            );
        uploaded.add(path);
      }
      await client.from('assignment_submissions').insert({
        'assignment_id': assignment.id,
        'student_id': userId,
        'response_text': response.trim().isEmpty ? null : response.trim(),
        'attachment_paths': uploaded,
      });
    } catch (_) {
      if (uploaded.isNotEmpty) {
        try {
          await client.storage.from('submissions').remove(uploaded);
        } catch (_) {
          /* Cleanup is best effort. */
        }
      }
      rethrow;
    }
  }
}

final assignmentRepositoryProvider = Provider<AssignmentRepository>(
  (ref) => AssignmentRepository(ref.watch(supabaseProvider)),
);
final assignmentsProvider = FutureProvider<List<Assignment>>(
  (ref) => ref.watch(assignmentRepositoryProvider).list(),
);
final assignmentProvider = FutureProvider.family<Assignment, String>(
  (ref, id) => ref.watch(assignmentRepositoryProvider).get(id),
);
