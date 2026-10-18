import 'package:flutter/gestures.dart' show kDoubleTapTimeout;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/date_format.dart';
import '../../core/models.dart';
import '../../state/providers.dart';
import '../../state/selection.dart';
import '../theme.dart';
import '../widgets/deadline_editor.dart';

/// Calendar.app-style month: 6×7 day cells with deadline chips. Tap a day to select it, a chip to open the
/// deadline, double-click a day to add a deadline on it.
class MonthGrid extends ConsumerWidget {
  const MonthGrid({super.key, required this.month});

  /// Any day in the month to show.
  final DateTime month;

  static List<DateTime> gridDays(DateTime month, int firstWeekday) {
    final first = DateTime(month.year, month.month);
    final offset = (first.weekday - firstWeekday + 7) % 7;
    return List.generate(42, (i) => DateTime(first.year, first.month, first.day - offset + i));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final selection = ref.watch(calendarSelectionProvider);
    final notifier = ref.read(calendarSelectionProvider.notifier);
    final deadlines = (ref.watch(deadlinesProvider).value ?? const <Deadline>[]).where((d) => d.deletedAt == null);
    final groups = ref.watch(groupsProvider).value ?? const <Group>[];

    // MaterialLocalizations: 0 = Sunday … 6 = Saturday; DateTime.weekday: 1 = Monday … 7 = Sunday.
    final firstIndex = MaterialLocalizations.of(context).firstDayOfWeekIndex;
    final firstWeekday = firstIndex == 0 ? 7 : firstIndex;
    final days = gridDays(month, firstWeekday);
    final byDay = <DateTime, List<Deadline>>{};
    for (final d in deadlines) {
      final key = DateTime(d.dueAt.year, d.dueAt.month, d.dueAt.day);
      (byDay[key] ??= []).add(d);
    }
    for (final list in byDay.values) {
      list.sort((a, b) => a.dueAt.compareTo(b.dueAt));
    }
    final (monthName, yearText) = monthTitle(month, buddhist: settings.buddhistYears);
    final weekdayNames = MaterialLocalizations.of(context).narrowWeekdays;

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 16, 8),
        child: Row(children: [
          // The title shrinks to fit narrow (phone) widths; the buttons keep their size.
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                Text(monthName, style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(width: 8),
                Text(yearText, style: theme.textTheme.headlineMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ]),
            ),
          ),
          const SizedBox(width: 8),
          const Spacer(),
          IconButton.filledTonal(
              tooltip: 'Previous month', onPressed: () => notifier.moveMonth(-1), icon: const Icon(Icons.chevron_left_rounded)),
          const SizedBox(width: 6),
          FilledButton.tonal(onPressed: notifier.goToToday, child: const Text('Today')),
          const SizedBox(width: 6),
          IconButton.filledTonal(
              tooltip: 'Next month', onPressed: () => notifier.moveMonth(1), icon: const Icon(Icons.chevron_right_rounded)),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(children: [
          for (var i = 0; i < 7; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 10, bottom: 6),
                child: Text(weekdayNames[(firstIndex + i) % 7],
                    textAlign: TextAlign.right,
                    style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w700)),
              ),
            ),
        ]),
      ),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.colorScheme.outlineVariant),
              color: theme.colorScheme.outlineVariant,
            ),
            child: Column(children: [
              for (var week = 0; week < 6; week++)
                Expanded(
                  child: Row(children: [
                    for (final day in days.sublist(week * 7, week * 7 + 7))
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(0.5),
                          child: DayCell(
                            day: day,
                            inMonth: day.month == month.month,
                            selected: selection.day == day,
                            deadlines: byDay[day] ?? const [],
                            groups: groups,
                            selectedDeadlineId: selection.deadlineId,
                            onTapDay: () => notifier.selectDay(day),
                            onTapDeadline: notifier.selectDeadline,
                            onNewDeadline: () => showDeadlineEditor(context, day: day),
                          ),
                        ),
                      ),
                  ]),
                ),
            ]),
          ),
        ),
      ),
    ]);
  }
}

