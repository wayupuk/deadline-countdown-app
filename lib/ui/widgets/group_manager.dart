import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../state/providers.dart';
import '../theme.dart';

Future<void> showGroupManager(BuildContext context) =>
    showDialog<void>(context: context, builder: (_) => const GroupManager());

/// Create, rename, recolor, reorder and delete groups.
class GroupManager extends ConsumerStatefulWidget {
  const GroupManager({super.key});

  @override
  ConsumerState<GroupManager> createState() => _GroupManagerState();
}

class _GroupManagerState extends ConsumerState<GroupManager> {
  final _newName = TextEditingController();

  @override
  void dispose() {
    _newName.dispose();
    super.dispose();
  }

  Future<void> _add(List<Group> groups) async {
    final name = _newName.text.trim();
    if (name.isEmpty) return;
    final color = DeadlineColor.values[groups.length % (DeadlineColor.values.length - 1)];
    await ref.read(repositoryProvider).createGroup(name, color, sortOrder: groups.length);
    _newName.clear();
  }

  Future<void> _rename(Group g) async {
    final controller = TextEditingController(text: g.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename group'),
        content: TextField(
            controller: controller, autofocus: true, maxLength: 40, onSubmitted: (v) => Navigator.pop(context, v)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Rename')),
        ],
      ),
    );
    if (name != null && name.trim().isNotEmpty) {
      await ref.read(repositoryProvider).saveGroup(g.copyWith(name: name.trim()));
    }
  }

  Future<void> _delete(Group g, List<Deadline> deadlines) async {
    final count = deadlines.where((d) => d.groupId == g.id).length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete “${g.name}”?'),
        content: Text(count == 0
            ? 'No deadlines are in this group.'
            : '$count deadline${count == 1 ? '' : 's'} will move to No group. Nothing is deleted.'),
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
      await ref.read(repositoryProvider).deleteGroup(g.id);
      if (ref.read(settingsProvider).groupFilter == g.id) {
        await ref.read(settingsProvider.notifier).update((s) => s.copyWith(groupFilter: null));
      }
    }
  }

  Future<void> _reorder(List<Group> groups, int from, int to) async {
    // onReorderItem's target index already accounts for the removed item.
    final list = [...groups];
    list.insert(to, list.removeAt(from));
    final repo = ref.read(repositoryProvider);
    for (var i = 0; i < list.length; i++) {
      if (list[i].sortOrder != i) await repo.saveGroup(list[i].copyWith(sortOrder: i));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final groups = ref.watch(groupsProvider).value ?? const <Group>[];
    final deadlines = ref.watch(deadlinesProvider).value ?? const <Deadline>[];

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Groups', style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text('Each deadline can be in one group. The group color is used everywhere.',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 12),
            Flexible(
              child: groups.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text('No groups yet.', textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
                    )
                  : ReorderableListView(
                      shrinkWrap: true,
                      buildDefaultDragHandles: false,
                      onReorderItem: (from, to) => _reorder(groups, from, to),
                      children: [
                        for (final (i, g) in groups.indexed)
                          ListTile(
                            key: ValueKey(g.id),
                            contentPadding: EdgeInsets.zero,
                            leading: PopupMenuButton<DeadlineColor>(
                              tooltip: 'Color',
                              onSelected: (c) => ref.read(repositoryProvider).saveGroup(g.copyWith(color: c)),
                              itemBuilder: (_) => [
                                for (final c in DeadlineColor.values)
                                  PopupMenuItem(
                                      value: c,
                                      child: Row(children: [
                                        CircleAvatar(radius: 7, backgroundColor: colorOf(c)),
                                        const SizedBox(width: 10),
                                        Text(c.name[0].toUpperCase() + c.name.substring(1)),
                                      ])),
                              ],
                              child: CircleAvatar(radius: 9, backgroundColor: colorOf(g.color)),
                            ),
                            title: Text(g.name),
                            onTap: () => _rename(g),
                            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                              IconButton(
                                  tooltip: 'Delete group',
                                  icon: const Icon(Icons.delete_outline_rounded),
                                  onPressed: () => _delete(g, deadlines)),
                              ReorderableDragStartListener(index: i, child: const Icon(Icons.drag_indicator_rounded)),
                            ]),
                          ),
                      ],
                    ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _newName,
              maxLength: 40,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _add(groups),
              decoration: InputDecoration(
                labelText: 'New group',
                counterText: '',
                suffixIcon: IconButton(tooltip: 'Add group', icon: const Icon(Icons.add_rounded), onPressed: () => _add(groups)),
              ),
            ),
            const SizedBox(height: 12),
            Align(
                alignment: Alignment.centerRight,
                child: TextButton(onPressed: () => Navigator.pop(context), child: const Text('Done'))),
          ]),
        ),
      ),
    );
  }
}
