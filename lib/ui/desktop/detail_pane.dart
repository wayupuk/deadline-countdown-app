import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/countdown.dart';
import '../../core/date_format.dart';
import '../../core/models.dart';
import '../../state/providers.dart';
import '../../state/selection.dart';
import '../theme.dart';
import '../widgets/countdown_card.dart';
import '../widgets/deadline_editor.dart';

/// Right-hand pane: the selected deadline's big countdown, or the selected day's deadlines.
class DetailPane extends ConsumerWidget {
  const DetailPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(calendarSelectionProvider);
    final deadlines = ref.watch(deadlinesProvider).value ?? const <Deadline>[];
    final selected = deadlines.where((d) => d.id == selection.deadlineId).firstOrNull;
    if (selected != null) return DeadlineDetail(deadline: selected);
    if (selection.day != null) return _DayDetail(day: selection.day!, deadlines: deadlines);
    return const _Empty();
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.calendar_month_rounded, size: 48, color: theme.colorScheme.outline),
        const SizedBox(height: 12),
        Text('Nothing selected', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text('Pick a day or a deadline.', style: theme.textTheme.bodySmall),
      ]),
    );
  }
}

class _DayDetail extends ConsumerWidget {
  const _DayDetail({required this.day, required this.deadlines});
  final DateTime day;
  final List<Deadline> deadlines;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final onDay = deadlines
        .where((d) => d.dueAt.year == day.year && d.dueAt.month == day.month && d.dueAt.day == day.day)
        .toList()
      ..sort((a, b) => a.dueAt.compareTo(b.dueAt));
    final label = dueLabelLong(DateTime(day.year, day.month, day.day), buddhist: settings.buddhistYears).split(' at ').first;

    return ListView(padding: const EdgeInsets.all(20), children: [
      Text(label, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: 16),
      if (onDay.isEmpty)
        Text('No deadlines on this day.', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      for (final d in onDay)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: CountdownCard(deadline: d, onTap: () => ref.read(calendarSelectionProvider.notifier).selectDeadline(d)),
        ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: () => showDeadlineEditor(context, day: day),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New deadline on this day'),
      ),
    ]);
  }
}

/// Big ring countdown with details and Edit / Delete.
class DeadlineDetail extends ConsumerStatefulWidget {
  const DeadlineDetail({super.key, required this.deadline});
  final Deadline deadline;

  @override
  ConsumerState<DeadlineDetail> createState() => _DeadlineDetailState();
}

class _DeadlineDetailState extends ConsumerState<DeadlineDetail> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _delete() async {
    final d = widget.deadline;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete “${d.title}”?'),
        content: const Text('Its reminders will be cancelled.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(repositoryProvider).deleteDeadline(d.id);
      ref.read(calendarSelectionProvider.notifier).clearDeadline();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final d = widget.deadline;
    final groups = ref.watch(groupsProvider).value ?? const <Group>[];
    final settings = ref.watch(settingsProvider);
    final tint = tintFor(d, groups);
    final group = groupOf(d, groups);
    final now = DateTime.now();
    final overdue = d.isOverdue(now);
    final left = d.dueAt.difference(now);
    final days = left.isNegative ? 0 : left.inDays;
    String two(int v) => v.toString().padLeft(2, '0');
    final reminder = d.reminderEnabled ? 'Every day at ${two(d.reminderHour)}:${two(d.reminderMinute)}' : 'Off';

    return ListView(padding: const EdgeInsets.all(20), children: [
      Row(children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: tint, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text((group?.name ?? 'No group').toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(color: tint, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
        const Spacer(),
        PriorityBadge(d.priority),
      ]),
      const SizedBox(height: 6),
      SelectableText(d.title, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: 4),
      Text(dueLabelLong(d.dueAt, buddhist: settings.buddhistYears),
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      const SizedBox(height: 24),
      Center(
        child: SizedBox.square(
          dimension: 220,
          child: CustomPaint(
            painter: _RingPainter(progress: d.progress(now), color: tint, track: tint.withValues(alpha: 0.15)),
            child: Center(
              child: overdue
                  ? Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.verified_rounded, size: 40, color: tint),
                      const SizedBox(height: 6),
                      Text('Deadline passed', style: theme.textTheme.titleMedium),
                    ])
                  : Column(mainAxisSize: MainAxisSize.min, children: [
                      Text('$days',
                          style: theme.textTheme.displayMedium
                              ?.copyWith(fontWeight: FontWeight.w800, fontFeatures: tabularFigures)),
                      Text(days == 1 ? 'DAY LEFT' : 'DAYS LEFT',
                          style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 1.2, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Text(clockCountdown(now, d.dueAt).split(' ').last,
                          style: theme.textTheme.titleLarge?.copyWith(color: tint, fontFeatures: tabularFigures)),
                    ]),
            ),
          ),
        ),
      ),
      const SizedBox(height: 24),
      Card(
        child: Column(children: [
          ListTile(leading: const Icon(Icons.notifications_rounded), title: const Text('Reminder'), trailing: Text(reminder)),
          ListTile(
              leading: const Icon(Icons.flag_rounded),
              title: const Text('Priority'),
              trailing: Text(priorityLabel(d.priority))),
        ]),
      ),
      if (d.notes.isNotEmpty) ...[
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Notes', style: theme.textTheme.labelMedium),
              const SizedBox(height: 4),
              SelectableText(d.notes),
            ]),
          ),
        ),
      ],
      const SizedBox(height: 20),
      Row(children: [
        Expanded(
          child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: tint),
              onPressed: () => showDeadlineEditor(context, existing: d),
              icon: const Icon(Icons.edit_rounded),
              label: const Text('Edit')),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(onPressed: _delete, icon: const Icon(Icons.delete_outline_rounded), label: const Text('Delete')),
        ),
      ]),
    ]);
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress, required this.color, required this.track});
  final double progress;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 14.0;
    final rect = Offset.zero & size;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect.deflate(stroke / 2), 0, math.pi * 2, false, paint..color = track);
    canvas.drawArc(rect.deflate(stroke / 2), -math.pi / 2, math.pi * 2 * progress, false, paint..color = color);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress || old.color != color;
}
