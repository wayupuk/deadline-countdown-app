import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/countdown.dart';
import '../../core/models.dart';
import '../../core/sorting.dart';
import '../../state/providers.dart';
import '../theme.dart';

/// Create (no [existing]) or edit a deadline. Prefill values come from quick add's "Details…".
Future<Deadline?> showDeadlineEditor(BuildContext context,
        {Deadline? existing, String? title, DateTime? due, String? groupId, Priority? priority, DateTime? day}) =>
    showDialog<Deadline>(
      context: context,
      builder: (_) => DeadlineEditor(
          existing: existing, title: title, due: due, groupId: groupId, priority: priority, day: day),
    );

/// 5:00 PM on [day] (or tomorrow); if that's already past, the next whole hour.
DateTime defaultDue(DateTime now, {DateTime? day}) {
  final base = day ?? DateTime(now.year, now.month, now.day + 1);
  final fivePm = DateTime(base.year, base.month, base.day, 17);
  return fivePm.isAfter(now) ? fivePm : DateTime(now.year, now.month, now.day, now.hour + 1);
}

class DeadlineEditor extends ConsumerStatefulWidget {
  const DeadlineEditor({super.key, this.existing, this.title, this.due, this.groupId, this.priority, this.day});

  final Deadline? existing;
  final String? title;
  final DateTime? due;
  final String? groupId;
  final Priority? priority;
  final DateTime? day;

  @override
  ConsumerState<DeadlineEditor> createState() => _DeadlineEditorState();
}

class _DeadlineEditorState extends ConsumerState<DeadlineEditor> {
  late final TextEditingController _title;
  late final TextEditingController _notes;
  late DateTime _due;
  late String _groupKey; // group id or noGroupFilter
  late Priority _priority;
  late bool _reminder;
  late TimeOfDay _reminderTime;

