import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/services/supabase_provider.dart';

class Announcement {
  const Announcement({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.priority,
    required this.isPinned,
    required this.authorId,
    required this.attachmentPaths,
    required this.isRead,
  });
  final String id;
  final String title;
  final String content;
  final DateTime createdAt;
  final int priority;
  final bool isPinned;
  final String authorId;
  final List<String> attachmentPaths;
  final bool isRead;

  factory Announcement.fromJson(
    Map<String, dynamic> json, {
    bool isRead = false,
  }) => Announcement(
    id: json['id'] as String,
    title: json['title'] as String,
    content: json['content'] as String,
    createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    priority: json['priority'] as int? ?? 0,
    isPinned: json['is_pinned'] as bool? ?? false,
    authorId: json['author_id'] as String,
    attachmentPaths: List<String>.from(
      json['attachment_paths'] as List? ?? const [],
    ),
    isRead: isRead,
  );
}

class AnnouncementRepository {
  const AnnouncementRepository(this.client);
  final SupabaseClient client;

  Future<List<Announcement>> list({int limit = 40}) async {
    final userId = client.auth.currentUser!.id;
    final rows = await client
        .from('announcements')
        .select(
          'id,title,content,created_at,priority,is_pinned,author_id,attachment_paths',
        )
        .eq('is_published', true)
        .order('is_pinned', ascending: false)
        .order('created_at', ascending: false)
        .limit(limit);
    if (rows.isEmpty) return [];
    final ids = rows.map((row) => row['id'] as String).toList();
    final reads = await client
        .from('announcement_reads')
        .select('announcement_id')
        .eq('student_id', userId)
        .inFilter('announcement_id', ids);
    final readIds = reads
        .map((row) => row['announcement_id'] as String)
        .toSet();
    return rows
        .map(
          (row) =>
              Announcement.fromJson(row, isRead: readIds.contains(row['id'])),
        )
        .toList();
  }

  Future<Announcement> get(String id) async {
    final row = await client
        .from('announcements')
        .select(
          'id,title,content,created_at,priority,is_pinned,author_id,attachment_paths',
        )
        .eq('id', id)
        .single();
    return Announcement.fromJson(row);
  }

  Future<void> markRead(String id) async {
    await client.from('announcement_reads').upsert({
      'announcement_id': id,
      'student_id': client.auth.currentUser!.id,
    }, onConflict: 'announcement_id,student_id');
  }
}

final announcementRepositoryProvider = Provider<AnnouncementRepository>(
  (ref) => AnnouncementRepository(ref.watch(supabaseProvider)),
);
final announcementsProvider = FutureProvider<List<Announcement>>(
  (ref) => ref.watch(announcementRepositoryProvider).list(),
);
final announcementProvider = FutureProvider.family<Announcement, String>(
  (ref, id) => ref.watch(announcementRepositoryProvider).get(id),
);
