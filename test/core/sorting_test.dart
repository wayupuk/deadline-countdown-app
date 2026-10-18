import 'package:deadlines/core/models.dart';
import 'package:deadlines/core/sorting.dart';
import 'package:test/test.dart';

Deadline d(String title, DateTime due, {Priority p = Priority.normal, String? group, DateTime? deleted}) => Deadline(
    id: title,
    title: title,
    dueAt: due,
    groupId: group,
    priority: p,
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
    deletedAt: deleted);

void main() {
  final now = DateTime(2026, 10, 18, 12);
  final a = d('a', now.add(const Duration(days: 3)));
  final b = d('b', now.add(const Duration(days: 1)));
  final u = d('u', now.add(const Duration(days: 9)), p: Priority.urgent);
  final h = d('h', now.add(const Duration(days: 5)), p: Priority.high, group: 'g1');
  final old1 = d('old1', now.subtract(const Duration(days: 1)));
  final old3 = d('old3', now.subtract(const Duration(days: 3)));
  final gone = d('gone', now.add(const Duration(days: 2)), deleted: DateTime.utc(2026, 10, 1));
  final all = [a, b, u, h, old1, old3, gone];

  test('upcoming: priority first, then soonest', () {
    expect(upcoming(all, now).map((x) => x.title), ['u', 'h', 'b', 'a']);
  });
  test('past: most recent first', () {
    expect(past(all, now).map((x) => x.title), ['old1', 'old3']);
  });
  test('nearest ignores priority', () {
    expect(nearest(all, now)?.title, 'b');
  });
  test('soft-deleted never listed', () {
    expect(upcoming(all, now).any((x) => x.title == 'gone'), isFalse);
    expect(nearest([gone], now), isNull);
  });
  test('group filter, including No group', () {
    expect(upcoming(all, now, groupFilter: 'g1').map((x) => x.title), ['h']);
    expect(upcoming(all, now, groupFilter: noGroupFilter).map((x) => x.title), ['u', 'b', 'a']);
  });
  test('progress clamps and survives zero span', () {
    final x = Deadline(
        id: 'x',
        title: 'x',
        dueAt: DateTime(2026, 10, 11),
        createdAt: DateTime(2026, 10, 1),
        updatedAt: DateTime(2026, 10, 1));
    expect(x.progress(DateTime(2026, 10, 6)), 0.5);
    expect(x.progress(DateTime(2026, 9, 1)), 0.0);
    expect(x.progress(DateTime(2026, 12, 1)), 1.0);
    final z = x.copyWith(dueAt: x.createdAt);
    expect(z.progress(x.createdAt), 1.0);
    expect(x.isOverdue(DateTime(2026, 10, 11)), isTrue);
  });
}
