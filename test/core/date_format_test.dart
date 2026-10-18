import 'package:deadlines/core/date_format.dart';
import 'package:test/test.dart';

void main() {
  final now = DateTime(2026, 10, 18, 12);

  test('due label: same year omits the year, 24-hour time', () {
    expect(dueLabel(DateTime(2026, 10, 24, 17), now: now, buddhist: false), 'Sat, 24 Oct at 17:00');
    expect(dueLabel(DateTime(2026, 11, 5, 7, 30), now: now, buddhist: true), 'Thu, 5 Nov at 07:30');
  });

  test('due label: other years show the year, BE when asked', () {
    expect(dueLabel(DateTime(2027, 2, 10, 6, 59), now: now, buddhist: false), 'Wed, 10 Feb 2027 at 06:59');
    expect(dueLabel(DateTime(2027, 2, 10, 6, 59), now: now, buddhist: true), 'Wed, 10 Feb 2570 at 06:59');
  });

  test('month title', () {
    expect(monthTitle(DateTime(2026, 10), buddhist: false), ('October', '2026'));
    expect(monthTitle(DateTime(2026, 10), buddhist: true), ('October', '2569 BE'));
  });

  test('long due label for detail views', () {
    expect(dueLabelLong(DateTime(2026, 10, 24, 17), buddhist: true), 'Saturday, 24 October 2569 at 17:00');
  });
}
