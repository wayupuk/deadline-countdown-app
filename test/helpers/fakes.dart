import 'dart:async';

import 'package:deadlines/core/models.dart';
import 'package:deadlines/data/repository.dart';
import 'package:deadlines/state/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// In-memory repository for widget tests (no database timers).
class FakeRepository implements DeadlineRepository {
  final deadlines = <Deadline>[];
  final groups = <Group>[];
  final _changes = StreamController<void>.broadcast();

  Stream<List<T>> _watch<T>(List<T> Function() read) async* {
    yield read();
    await for (final _ in _changes.stream) {
      yield read();
    }
  }

  @override
  Stream<List<Deadline>> watchDeadlines() => _watch(() => deadlines.where((d) => d.deletedAt == null).toList());
  @override
  Stream<List<Group>> watchGroups() => _watch(() => groups.where((g) => g.deletedAt == null).toList());

  @override
  Future<void> saveDeadline(Deadline d) async {
    deadlines.removeWhere((x) => x.id == d.id);
    deadlines.add(d);
    _changes.add(null);
  }

  @override
  Future<void> deleteDeadline(String id) async {
    deadlines.removeWhere((x) => x.id == id);
    _changes.add(null);
  }

  @override
  Future<Group> createGroup(String name, DeadlineColor color, {int sortOrder = 0}) async {
    final now = DateTime.now().toUtc();
    final g = Group(id: 'g${groups.length + 1}', name: name, color: color, sortOrder: sortOrder, createdAt: now, updatedAt: now);
    groups.add(g);
    _changes.add(null);
    return g;
  }

  @override
  Future<void> saveGroup(Group g) async {
    groups.removeWhere((x) => x.id == g.id);
    groups.add(g);
    _changes.add(null);
  }

  @override
  Future<int> deleteGroup(String id) async {
    var moved = 0;
    for (var i = 0; i < deadlines.length; i++) {
      if (deadlines[i].groupId == id) {
        deadlines[i] = deadlines[i].copyWith(groupId: null);
        moved++;
      }
    }
    groups.removeWhere((g) => g.id == id);
    _changes.add(null);
    return moved;
  }

  @override
  Future<int> importDeadlines(List<Deadline> list) async {
    var added = 0;
    for (final d in list) {
      if (deadlines.every((x) => x.id != d.id)) {
        deadlines.add(d);
        added++;
      }
    }
    _changes.add(null);
    return added;
  }
}

Deadline sampleDeadline(String title, DateTime due, {Priority priority = Priority.normal, String? groupId}) => Deadline(
    id: title,
    title: title,
    dueAt: due,
    priority: priority,
    groupId: groupId,
    createdAt: DateTime.now().toUtc().subtract(const Duration(days: 30)),
    updatedAt: DateTime.now().toUtc());

/// Pumps [child] inside a ProviderScope wired to [repo] and empty preferences.
Future<void> pumpApp(WidgetTester tester, Widget child, {required FakeRepository repo, Map<String, Object> prefs = const {}}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final sp = await SharedPreferences.getInstance();
  await tester.pumpWidget(ProviderScope(
    overrides: [repositoryProvider.overrideWithValue(repo), sharedPreferencesProvider.overrideWithValue(sp)],
    child: MaterialApp(home: Scaffold(body: child)),
  ));
  await tester.pump();
}
