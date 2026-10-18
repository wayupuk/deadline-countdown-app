import 'package:deadlines/core/models.dart';
import 'package:deadlines/core/reminders.dart';
import 'package:test/test.dart';

Deadline dl(String title, DateTime due, {Priority p = Priority.normal, bool reminders = true, int h = 9, int m = 0}) =>
    Deadline(
        id: title,
        title: title,
        dueAt: due,
        priority: p,
        reminderEnabled: reminders,
        reminderHour: h,
        reminderMinute: m,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1));

void main() {
  test('daily at reminder time through the due day, plus due notice', () {
    final now = DateTime(2026, 10, 18, 8);
    final plan = planReminders([dl('Thesis', DateTime(2026, 10, 21, 17))], now);
    expect(plan.where((r) => r.kind == ReminderKind.daily).map((r) => r.fireAt),
        [DateTime(2026, 10, 18, 9), DateTime(2026, 10, 19, 9), DateTime(2026, 10, 20, 9), DateTime(2026, 10, 21, 9)]);
    expect(plan.last.kind, ReminderKind.due);
    expect(plan.first.body, '3 days, 8 hours left');
    expect(plan.first.title, '📅 Thesis');
    expect(plan.last.title, '⏰ Thesis');
    expect(plan.map((r) => r.id).toSet().length, plan.length);
  });

  test('reminder time already passed today starts tomorrow', () {
    final plan = planReminders([dl('A', DateTime(2026, 10, 20, 12))], DateTime(2026, 10, 18, 10));
    expect(plan.first.fireAt, DateTime(2026, 10, 19, 9));
  });

  test('nothing at or after the due moment', () {
    final d = dl('B', DateTime(2026, 10, 19, 8, 30));
    final plan = planReminders([d], DateTime(2026, 10, 18, 8));
    expect(plan.map((r) => r.fireAt), [DateTime(2026, 10, 18, 9), d.dueAt]);
  });

  test('reminders off → only due notice; overdue → nothing', () {
    final now = DateTime(2026, 10, 18, 8);
    final off = planReminders([dl('C', DateTime(2026, 10, 25), reminders: false, p: Priority.urgent)], now);
    expect(off.map((r) => r.kind), [ReminderKind.due]);
    expect(planReminders([dl('D', DateTime(2026, 10, 17))], now), isEmpty);
  });

  test('DST keeps wall-clock time (America/New_York)', () {
    final plan = planReminders([dl('E', DateTime(2026, 11, 3, 12), h: 9, m: 30)], DateTime(2026, 10, 30, 8));
    final daily = plan.where((r) => r.kind == ReminderKind.daily).toList();
    expect(daily.length, 5);
    expect(daily.every((r) => r.fireAt.hour == 9 && r.fireAt.minute == 30), isTrue);
  });

  test('priority extras', () {
    final now = DateTime(2026, 10, 18, 8);
    final due = DateTime(2026, 10, 25, 17);
    List<DateTime> extras(Priority p) => planReminders([dl('P', due, p: p)], now)
        .where((r) => r.kind == ReminderKind.priority)
        .map((r) => r.fireAt)
        .toList();
    expect(extras(Priority.normal), isEmpty);
    expect(extras(Priority.high), [DateTime(2026, 10, 24, 17)]);
    expect(extras(Priority.urgent), [DateTime(2026, 10, 24, 17), DateTime(2026, 10, 25, 14), DateTime(2026, 10, 25, 16)]);
    // Extras that have already passed are skipped.
    final soon = planReminders([dl('S', DateTime(2026, 10, 18, 10), p: Priority.urgent)], now)
        .where((r) => r.kind == ReminderKind.priority)
        .map((r) => r.fireAt);
    expect(soon, [DateTime(2026, 10, 18, 9)]);
  });

  test('limit keeps the earliest across deadlines; until bounds the window', () {
    final now = DateTime(2026, 10, 18, 8);
    final far = List.generate(5, (i) => dl('Far$i', DateTime(2027, 3, 1), h: 9 + i));
    final soon = dl('Soon', DateTime(2026, 10, 18, 9, 30), reminders: false);
    final capped = planReminders([...far, soon], now, limit: 60);
    final all = planReminders([...far, soon], now, limit: 100000);
    expect(capped.length, 60);
    // Every non-daily reminder is kept; daily ones fill the remaining room, earliest first.
    final essential = all.where((r) => r.kind != ReminderKind.daily);
    final daily = all.where((r) => r.kind == ReminderKind.daily).take(60 - essential.length);
    expect(capped.map((r) => r.id).toSet(), {...essential.map((r) => r.id), ...daily.map((r) => r.id)});
    expect(capped.any((r) => r.deadlineId == 'Soon' && r.kind == ReminderKind.due), isTrue);
    final window = planReminders([...far, soon], now, limit: 100000, until: now.add(const Duration(hours: 24)));
    expect(window.every((r) => !r.fireAt.isAfter(now.add(const Duration(hours: 24)))), isTrue);
  });

  test('cap keeps every due-now and priority reminder before daily ones', () {
    final now = DateTime(2026, 10, 18, 8);
    final many = List.generate(40, (i) => dl('D$i', DateTime(2026, 10, 28, 17), p: i < 5 ? Priority.urgent : Priority.normal));
    final plan = planReminders(many, now, limit: 60);
    expect(plan.length, 60);
    expect(plan.where((r) => r.kind == ReminderKind.due).length, 40);
    expect(plan.where((r) => r.kind == ReminderKind.priority).length, 15);
    expect(plan.map((r) => r.fireAt), [...plan.map((r) => r.fireAt)]..sort());
  });

  test('stable int ids', () {
    expect(stableNotificationId('abc'), stableNotificationId('abc'));
    expect(stableNotificationId('abc'), isNot(stableNotificationId('abd')));
    expect(stableNotificationId('x') >= 0 && stableNotificationId('x') < 0x80000000, isTrue);
  });
}
