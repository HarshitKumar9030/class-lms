import 'package:class_lms/features/schedule/schedule_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('weekly classes expand on selected weekdays after their start date', () {
    final monday = DateTime(2026, 9, 28);
    final event = ScheduleEvent(
      id: '1',
      title: 'Grammar',
      kind: 'class',
      status: 'scheduled',
      startsAt: DateTime(2026, 9, 29, 17),
      endsAt: DateTime(2026, 9, 29, 18),
      recurrenceRule: 'FREQ=WEEKLY;BYDAY=TU,TH',
    );
    final result = expandWeek([event], monday);
    expect(result.map((item) => item.startsAt.day), [29, 1]);
    expect(result.every((item) => item.startsAt.hour == 17), isTrue);
  });
}
