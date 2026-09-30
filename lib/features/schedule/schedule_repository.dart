import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/services/supabase_provider.dart';

class ScheduleEvent {
  const ScheduleEvent({
    required this.id,
    required this.title,
    required this.kind,
    required this.status,
    required this.startsAt,
    required this.endsAt,
    this.subtitle,
    this.location,
    this.recurrenceRule,
  });
  final String id;
  final String title;
  final String? subtitle;
  final String kind;
  final String status;
  final DateTime startsAt;
  final DateTime endsAt;
  final String? recurrenceRule;
  final String? location;

  factory ScheduleEvent.fromJson(Map<String, dynamic> json) => ScheduleEvent(
    id: json['id'] as String,
    title: json['title'] as String,
    subtitle: json['subtitle'] as String?,
    kind: json['kind'] as String,
    status: json['status'] as String,
    startsAt: DateTime.parse(json['starts_at'] as String).toLocal(),
    endsAt: DateTime.parse(json['ends_at'] as String).toLocal(),
    recurrenceRule: json['recurrence_rule'] as String?,
    location: json['location'] as String?,
  );

  ScheduleEvent occurrenceOn(DateTime date) {
    final start = DateTime(
      date.year,
      date.month,
      date.day,
      startsAt.hour,
      startsAt.minute,
    );
    return ScheduleEvent(
      id: id,
      title: title,
      subtitle: subtitle,
      kind: kind,
      status: status,
      startsAt: start,
      endsAt: start.add(endsAt.difference(startsAt)),
      recurrenceRule: recurrenceRule,
      location: location,
    );
  }
}

DateTime weekStart(DateTime date) {
  final midnight = DateTime(date.year, date.month, date.day);
  return midnight.subtract(Duration(days: date.weekday - 1));
}

List<ScheduleEvent> expandWeek(List<ScheduleEvent> events, DateTime monday) {
  const days = ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'];
  final result = <ScheduleEvent>[];
  for (final event in events) {
    if (event.recurrenceRule == null) {
      if (!event.startsAt.isBefore(monday) &&
          event.startsAt.isBefore(monday.add(const Duration(days: 7)))) {
        result.add(event);
      }
      continue;
    }
    final rule = event.recurrenceRule!.toUpperCase();
    if (!rule.contains('FREQ=WEEKLY')) continue;
    final match = RegExp(r'BYDAY=([A-Z,]+)').firstMatch(rule);
    final weekdays = match == null
        ? [days[event.startsAt.weekday - 1]]
        : match.group(1)!.split(',');
    for (var offset = 0; offset < 7; offset++) {
      final date = monday.add(Duration(days: offset));
      if (date.isBefore(
        DateTime(event.startsAt.year, event.startsAt.month, event.startsAt.day),
      )) {
        continue;
      }
      if (weekdays.contains(days[offset])) result.add(event.occurrenceOn(date));
    }
  }
  result.sort((a, b) => a.startsAt.compareTo(b.startsAt));
  return result;
}

class ScheduleRepository {
  const ScheduleRepository(this.client);
  final SupabaseClient client;

  Future<List<ScheduleEvent>> week(DateTime monday) async {
    final end = monday.add(const Duration(days: 7));
    final rows = await client
        .from('schedule_events')
        .select(
          'id,title,subtitle,kind,status,starts_at,ends_at,recurrence_rule,location',
        )
        .lt('starts_at', end.toUtc().toIso8601String())
        .or(
          'starts_at.gte.${monday.toUtc().toIso8601String()},recurrence_rule.not.is.null',
        )
        .order('starts_at')
        .limit(500);
    return expandWeek(rows.map(ScheduleEvent.fromJson).toList(), monday);
  }
}

final scheduleRepositoryProvider = Provider<ScheduleRepository>(
  (ref) => ScheduleRepository(ref.watch(supabaseProvider)),
);
final scheduleWeekProvider =
    FutureProvider.family<List<ScheduleEvent>, DateTime>(
      (ref, monday) => ref.watch(scheduleRepositoryProvider).week(monday),
    );
