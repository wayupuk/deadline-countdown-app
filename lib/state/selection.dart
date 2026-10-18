import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models.dart';

/// What the calendar window is showing: the month, the selected day, the selected deadline.
class CalendarSelection {
  const CalendarSelection({required this.month, this.day, this.deadlineId});

  /// First day of the displayed month.
  final DateTime month;
  final DateTime? day;
  final String? deadlineId;
}

DateTime _dayOf(DateTime d) => DateTime(d.year, d.month, d.day);
DateTime _monthOf(DateTime d) => DateTime(d.year, d.month);

final calendarSelectionProvider =
    NotifierProvider<CalendarSelectionNotifier, CalendarSelection>(CalendarSelectionNotifier.new);

class CalendarSelectionNotifier extends Notifier<CalendarSelection> {
  @override
  CalendarSelection build() {
    final now = DateTime.now();
    return CalendarSelection(month: _monthOf(now), day: _dayOf(now));
  }

  void moveMonth(int delta) =>
      state = CalendarSelection(month: DateTime(state.month.year, state.month.month + delta), day: state.day, deadlineId: state.deadlineId);

  void goToToday() {
    final now = DateTime.now();
    state = CalendarSelection(month: _monthOf(now), day: _dayOf(now));
  }

  void selectDay(DateTime day) => state = CalendarSelection(month: state.month, day: _dayOf(day));

  /// Selects [d] and jumps the calendar to its month.
  void selectDeadline(Deadline d) =>
      state = CalendarSelection(month: _monthOf(d.dueAt), day: _dayOf(d.dueAt), deadlineId: d.id);

  void clearDeadline() => state = CalendarSelection(month: state.month, day: state.day);
}
