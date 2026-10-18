import 'package:flutter/material.dart';

import '../core/models.dart';

/// Apple-like system colors, readable in light and dark mode.
const _palette = {
  DeadlineColor.blue: Color(0xFF0A84FF),
  DeadlineColor.purple: Color(0xFFBF5AF2),
  DeadlineColor.pink: Color(0xFFFF375F),
  DeadlineColor.red: Color(0xFFFF453A),
  DeadlineColor.orange: Color(0xFFFF9F0A),
  DeadlineColor.yellow: Color(0xFFFFD60A),
  DeadlineColor.green: Color(0xFF30D158),
  DeadlineColor.teal: Color(0xFF64D2FF),
  DeadlineColor.graphite: Color(0xFF8E8E93),
};

Color colorOf(DeadlineColor c) => _palette[c]!;

Group? groupOf(Deadline d, List<Group> groups) => groups.where((g) => g.id == d.groupId).firstOrNull;

/// The deadline's group color; "No group" is graphite.
Color tintFor(Deadline d, List<Group> groups) => colorOf(groupOf(d, groups)?.color ?? DeadlineColor.graphite);

String priorityLabel(Priority p) => switch (p) {
      Priority.low => 'Low',
      Priority.normal => 'Normal',
      Priority.high => 'High',
      Priority.urgent => 'Urgent',
    };

/// Only High and Urgent get a visible badge.
Color? priorityColor(Priority p) => switch (p) {
      Priority.high => _palette[DeadlineColor.orange],
      Priority.urgent => _palette[DeadlineColor.red],
      _ => null,
    };

const tabularFigures = [FontFeature.tabularFigures()];

ThemeData buildTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF5E5CE6), brightness: brightness);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    visualDensity: VisualDensity.adaptivePlatformDensity,
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14), side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5))),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHigh,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: scheme.primary, width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
    dialogTheme: DialogThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
  );
}

/// Small capsule for High / Urgent; nothing for Low / Normal.
class PriorityBadge extends StatelessWidget {
  const PriorityBadge(this.priority, {super.key});
  final Priority priority;

  @override
  Widget build(BuildContext context) {
    final color = priorityColor(priority);
    if (color == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(6)),
      child: Text(priorityLabel(priority),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w700)),
    );
  }
}
