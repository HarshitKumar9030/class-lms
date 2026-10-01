import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_components.dart';
import 'schedule_repository.dart';

class ScheduleScreen extends ConsumerStatefulWidget {
  const ScheduleScreen({super.key});
  @override
  ConsumerState<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends ConsumerState<ScheduleScreen> {
  late DateTime monday = weekStart(DateTime.now());
  late int selected = DateTime.now().weekday - 1;

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(scheduleWeekProvider(monday));
    final day = monday.add(Duration(days: selected));
    return AppPage(
      title: 'Schedule',
      onRefresh: () async => ref.invalidate(scheduleWeekProvider(monday)),
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Previous week',
              onPressed: () => setState(
                () => monday = monday.subtract(const Duration(days: 7)),
              ),
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Expanded(
              child: Text(
                '${DateFormat.MMMd().format(monday)} – ${DateFormat.MMMd().format(monday.add(const Duration(days: 6)))}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            IconButton(
              tooltip: 'Next week',
              onPressed: () =>
                  setState(() => monday = monday.add(const Duration(days: 7))),
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: List.generate(7, (index) {
            final date = monday.add(Duration(days: index));
            final active = selected == index;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Material(
                  color: active
                      ? context.palette.accent
                      : context.palette.surface,
                  borderRadius: BorderRadius.circular(AppRadius.small),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppRadius.small),
                    onTap: () => setState(() => selected = index),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      child: Column(
                        children: [
                          Text(
                            DateFormat.E().format(date).substring(0, 1),
                            style: TextStyle(
                              fontSize: 11,
                              color: active
                                  ? Colors.white
                                  : context.palette.secondary,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '${date.day}',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: active
                                  ? Colors.white
                                  : context.palette.text,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
        SectionHeader(title: DateFormat.EEEE().format(day)),
        value.when(
          loading: () => const LoadingRows(count: 2),
          error: (_, _) => ErrorState(
            message: 'Check your connection and try again.',
            onRetry: () => ref.invalidate(scheduleWeekProvider(monday)),
          ),
          data: (events) {
            final selectedEvents = events
                .where(
                  (event) =>
                      event.startsAt.year == day.year &&
                      event.startsAt.month == day.month &&
                      event.startsAt.day == day.day,
                )
                .toList();
            if (selectedEvents.isEmpty) {
              return const CompactEmptyState(
                title: 'No classes today',
                message: 'Enjoy the time to study at your own pace.',
                icon: Icons.calendar_today_outlined,
              );
            }
            return Column(
              children: selectedEvents
                  .map(
                    (event) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: AppSurface(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 70,
                              child: Text(
                                DateFormat.jm().format(event.startsAt),
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(color: context.palette.accent),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    event.title,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                  if (event.subtitle != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      event.subtitle!,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyMedium,
                                    ),
                                  ],
                                  const SizedBox(height: 8),
                                  Text(
                                    event.status == 'scheduled'
                                        ? '${DateFormat.jm().format(event.endsAt)}${event.location == null ? '' : ' · ${event.location}'}'
                                        : event.status == 'cancelled'
                                        ? 'Cancelled'
                                        : 'Rescheduled',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}
