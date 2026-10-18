import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/countdown.dart';
import '../../core/date_format.dart';
import '../../core/models.dart';
import '../../core/sorting.dart';
import '../../state/providers.dart';
import '../../state/selection.dart';
import '../theme.dart';
import '../widgets/deadline_editor.dart';
import '../widgets/group_manager.dart';

/// Left column: group filter, then Upcoming (priority first) and Past lists.
class Sidebar extends ConsumerWidget {
  const Sidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final now = ref.watch(nowProvider);
    final all = ref.watch(deadlinesProvider).value ?? const <Deadline>[];
    final groups = ref.watch(groupsProvider).value ?? const <Group>[];
    final filter = effectiveGroupFilter(settings.groupFilter, groups);
    final up = upcoming(all, now, groupFilter: filter);
    final done = past(all, now, groupFilter: filter);
    final selectedId = ref.watch(calendarSelectionProvider).deadlineId;

    void setFilter(String? f) => ref.read(settingsProvider.notifier).update((s) => s.copyWith(groupFilter: f));
    int count(String? f) => upcoming(all, now, groupFilter: f).length;

    Widget header(String text) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
          child: Text(text.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
        );

    Widget filterTile(String? value, String label, Color color) => ListTile(
          dense: true,
          selected: filter == value,
          selectedTileColor: theme.colorScheme.secondaryContainer,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          leading: CircleAvatar(radius: 6, backgroundColor: color),
          title: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: Text('${count(value)}', style: theme.textTheme.labelSmall),
          onTap: () => setFilter(value),
        );

    Widget row(Deadline d) {
      final overdue = d.isOverdue(now);
      final tint = tintFor(d, groups);
      return ListTile(
        dense: true,
        selected: d.id == selectedId,
        selectedTileColor: tint.withValues(alpha: 0.12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        leading: CircleAvatar(radius: 5, backgroundColor: tint),
        title: Row(children: [
          Flexible(child: Text(d.title, maxLines: 1, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 4),
          PriorityBadge(d.priority),
        ]),
        subtitle: Text(dueLabel(d.dueAt, now: now, buddhist: settings.buddhistYears), maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
              color: (overdue ? theme.colorScheme.outline : tint).withValues(alpha: 0.16), borderRadius: BorderRadius.circular(10)),
          child: Text(shortCountdown(now, d.dueAt, precision: settings.precision),
              style: theme.textTheme.labelSmall?.copyWith(
                  color: overdue ? theme.colorScheme.outline : tint, fontWeight: FontWeight.w700, fontFeatures: tabularFigures)),
        ),
        onTap: () => ref.read(calendarSelectionProvider.notifier).selectDeadline(d),
        onLongPress: () => showDeadlineEditor(context, existing: d),
      );
    }

    return ListView(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8), children: [
      header('Groups'),
      filterTile(null, 'All deadlines', theme.colorScheme.primary),
      for (final g in groups) filterTile(g.id, g.name, colorOf(g.color)),
      filterTile(noGroupFilter, 'No group', colorOf(DeadlineColor.graphite)),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
            onPressed: () => showGroupManager(context), icon: const Icon(Icons.tune_rounded, size: 18), label: const Text('Manage groups…')),
      ),
      header('Upcoming'),
      if (up.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Text('No upcoming deadlines', style: theme.textTheme.bodySmall),
        ),
      for (final d in up) row(d),
      if (done.isNotEmpty) ...[header('Past'), for (final d in done) row(d)],
    ]);
  }
}
