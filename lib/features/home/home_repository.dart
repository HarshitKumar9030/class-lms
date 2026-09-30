import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/services/supabase_provider.dart';

class HomeItem {
  const HomeItem({
    required this.id,
    required this.title,
    this.subtitle,
    this.date,
  });
  final String id;
  final String title;
  final String? subtitle;
  final DateTime? date;
}

class HomeOverview {
  const HomeOverview({
    this.nextClass,
    this.recentResource,
    this.upcomingQuiz,
    this.dueAssignment,
  });
  final HomeItem? nextClass;
  final HomeItem? recentResource;
  final HomeItem? upcomingQuiz;
  final HomeItem? dueAssignment;
}

class HomeRepository {
  const HomeRepository(this.client);
  final SupabaseClient client;

  Future<HomeOverview> load() async {
    final now = DateTime.now().toUtc().toIso8601String();
    final classes = await client
        .from('schedule_events')
        .select('id,title,subtitle,starts_at')
        .gte('starts_at', now)
        .eq('status', 'scheduled')
        .order('starts_at')
        .limit(1);
    final resources = await client
        .from('resources')
        .select('id,title,description')
        .eq('is_published', true)
        .order('created_at', ascending: false)
        .limit(1);
    final quizzes = await client
        .from('quizzes')
        .select('id,title,description,closes_at')
        .eq('is_published', true)
        .or('closes_at.is.null,closes_at.gte.$now')
        .order('created_at', ascending: false)
        .limit(1);
    final assignments = await client
        .from('assignments')
        .select('id,title,due_at')
        .eq('is_published', true)
        .gte('due_at', now)
        .order('due_at')
        .limit(1);
    HomeItem? item(
      List<Map<String, dynamic>> rows, {
      String? dateKey,
      String? subtitleKey,
    }) {
      if (rows.isEmpty) return null;
      final row = rows.first;
      return HomeItem(
        id: row['id'] as String,
        title: row['title'] as String,
        subtitle: row[subtitleKey] as String?,
        date: dateKey == null || row[dateKey] == null
            ? null
            : DateTime.parse(row[dateKey] as String).toLocal(),
      );
    }

    return HomeOverview(
      nextClass: item(classes, dateKey: 'starts_at', subtitleKey: 'subtitle'),
      recentResource: item(resources, subtitleKey: 'description'),
      upcomingQuiz: item(
        quizzes,
        dateKey: 'closes_at',
        subtitleKey: 'description',
      ),
      dueAssignment: item(assignments, dateKey: 'due_at'),
    );
  }
}

final homeRepositoryProvider = Provider<HomeRepository>(
  (ref) => HomeRepository(ref.watch(supabaseProvider)),
);
final homeOverviewProvider = FutureProvider<HomeOverview>(
  (ref) => ref.watch(homeRepositoryProvider).load(),
);
