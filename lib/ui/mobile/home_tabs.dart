import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/sorting.dart';
import '../../state/providers.dart';
import '../../state/selection.dart';
import '../desktop/detail_pane.dart';
import '../desktop/month_grid.dart';
import '../settings_page.dart';
import '../theme.dart';
import '../widgets/countdown_card.dart';
import '../widgets/deadline_editor.dart';
import '../widgets/exact_alarms_banner.dart';
import '../widgets/quick_add_field.dart';

/// Phone layout: Upcoming / Calendar / Settings.
class HomeTabs extends ConsumerStatefulWidget {
  const HomeTabs({super.key, this.banner});

  /// Shown at the top of Upcoming (e.g. "Notifications are off").
  final Widget? banner;

  @override
  ConsumerState<HomeTabs> createState() => _HomeTabsState();
}

class _HomeTabsState extends ConsumerState<HomeTabs> {
  var _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _tab, children: [
        _UpcomingTab(banner: widget.banner),
        const _CalendarTab(),
        Scaffold(appBar: AppBar(title: const Text('Settings')), body: const SettingsPage()),
      ]),
      floatingActionButton: _tab == 2
          ? null
          : FloatingActionButton.extended(
              onPressed: () => showDeadlineEditor(context, day: _tab == 1 ? ref.read(calendarSelectionProvider).day : null),
              icon: const Icon(Icons.add_rounded),
              label: const Text('New'),
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.hourglass_top_rounded), label: 'Upcoming'),
          NavigationDestination(icon: Icon(Icons.calendar_month_rounded), label: 'Calendar'),
          NavigationDestination(icon: Icon(Icons.settings_rounded), label: 'Settings'),
        ],
      ),
    );
  }
}

Future<void> _openDetail(BuildContext context, Deadline d) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => _DeadlinePage(id: d.id)));

class _UpcomingTab extends ConsumerWidget {
  const _UpcomingTab({this.banner});
  final Widget? banner;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final now = ref.watch(nowProvider);
    final all = ref.watch(deadlinesProvider).value ?? const <Deadline>[];
    final groups = ref.watch(groupsProvider).value ?? const <Group>[];
    final list = upcoming(all, now, groupFilter: effectiveGroupFilter(settings.groupFilter, groups));
    void setFilter(String? f) => ref.read(settingsProvider.notifier).update((s) => s.copyWith(groupFilter: f));

    Widget chip(String? value, String label, Color color) => Padding(
          padding: const EdgeInsets.only(right: 6),
          child: ChoiceChip(
            avatar: CircleAvatar(radius: 5, backgroundColor: color),
            label: Text(label),
            selected: effectiveGroupFilter(settings.groupFilter, groups) == value,
            showCheckmark: false,
            onSelected: (_) => setFilter(value),
          ),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Deadlines')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 96), children: [
        if (banner != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: banner),
        const ExactAlarmsBanner(),
        const QuickAddField(),
        if (groups.isNotEmpty)
          SizedBox(
            height: 48,
            child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.only(top: 10), children: [
              chip(null, 'All', theme.colorScheme.primary),
              for (final g in groups) chip(g.id, g.name, colorOf(g.color)),
              chip(noGroupFilter, 'No group', colorOf(DeadlineColor.graphite)),
            ]),
          ),
        const SizedBox(height: 12),
        if (list.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 48),
            child: Column(children: [
              Icon(Icons.hourglass_empty_rounded, size: 48, color: theme.colorScheme.outline),
              const SizedBox(height: 8),
              Text('No deadlines yet', style: theme.textTheme.titleMedium),
              Text('Type one above, e.g. "Essay Friday 5pm".', style: theme.textTheme.bodySmall),
            ]),
          ),
        for (final d in list)
          Padding(padding: const EdgeInsets.only(bottom: 8), child: CountdownCard(deadline: d, onTap: () => _openDetail(context, d))),
      ]),
    );
  }
}

class _CalendarTab extends ConsumerWidget {
  const _CalendarTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(calendarSelectionProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Calendar')),
      body: Column(children: [
        Expanded(flex: 3, child: MonthGrid(month: selection.month)),
        const Divider(height: 1),
        const Expanded(flex: 2, child: DetailPane()),
      ]),
    );
  }
}

/// Full-screen deadline detail; closes itself if the deadline is deleted.
class _DeadlinePage extends ConsumerWidget {
  const _DeadlinePage({required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deadline = (ref.watch(deadlinesProvider).value ?? const <Deadline>[]).where((d) => d.id == id).firstOrNull;
    if (deadline == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();
      });
      return const Scaffold();
    }
    return Scaffold(appBar: AppBar(), body: DeadlineDetail(deadline: deadline));
  }
}
