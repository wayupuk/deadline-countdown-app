import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/countdown.dart';
import '../../core/date_format.dart';
import '../../core/models.dart';
import '../../state/providers.dart';
import '../theme.dart';

/// One upcoming deadline: group color stripe, title, due date, priority, live countdown and progress.
class CountdownCard extends ConsumerStatefulWidget {
  const CountdownCard({super.key, required this.deadline, this.onTap, this.selected = false});

  final Deadline deadline;
  final VoidCallback? onTap;
  final bool selected;

  @override
  ConsumerState<CountdownCard> createState() => _CountdownCardState();
}

class _CountdownCardState extends ConsumerState<CountdownCard> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // The seconds clock ticks every second; everything else follows the shared minute clock.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final d = widget.deadline;
    final groups = ref.watch(groupsProvider).value ?? const <Group>[];
    final settings = ref.watch(settingsProvider);
    final tint = tintFor(d, groups);
    final now = DateTime.now();
    final muted = theme.colorScheme.onSurfaceVariant;

    return Card(
      color: widget.selected ? tint.withValues(alpha: 0.12) : null,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Container(width: 4, height: 52, decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(
                      child: Text(d.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600))),
                  const SizedBox(width: 6),
                  PriorityBadge(d.priority),
                ]),
                const SizedBox(height: 2),
                Text(dueLabel(d.dueAt, now: now, buddhist: settings.buddhistYears),
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall?.copyWith(color: muted)),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                      value: d.progress(now), minHeight: 3, color: tint, backgroundColor: tint.withValues(alpha: 0.15)),
                ),
              ]),
            ),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(shortCountdown(now, d.dueAt, precision: settings.precision),
                  style: theme.textTheme.titleMedium
                      ?.copyWith(color: tint, fontWeight: FontWeight.w700, fontFeatures: tabularFigures)),
              Text(clockCountdown(now, d.dueAt),
                  style: theme.textTheme.labelSmall?.copyWith(color: muted, fontFeatures: tabularFigures)),
            ]),
          ]),
        ),
      ),
    );
  }
}
