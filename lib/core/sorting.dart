import 'models.dart';

/// Filter value meaning "deadlines without a group".
const noGroupFilter = '__none__';

/// The filter to apply: a saved filter that names a group which no longer exists means "all".
String? effectiveGroupFilter(String? filter, List<Group> groups) =>
    filter == null || filter == noGroupFilter || groups.any((g) => g.id == filter) ? filter : null;

Iterable<Deadline> _visible(Iterable<Deadline> all, String? groupFilter) => all.where((d) =>
    d.deletedAt == null &&
    (groupFilter == null || (groupFilter == noGroupFilter ? d.groupId == null : d.groupId == groupFilter)));

/// Not yet due: urgent → low, then soonest first.
List<Deadline> upcoming(Iterable<Deadline> all, DateTime now, {String? groupFilter}) =>
    _visible(all, groupFilter).where((d) => !d.isOverdue(now)).toList()
      ..sort((a, b) {
        final byPriority = b.priority.index.compareTo(a.priority.index);
        return byPriority != 0 ? byPriority : a.dueAt.compareTo(b.dueAt);
      });

/// Already due: most recent first.
List<Deadline> past(Iterable<Deadline> all, DateTime now, {String? groupFilter}) =>
    _visible(all, groupFilter).where((d) => d.isOverdue(now)).toList()..sort((a, b) => b.dueAt.compareTo(a.dueAt));

/// The soonest upcoming deadline regardless of priority — what the tray countdown shows.
Deadline? nearest(Iterable<Deadline> all, DateTime now) {
  Deadline? best;
  for (final d in _visible(all, null)) {
    if (!d.isOverdue(now) && (best == null || d.dueAt.isBefore(best.dueAt))) best = d;
  }
  return best;
}
