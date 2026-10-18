import 'countdown.dart';
import 'models.dart';

enum ReminderKind { daily, priority, due }

class PlannedReminder {
  const PlannedReminder({
    required this.id,
    required this.deadlineId,
    required this.title,
    required this.body,
    required this.fireAt,
    required this.kind,
  });

  final String id;
  final String deadlineId;
  final String title;
  final String body;
  final DateTime fireAt;
  final ReminderKind kind;
}

/// Extra reminders before the due time, on top of the daily ones.
const _priorityOffsets = {
  Priority.high: [Duration(hours: 24)],
  Priority.urgent: [Duration(hours: 24), Duration(hours: 3), Duration(hours: 1)],
};

/// Every notification that should be pending now: daily reminders at each deadline's local reminder time
/// (strictly after [now], strictly before due), priority extras, and a "due now" notice. Only the earliest
/// [limit] are kept (OS caps); [until] bounds the window for in-app delivery.
List<PlannedReminder> planReminders(Iterable<Deadline> deadlines, DateTime now, {int limit = 60, DateTime? until}) {
  final out = <PlannedReminder>[];
  bool inWindow(DateTime t) => t.isAfter(now) && (until == null || !t.isAfter(until));

  for (final d in deadlines) {
    if (d.deletedAt != null || d.isOverdue(now)) continue;
    final due = d.dueAt.toLocal();
    if (d.reminderEnabled) {
      var day = DateTime(now.year, now.month, now.day);
      var count = 0;
      while (count < limit && day.isBefore(due) && (until == null || !day.isAfter(until))) {
        // Wall-clock constructor: daylight-saving changes keep the same local time.
        final fire = DateTime(day.year, day.month, day.day, d.reminderHour, d.reminderMinute);
        if (fire.isBefore(due) && inWindow(fire)) {
          out.add(_reminder(d, fire, ReminderKind.daily, '📅 ${d.title}', sentenceCountdown(fire, due)));
          count++;
        }
        day = DateTime(day.year, day.month, day.day + 1);
      }
      for (final offset in _priorityOffsets[d.priority] ?? const <Duration>[]) {
        final fire = due.subtract(offset);
        if (inWindow(fire)) {
          out.add(_reminder(d, fire, ReminderKind.priority, '❗ ${d.title}', sentenceCountdown(fire, due)));
        }
      }
    }
    if (inWindow(due)) {
      out.add(_reminder(d, due, ReminderKind.due, '⏰ ${d.title}', 'This deadline is due now.'));
    }
  }
  out.sort((a, b) => a.fireAt.compareTo(b.fireAt));
  return out.take(limit).toList();
}

PlannedReminder _reminder(Deadline d, DateTime fire, ReminderKind kind, String title, String body) => PlannedReminder(
    id: '${d.id}-${kind.name}-${fire.millisecondsSinceEpoch}',
    deadlineId: d.id,
    title: title,
    body: body,
    fireAt: fire,
    kind: kind);

/// 31-bit FNV-1a hash, stable across runs (Dart's String.hashCode is not), for plugins that need int ids.
int stableNotificationId(String id) {
  var hash = 0x811c9dc5;
  for (final unit in id.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash & 0x7FFFFFFF;
}
