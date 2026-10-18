import 'package:deadlines/core/mac_import.dart';
import 'package:test/test.dart';

const sample = '''[{"color":"purple","createdAt":813110400.5,"dueDate":815234400,"id":"79E58A31-1B32-4203-A3FC-55F05D35421C",
"notes":"chapter 3","reminderEnabled":true,"reminderHour":8,"reminderMinute":30,"title":"Final report"}]''';

void main() {
  test('reads the SwiftUI app format (seconds since 2001)', () {
    final list = parseMacDeadlines(sample, DateTime.utc(2026, 10, 18));
    expect(list, hasLength(1));
    final d = list.single;
    expect(d.id, '79E58A31-1B32-4203-A3FC-55F05D35421C');
    expect(d.title, 'Final report');
    expect(d.dueAt, DateTime.utc(2001).add(const Duration(seconds: 815234400)));
    expect(d.createdAt, DateTime.utc(2001).add(const Duration(microseconds: 813110400500000)));
    expect((d.reminderHour, d.reminderMinute, d.reminderEnabled, d.notes), (8, 30, true, 'chapter 3'));
    expect(d.groupId, isNull);
    expect(d.updatedAt, DateTime.utc(2026, 10, 18));
  });

  test('bad JSON throws FormatException', () {
    expect(() => parseMacDeadlines('not json', DateTime.utc(2026)), throwsFormatException);
    expect(() => parseMacDeadlines('[{"title": 3}]', DateTime.utc(2026)), throwsFormatException);
  });
}