class DayCell extends StatefulWidget {
  const DayCell({
    super.key,
    required this.day,
    required this.inMonth,
    required this.selected,
    required this.deadlines,
    required this.groups,
    required this.selectedDeadlineId,
    required this.onTapDay,
    required this.onTapDeadline,
    required this.onNewDeadline,
  });

  final DateTime day;
  final bool inMonth;
  final bool selected;
  final List<Deadline> deadlines;
  final List<Group> groups;
  final String? selectedDeadlineId;
  final VoidCallback onTapDay;
  final void Function(Deadline) onTapDeadline;
  final VoidCallback onNewDeadline;

  @override
  State<DayCell> createState() => _DayCellState();
}

class _DayCellState extends State<DayCell> {
  // Double-click is detected from tap times rather than a double-tap recognizer, which would delay
  // every single tap (including taps on deadline chips) by the double-tap timeout.
  DateTime? _lastTap;

  void _tap() {
    final now = DateTime.now();
    final isDouble = _lastTap != null && now.difference(_lastTap!) < kDoubleTapTimeout;
    _lastTap = isDouble ? null : now;
    isDouble ? widget.onNewDeadline() : widget.onTapDay();
  }

  @override
  Widget build(BuildContext context) {
    final DayCell(:day, :inMonth, :selected, :deadlines, :groups, :selectedDeadlineId, :onTapDeadline) = widget;
    final theme = Theme.of(context);
    final now = DateTime.now();
    final isToday = day.year == now.year && day.month == now.month && day.day == now.day;
    final scheme = theme.colorScheme;

    return GestureDetector(
      onTap: _tap,
      child: Container(
        decoration: BoxDecoration(
          color: selected ? scheme.primary.withValues(alpha: 0.08) : (inMonth ? scheme.surface : scheme.surfaceContainerLow),
          border: selected ? Border.all(color: scheme.primary, width: 1.5) : null,
        ),
        padding: const EdgeInsets.all(4),
        child: LayoutBuilder(builder: (context, box) {
          // Show as many chips as fit; the rest become "N more".
          final room = ((box.maxHeight - 28) / 20).floor().clamp(0, deadlines.length);
          final shown = deadlines.length > room && room > 0 ? room - 1 : room;
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Align(
              alignment: Alignment.topRight,
              child: Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: isToday ? const BoxDecoration(color: Color(0xFFFF453A), shape: BoxShape.circle) : null,
                child: Text('${day.day}',
                    style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                        color: isToday ? Colors.white : (inMonth ? scheme.onSurface : scheme.onSurfaceVariant.withValues(alpha: 0.6)),
                        fontFeatures: tabularFigures)),
              ),
            ),
            for (final d in deadlines.take(shown))
              _Chip(deadline: d, color: tintFor(d, groups), selected: d.id == selectedDeadlineId, onTap: () => onTapDeadline(d)),
            if (deadlines.length > shown && shown < deadlines.length && room > 0)
              Padding(
                padding: const EdgeInsets.only(left: 4, top: 1),
                child: Text('${deadlines.length - shown} more',
                    style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
              ),
          ]);
        }),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.deadline, required this.color, required this.selected, required this.onTap});
  final Deadline deadline;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final time =
        '${deadline.dueAt.hour.toString().padLeft(2, '0')}:${deadline.dueAt.minute.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: selected ? color : color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(5),
        child: InkWell(
          borderRadius: BorderRadius.circular(5),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            child: LayoutBuilder(builder: (context, box) {
              final style = theme.textTheme.labelSmall?.copyWith(color: selected ? Colors.white : null);
              return Row(children: [
                Container(width: 6, height: 6, decoration: BoxDecoration(color: selected ? Colors.white : color, shape: BoxShape.circle)),
                const SizedBox(width: 4),
                Expanded(child: Text(deadline.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: style)),
                // The time only when there's room; never wrap it.
                if (box.maxWidth > 110) Text(time, style: style?.copyWith(fontFeatures: tabularFigures)),
              ]);
            }),
          ),
        ),
      ),
    );
  }
}
