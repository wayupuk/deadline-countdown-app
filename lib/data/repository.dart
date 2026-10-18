import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../core/models.dart';
import 'database.dart';

/// All reads and writes of deadlines and groups. Deletes are soft (rows keep `deletedAt` for a later sync)
/// and every write stamps `updatedAt`.
class DeadlineRepository {
  DeadlineRepository(this._db, {DateTime Function()? clock}) : _clock = clock ?? (() => DateTime.now().toUtc());

  final AppDatabase _db;
  final DateTime Function() _clock;

  Stream<List<Deadline>> watchDeadlines() => (_db.select(_db.deadlines)..where((t) => t.deletedAt.isNull()))
      .watch()
      .map((rows) => rows.map(_toDeadline).toList());

  Stream<List<Group>> watchGroups() => (_db.select(_db.groups)
        ..where((t) => t.deletedAt.isNull())
        ..orderBy([(t) => OrderingTerm.asc(t.sortOrder), (t) => OrderingTerm.asc(t.name)]))
      .watch()
      .map((rows) => rows.map(_toGroup).toList());

  Future<void> saveDeadline(Deadline d) => _db.into(_db.deadlines).insertOnConflictUpdate(DeadlinesCompanion.insert(
      id: d.id,
      title: d.title,
      dueAt: d.dueAt.toUtc(),
      groupId: Value(d.groupId),
      priority: Value(d.priority.name),
      notes: Value(d.notes),
      reminderEnabled: Value(d.reminderEnabled),
      reminderHour: Value(d.reminderHour),
      reminderMinute: Value(d.reminderMinute),
      createdAt: d.createdAt.toUtc(),
      updatedAt: _clock(),
      deletedAt: Value(d.deletedAt?.toUtc())));

  Future<void> deleteDeadline(String id) => (_db.update(_db.deadlines)..where((t) => t.id.equals(id)))
      .write(DeadlinesCompanion(deletedAt: Value(_clock()), updatedAt: Value(_clock())));

  Future<Group> createGroup(String name, DeadlineColor color, {int sortOrder = 0}) async {
    final now = _clock();
    final g = Group(
        id: const Uuid().v4(), name: name.trim(), color: color, sortOrder: sortOrder, createdAt: now, updatedAt: now);
    await saveGroup(g);
    return g;
  }

  Future<void> saveGroup(Group g) => _db.into(_db.groups).insertOnConflictUpdate(GroupsCompanion.insert(
      id: g.id,
      name: g.name,
      color: g.color.name,
      sortOrder: Value(g.sortOrder),
      createdAt: g.createdAt.toUtc(),
      updatedAt: _clock(),
      deletedAt: Value(g.deletedAt?.toUtc())));

  /// Soft-deletes the group; its deadlines move to "No group". Returns how many moved.
  Future<int> deleteGroup(String id) => _db.transaction(() async {
        final moved = await (_db.update(_db.deadlines)..where((t) => t.groupId.equals(id)))
            .write(DeadlinesCompanion(groupId: const Value(null), updatedAt: Value(_clock())));
        await (_db.update(_db.groups)..where((t) => t.id.equals(id)))
            .write(GroupsCompanion(deletedAt: Value(_clock()), updatedAt: Value(_clock())));
        return moved;
      });

  /// Adds deadlines whose ids aren't stored yet (re-importing is harmless). Returns how many were added.
  Future<int> importDeadlines(List<Deadline> list) => _db.transaction(() async {
        var added = 0;
        for (final d in list) {
          final exists = await (_db.select(_db.deadlines)..where((t) => t.id.equals(d.id))).getSingleOrNull();
          if (exists == null) {
            await saveDeadline(d);
            added++;
          }
        }
        return added;
      });

  Deadline _toDeadline(DeadlineRow r) => Deadline(
      id: r.id,
      title: r.title,
      dueAt: r.dueAt.toLocal(),
      groupId: r.groupId,
      priority: Priority.values.byName(r.priority),
      notes: r.notes,
      reminderEnabled: r.reminderEnabled,
      reminderHour: r.reminderHour,
      reminderMinute: r.reminderMinute,
      createdAt: r.createdAt.toUtc(),
      updatedAt: r.updatedAt.toUtc(),
      deletedAt: r.deletedAt?.toUtc());

  Group _toGroup(GroupRow r) => Group(
      id: r.id,
      name: r.name,
      color: DeadlineColor.values.byName(r.color),
      sortOrder: r.sortOrder,
      createdAt: r.createdAt.toUtc(),
      updatedAt: r.updatedAt.toUtc(),
      deletedAt: r.deletedAt?.toUtc());
}
