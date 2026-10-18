import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/services.dart';

/// Android: shown while "Alarms & reminders" is off. Dismissible for the session.
class ExactAlarmsBanner extends ConsumerStatefulWidget {
  const ExactAlarmsBanner({super.key});

  @override
  ConsumerState<ExactAlarmsBanner> createState() => _ExactAlarmsBannerState();
}

class _ExactAlarmsBannerState extends ConsumerState<ExactAlarmsBanner> {
  var _dismissed = false;

  @override
  Widget build(BuildContext context) {
    if (_dismissed || ref.watch(exactAlarmsProvider)) return const SizedBox.shrink();
    final theme = Theme.of(context);
    const orange = Color(0xFFFF9F0A);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      decoration: BoxDecoration(color: orange.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        const Icon(Icons.alarm_off_rounded, color: orange, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Reminders may arrive late', maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.labelLarge),
            Text('Allow "Alarms & reminders" so they come on time.',
                maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
          ]),
        ),
        TextButton(onPressed: () => ref.read(exactAlarmsProvider.notifier).request(), child: const Text('Allow')),
        IconButton(
            tooltip: 'Not now', icon: const Icon(Icons.close_rounded, size: 18), onPressed: () => setState(() => _dismissed = true)),
      ]),
    );
  }
}
