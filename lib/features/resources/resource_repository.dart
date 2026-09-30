import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/services/supabase_provider.dart';

enum ResourceKind {
  pdf,
  document,
  image,
  audio,
  videoLink,
  webLink,
  worksheet,
  notes,
  presentation,
  vocabulary,
  grammar,
  literature,
}

ResourceKind _kindFromDb(String value) => ResourceKind.values.firstWhere(
  (kind) =>
      kind.name.replaceAllMapped(
        RegExp(r'[A-Z]'),
        (match) => '_${match.group(0)!.toLowerCase()}',
      ) ==
      value,
  orElse: () => ResourceKind.document,
);

class LearningResource {
  const LearningResource({
    required this.id,
    required this.title,
    required this.kind,
    required this.courseTitle,
    required this.createdAt,
    required this.allowDownload,
    this.description,
    this.topicTitle,
    this.storagePath,
    this.externalUrl,
    this.isBookmarked = false,
    this.lastPage,
  });
  final String id;
  final String title;
  final String? description;
  final ResourceKind kind;
  final String courseTitle;
  final String? topicTitle;
  final String? storagePath;
  final String? externalUrl;
  final DateTime createdAt;
  final bool allowDownload;
  final bool isBookmarked;
  final int? lastPage;

  factory LearningResource.fromJson(
    Map<String, dynamic> json, {
    bool bookmarked = false,
    int? lastPage,
  }) => LearningResource(
    id: json['id'] as String,
    title: json['title'] as String,
    description: json['description'] as String?,
    kind: _kindFromDb(json['kind'] as String),
    courseTitle:
        (json['courses'] as Map<String, dynamic>?)?['title'] as String? ??
        'Learning',
    topicTitle: (json['topics'] as Map<String, dynamic>?)?['title'] as String?,
    storagePath: json['storage_path'] as String?,
    externalUrl: json['external_url'] as String?,
    createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    allowDownload: json['allow_download'] as bool? ?? true,
    isBookmarked: bookmarked,
    lastPage: lastPage,
  );
}

const resourceColumns =
    'id,title,description,kind,storage_path,external_url,created_at,allow_download,courses(title),topics(title)';

class ResourceRepository {
  const ResourceRepository(this.client);
  final SupabaseClient client;
  String get userId => client.auth.currentUser!.id;

  Future<List<LearningResource>> list({String query = ''}) async {
    var request = client
        .from('resources')
        .select(resourceColumns)
        .eq('is_published', true);
    if (query.trim().isNotEmpty) {
      request = request.ilike('title', '%${query.trim()}%');
    }
    final rows = await request.order('created_at', ascending: false).limit(100);
    if (rows.isEmpty) return [];
    final ids = rows.map((row) => row['id'] as String).toList();
    final bookmarks = await client
        .from('resource_bookmarks')
        .select('resource_id')
        .eq('student_id', userId)
        .inFilter('resource_id', ids);
    final marked = bookmarks.map((row) => row['resource_id'] as String).toSet();
    return rows
        .map(
          (row) => LearningResource.fromJson(
            row,
            bookmarked: marked.contains(row['id']),
          ),
        )
        .toList();
  }

  Future<LearningResource> get(String id) async {
    final row = await client
        .from('resources')
        .select(resourceColumns)
        .eq('id', id)
        .single();
    final progress = await client
        .from('resource_progress')
        .select('page_number')
        .eq('resource_id', id)
        .eq('student_id', userId)
        .maybeSingle();
    final bookmark = await client
        .from('resource_bookmarks')
        .select('resource_id')
        .eq('resource_id', id)
        .eq('student_id', userId)
        .maybeSingle();
    return LearningResource.fromJson(
      row,
      bookmarked: bookmark != null,
      lastPage: progress?['page_number'] as int?,
    );
  }

  Future<void> setBookmark(String id, bool value) async {
    if (value) {
      await client.from('resource_bookmarks').upsert({
        'resource_id': id,
        'student_id': userId,
      }, onConflict: 'resource_id,student_id');
    } else {
      await client
          .from('resource_bookmarks')
          .delete()
          .eq('resource_id', id)
          .eq('student_id', userId);
    }
  }

  Future<void> savePage(String id, int page) async =>
      client.from('resource_progress').upsert({
        'resource_id': id,
        'student_id': userId,
        'page_number': page,
        'last_opened_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'resource_id,student_id');

  Future<String> signedUrl(LearningResource resource) async {
    if (resource.storagePath == null) {
      throw StateError('This resource has no file.');
    }
    return client.storage
        .from('resources')
        .createSignedUrl(resource.storagePath!, 3600);
  }

  Future<File> _downloadFile(LearningResource resource) async {
    final root = await getApplicationDocumentsDirectory();
    final directory = Directory(
      '${root.path}${Platform.pathSeparator}resources',
    );
    if (!await directory.exists()) await directory.create(recursive: true);
    final sourceName = resource.storagePath!.split('/').last;
    final dot = sourceName.lastIndexOf('.');
    final extension = dot < 0
        ? ''
        : sourceName.substring(dot).replaceAll(RegExp(r'[^.a-zA-Z0-9]'), '');
    return File(
      '${directory.path}${Platform.pathSeparator}${resource.id}$extension',
    );
  }

  Future<File?> localFile(LearningResource resource) async {
    if (resource.storagePath == null) return null;
    final file = await _downloadFile(resource);
    return await file.exists() ? file : null;
  }

  Future<File> download(
    LearningResource resource, {
    void Function(double)? onProgress,
  }) async {
    if (!resource.allowDownload || resource.storagePath == null) {
      throw StateError('Downloads are not available for this resource.');
    }
    final destination = await _downloadFile(resource);
    final partial = File('${destination.path}.part');
    final http = HttpClient();
    try {
      final request = await http.getUrl(Uri.parse(await signedUrl(resource)));
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('Download failed', uri: request.uri);
      }
      final sink = partial.openWrite();
      var received = 0;
      try {
        await for (final chunk in response) {
          sink.add(chunk);
          received += chunk.length;
          if (response.contentLength > 0) {
            onProgress?.call(received / response.contentLength);
          }
        }
        await sink.flush();
      } finally {
        await sink.close();
      }
      if (await destination.exists()) await destination.delete();
      return partial.rename(destination.path);
    } catch (_) {
      if (await partial.exists()) await partial.delete();
      rethrow;
    } finally {
      http.close(force: true);
    }
  }
}

final resourceRepositoryProvider = Provider<ResourceRepository>(
  (ref) => ResourceRepository(ref.watch(supabaseProvider)),
);
final resourcesProvider = FutureProvider<List<LearningResource>>(
  (ref) => ref.watch(resourceRepositoryProvider).list(),
);
final resourceProvider = FutureProvider.family<LearningResource, String>(
  (ref, id) => ref.watch(resourceRepositoryProvider).get(id),
);