  static const _newGroupKey = '__new__';

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? widget.title ?? '');
    _notes = TextEditingController(text: e?.notes ?? '');
    _due = e?.dueAt ?? widget.due ?? defaultDue(DateTime.now(), day: widget.day);
    _groupKey = e?.groupId ?? widget.groupId ?? noGroupFilter;
    _priority = e?.priority ?? widget.priority ?? Priority.normal;
    _reminder = e?.reminderEnabled ?? true;
    _reminderTime = TimeOfDay(hour: e?.reminderHour ?? 9, minute: e?.reminderMinute ?? 0);
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  /// New deadlines, and edits that move the date, must be in the future.
  String? get _dateProblem {
    final moved = widget.existing == null || widget.existing!.dueAt.difference(_due).abs() >= const Duration(minutes: 1);
    return moved && !_due.isAfter(DateTime.now()) ? 'Pick a time in the future.' : null;
  }

  bool get _canSave => _title.text.trim().isNotEmpty && _dateProblem == null;

  Future<void> _pickDueTime() async {
    final picked = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_due));
    if (picked != null) setState(() => _due = DateTime(_due.year, _due.month, _due.day, picked.hour, picked.minute));
  }

  Future<void> _pickReminderTime() async {
    final picked = await showTimePicker(context: context, initialTime: _reminderTime);
    if (picked != null) setState(() => _reminderTime = picked);
  }

  Future<void> _newGroup(List<Group> groups) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New group'),
        content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 40,
            decoration: const InputDecoration(labelText: 'Name'),
            onSubmitted: (v) => Navigator.pop(context, v)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Create')),
        ],
      ),
    );
    if (name == null || name.trim().isEmpty) return;
    final color = DeadlineColor.values[groups.length % (DeadlineColor.values.length - 1)];
    final g = await ref.read(repositoryProvider).createGroup(name, color, sortOrder: groups.length);
    setState(() => _groupKey = g.id);
  }

  Future<void> _save() async {
    final due = DateTime(_due.year, _due.month, _due.day, _due.hour, _due.minute); // whole minutes
    final now = DateTime.now().toUtc();
    final groupId = _groupKey == noGroupFilter ? null : _groupKey;
    final base = widget.existing ??
        Deadline(id: const Uuid().v4(), title: '', dueAt: due, createdAt: now, updatedAt: now);
    final saved = base.copyWith(
        title: _title.text.trim(),
        dueAt: due,
        groupId: groupId,
        priority: _priority,
        notes: _notes.text.trim(),
        reminderEnabled: _reminder,
        reminderHour: _reminderTime.hour,
        reminderMinute: _reminderTime.minute);
    await ref.read(repositoryProvider).saveDeadline(saved);
    if (mounted) Navigator.pop(context, saved);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final groups = ref.watch(groupsProvider).value ?? const <Group>[];
    final creating = widget.existing == null;
    final problem = _dateProblem;
    String two(int v) => v.toString().padLeft(2, '0');
    if (_groupKey != noGroupFilter && groups.every((g) => g.id != _groupKey) && groups.isNotEmpty) {
      _groupKey = noGroupFilter; // group was deleted meanwhile
    }

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 820),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
            child: Row(children: [
              Expanded(child: Text(creating ? 'New Deadline' : 'Edit Deadline', style: theme.textTheme.titleLarge)),
              Text(sentenceCountdown(DateTime.now(), _due),
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: problem == null ? theme.colorScheme.primary : theme.colorScheme.error)),
            ]),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                TextField(
                  controller: _title,
                  autofocus: creating && _title.text.isEmpty,
                  decoration: const InputDecoration(labelText: 'Title'),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                CalendarDatePicker(
                  initialDate: _due,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                  onDateChanged: (d) => setState(() => _due = DateTime(d.year, d.month, d.day, _due.hour, _due.minute)),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.schedule_rounded),
                  title: const Text('Time'),
                  trailing: OutlinedButton(
                      onPressed: _pickDueTime, child: Text('${two(_due.hour)}:${two(_due.minute)}')),
                ),
                if (problem != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(problem, style: TextStyle(color: theme.colorScheme.error)),
                  ),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  initialValue: _groupKey,
                  decoration: const InputDecoration(labelText: 'Group'),
                  items: [
                    DropdownMenuItem(value: noGroupFilter, child: _GroupLabel(color: colorOf(DeadlineColor.graphite), name: 'No group')),
                    for (final g in groups) DropdownMenuItem(value: g.id, child: _GroupLabel(color: colorOf(g.color), name: g.name)),
                    const DropdownMenuItem(value: _newGroupKey, child: Text('New group…')),
                  ],
                  onChanged: (v) {
                    if (v == _newGroupKey) {
                      _newGroup(groups);
                    } else if (v != null) {
                      setState(() => _groupKey = v);
                    }
                  },
                ),
                const SizedBox(height: 16),
                Text('Priority', style: theme.textTheme.labelLarge),
                const SizedBox(height: 8),
                SegmentedButton<Priority>(
                  segments: [for (final p in Priority.values) ButtonSegment(value: p, label: Text(priorityLabel(p)))],
                  selected: {_priority},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) => setState(() => _priority = s.single),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Daily reminder'),
                  subtitle: Text(_priority == Priority.urgent
                      ? 'Plus 1 day, 3 hours and 1 hour before'
                      : _priority == Priority.high
                          ? 'Plus 1 day before'
                          : 'Every day until it\'s due'),
                  value: _reminder,
                  onChanged: (v) => setState(() => _reminder = v),
                ),
                if (_reminder)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.notifications_active_outlined),
                    title: const Text('Remind me every day at'),
                    trailing: OutlinedButton(
                        onPressed: _pickReminderTime,
                        child: Text('${two(_reminderTime.hour)}:${two(_reminderTime.minute)}')),
                  ),
                const SizedBox(height: 8),
                TextField(controller: _notes, minLines: 2, maxLines: 5, decoration: const InputDecoration(labelText: 'Notes')),
              ]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              const SizedBox(width: 8),
              FilledButton(onPressed: _canSave ? _save : null, child: Text(creating ? 'Add Deadline' : 'Save')),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel({required this.color, required this.name});
  final Color color;
  final String name;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(name),
      ]);
}
