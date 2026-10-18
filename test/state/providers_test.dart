import 'package:deadlines/core/models.dart';
import 'package:deadlines/data/database.dart';
import 'package:deadlines/data/repository.dart';
import 'package:deadlines/state/providers.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('nearestProvider follows the repository', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = DeadlineRepository(db);
    final container = ProviderContainer(overrides: [repositoryProvider.overrideWithValue(repo)]);
    addTearDown(() async {
      container.dispose();
      await db.close();
    });
    final sub = container.listen(nearestProvider, (_, __) {});
    final now = DateTime.now();
    Deadline dl(String id, Duration inFuture, Priority p) => Deadline(
        id: id, title: id, dueAt: now.add(inFuture), priority: p, createdAt: now.toUtc(), updatedAt: now.toUtc());
    await repo.saveDeadline(dl('later-urgent', const Duration(days: 5), Priority.urgent));
    await repo.saveDeadline(dl('soon', const Duration(days: 1), Priority.low));
    await container.read(deadlinesProvider.future);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(sub.read()?.id, 'soon');
  });
}
