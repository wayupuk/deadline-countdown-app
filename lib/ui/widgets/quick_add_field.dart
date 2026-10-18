import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/countdown.dart';
import '../../core/date_format.dart';
import '../../core/models.dart';
import '../../core/quick_add/quick_add_parser.dart';
import '../../state/providers.dart';
import '../theme.dart';
import 'deadline_editor.dart';

/// One-line entry: "Lab report Friday 5pm !! #Physics" + Enter. Shows how the text was read before saving.
class QuickAddField extends ConsumerStatefulWidget {
  const QuickAddField({super.key, this.autofocus = false, this.onAdded});

  final bool autofocus;
  final void Function(Deadline added)? onAdded;

  @override
  ConsumerState<QuickAddField> createState() => _QuickAddFieldState();
}

class _QuickAddFieldState extends ConsumerState<QuickAddField> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  QuickAddOutcome? _parse(List<Group> groups) {
    if (_controller.text.trim().isEmpty) return null;
    return parseQuickAdd(_controller.text, DateTime.now(), groupNames: groups.map((g) => g.name).toSet());
  }

  Future<void> _submit(List<Group> groups) async {
    final outcome = _parse(groups);
    if (outcome is! QuickAddOk) return;
    final r = outcome.result;
    final now = DateTime.now().toUtc();
    final deadline = Deadline(
        id: const Uuid().v4(),
        title: r.title,
        dueAt: r.dueAt,
        groupId: groups.where((g) => g.name == r.groupName).firstOrNull?.id,
        priority: r.priority ?? Priority.normal,
        createdAt: now,
        updatedAt: now);
    await ref.read(repositoryProvider).saveDeadline(deadline);
    _controller.clear();
    setState(() {});
    _focus.requestFocus();
    widget.onAdded?.call(deadline);
  }

  Future<void> _details(List<Group> groups) async {
    final outcome = _parse(groups);
    final (title, due, groupId, priority) = switch (outcome) {
      QuickAddOk(:final result) => (
          result.title,
          result.dueAt,
          groups.where((g) => g.name == result.groupName).firstOrNull?.id,
          result.priority
        ),
      QuickAddFailed(error: QuickAddError.noDate) => (_controller.text.trim(), null, null, null),
      _ => ('', null, null, null),
    };
    _controller.clear();
    setState(() {});
    await showDeadlineEditor(context, title: title, due: due, groupId: groupId, priority: priority);
  }

  @override
  Widget build(BuildContext context) {
    final groups = ref.watch(groupsProvider).value ?? const <Group>[];
    final outcome = _parse(groups);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.escape): () => setState(_controller.clear),
          },
          child: TextField(
            controller: _controller,
            focusNode: _focus,
            autofocus: widget.autofocus,
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _submit(groups),
            decoration: InputDecoration(
              hintText: 'Quick add — e.g. Thesis Oct 24 5pm !! #Physics',
              prefixIcon: Icon(Icons.add_circle_rounded, color: theme.colorScheme.primary),
              suffixIcon: outcome == null
                  ? null
                  : Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: TextButton(onPressed: () => _details(groups), child: const Text('Details…')),
                    ),
            ),
          ),
        ),
        if (outcome != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
            child: DefaultTextStyle.merge(
              style: theme.textTheme.bodySmall,
              child: _Preview(outcome: outcome),
            ),
          ),
      ],
    );
  }
}

class _Preview extends ConsumerWidget {
  const _Preview({required this.outcome});
  final QuickAddOutcome outcome;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final muted = theme.colorScheme.onSurfaceVariant;

    switch (outcome) {
      case QuickAddOk(:final result):
        final now = DateTime.now();
        final due = dueLabel(result.dueAt, now: now, buddhist: settings.buddhistYears) +
            (result.hasExplicitTime ? '' : ' (end of day)');
        return Row(children: [
          Icon(Icons.keyboard_return_rounded, size: 14, color: muted),
          const SizedBox(width: 6),
          Flexible(
              child: Text(result.title,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600))),
          if (result.priority != null) ...[const SizedBox(width: 6), PriorityBadge(result.priority!)],
          if (result.groupName != null) ...[
            const SizedBox(width: 6),
            Text('#${result.groupName}', style: TextStyle(color: theme.colorScheme.primary)),
          ],
          Text('  ·  ', style: TextStyle(color: muted)),
          Flexible(child: Text(due, maxLines: 1, overflow: TextOverflow.ellipsis)),
          Text('  ·  ', style: TextStyle(color: muted)),
          Text('in ${shortCountdown(now, result.dueAt, precision: settings.precision)}',
              style: TextStyle(color: theme.colorScheme.primary, fontFeatures: tabularFigures)),
        ]);
      case QuickAddFailed(:final error, :final detail):
        final message = switch (error) {
          QuickAddError.empty => '',
          QuickAddError.noDate => 'Add a date, e.g. "tomorrow 5pm" or "Oct 24"',
          QuickAddError.noTitle => 'Add a name before or after the date',
          QuickAddError.inPast => 'That time has already passed',
          QuickAddError.unknownGroup => 'No group named "#$detail"',
        };
        return Row(children: [
          Icon(Icons.info_outline_rounded, size: 14, color: muted),
          const SizedBox(width: 6),
          Flexible(child: Text(message, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: muted))),
        ]);
    }
  }
}
