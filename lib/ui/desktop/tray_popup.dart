import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/sorting.dart';
import '../../state/providers.dart';
import '../../state/selection.dart';
import '../theme.dart';
import '../widgets/countdown_card.dart';
import '../widgets/quick_add_field.dart';

/// The menu bar / tray dropdown: quick add, group chips, live countdown cards, and shortcuts.
class TrayPopup extends ConsumerWidget {
  const TrayPopup({super.key, required this.onOpenCalendar, required this.onOpenSettings, required this.onQuit, this.banner});

  final VoidCallback onOpenCalendar;
  final VoidCallback onOpenSettings;
  final VoidCallback onQuit;
  final Widget? banner;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final now = ref.watch(nowProvider);
    final all = ref.watch(deadlinesProvider).value ?? const <Deadline>[];
    final groups = ref.watch(groupsProvider).value ?? const <Group>[];
    final list = upcoming(all, now, groupFilter: settings.groupFilter);
    final total = upcoming(all, now).length;
    void setFilter(String? f) => ref.read(settingsProvider.notifier).update((s) => s.copyWith(groupFilter: f));

    Widget chip(String? value, String label, Color color) => Padding(
          padding: const EdgeInsets.only(right: 6),
          child: ChoiceChip(
            avatar: CircleAvatar(radius: 5, backgroundColor: color),
            label: Text(label),
            selected: settings.groupFilter == value,
            showCheckmark: false,
            visualDensity: VisualDensity.compact,
            onSelected: (_) => setFilter(value),
          ),
        );

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('Deadlines', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(total == 0 ? 'Nothing coming up' : '$total upcoming',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ),
          ]),
        ),
        if (banner != null) Padding(padding: const EdgeInsets.fromLTRB(12, 0, 12, 8), child: banner),
        const Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: QuickAddField(autofocus: true)),
        if (groups.isNotEmpty)
          SizedBox(
            height: 44,
            child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.fromLTRB(12, 8, 12, 0), children: [
              chip(null, 'All', theme.colorScheme.primary),
              for (final g in groups) chip(g.id, g.name, colorOf(g.color)),
              chip(noGroupFilter, 'No group', colorOf(DeadlineColor.graphite)),
            ]),
          ),
        const SizedBox(height: 8),
        Expanded(
          child: list.isEmpty
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.hourglass_empty_rounded, size: 40, color: theme.colorScheme.outline),
                    const SizedBox(height: 8),
                    Text('No deadlines yet', style: theme.textTheme.titleSmall),
                    Text('Type one above and press Enter.', style: theme.textTheme.bodySmall),
                  ]),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) => CountdownCard(
                    deadline: list[i],
                    onTap: () {
                      ref.read(calendarSelectionProvider.notifier).selectDeadline(list[i]);
                      onOpenCalendar();
                    },
                  ),
                ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Row(children: [
            TextButton.icon(onPressed: onOpenCalendar, icon: const Icon(Icons.calendar_month_rounded), label: const Text('Open Calendar')),
            const Spacer(),
            IconButton(tooltip: 'Settings', onPressed: onOpenSettings, icon: const Icon(Icons.settings_rounded)),
            IconButton(tooltip: 'Quit', onPressed: onQuit, icon: const Icon(Icons.power_settings_new_rounded)),
          ]),
        ),
      ]),
    );
  }
}
