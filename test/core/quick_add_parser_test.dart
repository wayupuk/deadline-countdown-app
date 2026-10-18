import 'package:deadlines/core/models.dart';
import 'package:deadlines/core/quick_add/quick_add_parser.dart';
import 'package:test/test.dart';

void main() {
  final now = DateTime(2026, 10, 18, 17);

  QuickAddResult ok(String text, {Set<String> groups = const {}}) {
    final r = parseQuickAdd(text, now, groupNames: groups);
    if (r is! QuickAddOk) fail('$text → $r');
    return r.result;
  }

  QuickAddError err(String text, {Set<String> groups = const {}}) =>
      (parseQuickAdd(text, now, groupNames: groups) as QuickAddFailed).error;

  test('title and date', () {
    final r = ok('Thesis submission Oct 24 2030 5pm');
    expect(r.title, 'Thesis submission');
    expect(r.dueAt, DateTime(2030, 10, 24, 17));
    expect(r.hasExplicitTime, isTrue);
  });

  test('no time → 23:59', () {
    final r = ok('Launch 24 Oct 2030');
    expect(r.dueAt, DateTime(2030, 10, 24, 23, 59));
    expect(r.hasExplicitTime, isFalse);
  });

  test('connector words and punctuation', () {
    expect(ok('Thesis on 24 Oct 2030 at 18:30').title, 'Thesis');
    expect(ok('Report due by 30 Oct 2030').title, 'Report');
    expect(ok('Pay before Dec 1 2030 10am').title, 'Pay');
    expect(ok('Essay by Oct 25 2030 5pm').title, 'Essay');
    expect(ok('Submit Oct 24 2030 thesis').title, 'Submit thesis');
    expect(ok('Oct 24 2030 9am: call mom').title, 'call mom');
    expect(ok('Dr. Smith, follow-up - Oct 24 2030 5pm').title, 'Dr. Smith, follow-up');
    expect(ok('Thesis (draft 2) Oct 24 2030 5pm').title, 'Thesis (draft 2)');
  });

  test('JavaScript format with zone name', () {
    final r = ok('Thesis Sun Feb 10 2030 06:59:59 GMT+0700 (Indochina Time)');
    expect(r.title, 'Thesis');
    expect(r.dueAt, DateTime.utc(2030, 2, 9, 23, 59, 59).toLocal());
    expect(ok('Sun Feb 10 2030 06:59:59 GMT+0700 (Indochina Time) Thesis').title, 'Thesis');
  });

  test('priority markers and #group', () {
    final r = ok('Lab report Oct 24 2030 5pm !! #physics', groups: {'Physics', 'Work'});
    expect(r.title, 'Lab report');
    expect(r.priority, Priority.urgent);
    expect(r.groupName, 'Physics');
    expect(ok('Essay ! Oct 24 2030').priority, Priority.high);
    expect(ok('Essay Oct 24 2030').priority, isNull);
    expect(err('Essay Oct 24 2030 #chem', groups: {'Physics'}), QuickAddError.unknownGroup);
  });

  test('errors', () {
    expect(err('   '), QuickAddError.empty);
    expect(err('Buy groceries'), QuickAddError.noDate);
    expect(err('Oct 24 2030 5pm'), QuickAddError.noTitle);
    expect(err('Sun Feb 10 2030 06:59:59 GMT+0700 (Indochina Time)'), QuickAddError.noTitle);
    expect(err('Old thing Jan 5 2020'), QuickAddError.inPast);
    expect(err('Call 3pm'), QuickAddError.inPast); // today 15:00 already passed at 17:00
  });
}
