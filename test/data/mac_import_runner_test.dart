import 'package:deadlines/data/mac_import_runner.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fakes.dart';

const _valid = '[{"createdAt":813110400,"dueDate":915234400,"id":"A","notes":"","reminderEnabled":true,'
    '"reminderHour":9,"reminderMinute":0,"title":"Report"}]';

void main() {
  test('imports and reports the count', () async {
    final repo = FakeRepository();
    final notice = await importMacDeadlines(read: () async => _valid, repo: repo);
    expect(notice, 'Imported 1 deadline from the Mac app.');
    expect(repo.deadlines.single.title, 'Report');
  });

  test('an unreadable file gives a notice instead of crashing', () async {
    final notice = await importMacDeadlines(read: () async => throw const FileSystemExceptionStub(), repo: FakeRepository());
    expect(notice, "Couldn't read the Mac app's deadlines, so nothing was imported.");
  });

  test('unexpected field types give a notice instead of crashing', () async {
    final notice = await importMacDeadlines(
        read: () async => '[{"id":"A","title":"x","dueDate":1,"createdAt":1,"reminderHour":"nine"}]', repo: FakeRepository());
    expect(notice, "Couldn't read the Mac app's deadlines, so nothing was imported.");
  });
}

class FileSystemExceptionStub implements Exception {
  const FileSystemExceptionStub();
}
