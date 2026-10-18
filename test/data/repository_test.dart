import 'dart:io';

import 'package:deadlines/core/models.dart';
import 'package:deadlines/data/database.dart';
import 'package:deadlines/data/repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late DeadlineRepository repo;
  var t = DateTime.utc(2026, 10, 18, 12);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = DeadlineRepository(db, clock: () => t);
  });
  tearDown(() => db.close());

  Deadline dl(String id, {String? group}) => Deadline(
      id: id,
      title: id,
      dueAt: DateTime.utc(2026, 12, 1),
      groupId: group,
      createdAt: DateTime.utc(2026, 10, 1),
      updatedAt: DateTime.utc(2026, 10, 1));

  test('save, update stamps updatedAt, soft delete hides', () async {
    await repo.saveDeadline(dl('a'));
    t = t.add(const Duration(minutes: 5));
    await repo.saveDeadline(dl('a').copyWith(title: 'A2'));
    var list = await repo.watchDeadlines().first;
    expect(list.single.title, 'A2');
    expect(list.single.updatedAt, t);
    await repo.deleteDeadline('a');
    list = await repo.watchDeadlines().first;
    expect(list, isEmpty);
    final raw = await db.select(db.deadlines).get();
    expect(raw.single.deletedAt, isNotNull); // kept for sync
  });

  test('round-trips every field', () async {
    final d = Deadline(
        id: 'full',
        title: 'Full',
        dueAt: DateTime(2026, 12, 1, 17, 30),
        groupId: 'g',
        priority: Priority.urgent,
        notes: 'n',
        reminderEnabled: false,
        reminderHour: 7,
        reminderMinute: 45,
        createdAt: DateTime.utc(2026, 10, 1, 8),
        updatedAt: DateTime.utc(2026, 10, 1, 8));
    await repo.saveDeadline(d);
    final back = (await repo.watchDeadlines().first).single;
    expect((back.title, back.dueAt, back.groupId, back.priority, back.notes),
        ('Full', DateTime(2026, 12, 1, 17, 30), 'g', Priority.urgent, 'n'));
    expect((back.reminderEnabled, back.reminderHour, back.reminderMinute), (false, 7, 45));
    expect(back.createdAt.isAtSameMomentAs(d.createdAt), isTrue);
  });

  test('deleting a group keeps its deadlines', () async {
    final g = await repo.createGroup('Physics', DeadlineColor.teal);
    await repo.saveDeadline(dl('x', group: g.id));
    await repo.saveDeadline(dl('y', group: g.id));
    expect(await repo.deleteGroup(g.id), 2);
    final list = await repo.watchDeadlines().first;
    expect(list.map((d) => d.groupId), [null, null]);
    expect(await repo.watchGroups().first, isEmpty);
  });

  test('import skips existing ids', () async {
    await repo.saveDeadline(dl('a'));
    expect(await repo.importDeadlines([dl('a'), dl('b')]), 1);
  });

  test('corrupt file is moved aside', () async {
    final dir = await Directory.systemTemp.createTemp('dl');
    final file = File('${dir.path}/deadlines.db')..writeAsStringSync('not a database');
    final result = await AppDatabase.openAt(file);
    expect(result.recoveredFrom, isNotNull);
    expect(File(result.recoveredFrom!).existsSync(), isTrue);
    expect(await DeadlineRepository(result.db).watchDeadlines().first, isEmpty);
    await result.db.close();
  });
}
