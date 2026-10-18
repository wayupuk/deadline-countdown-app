import 'package:deadlines/core/quick_add/date_grammar.dart';
import 'package:test/test.dart';

void main() {
  final now = DateTime(2026, 10, 18, 17, 0); // Sunday

  void expectDate(String text, DateTime value, {bool? hasTime, String? matched}) {
    final m = findDate(text, now);
    expect(m, isNotNull, reason: text);
    expect(m!.value, value, reason: text);
    if (hasTime != null) expect(m.hasTime, hasTime, reason: text);
    if (matched != null) expect(text.substring(m.start, m.end), matched, reason: text);
  }

  test('month names', () {
    expectDate('Thesis Oct 24 5pm', DateTime(2026, 10, 24, 17), hasTime: true, matched: 'Oct 24 5pm');
    expectDate('Launch 24 Oct 2030', DateTime(2030, 10, 24), hasTime: false);
    expectDate('Party October 24th at 18:30', DateTime(2026, 10, 24, 18, 30));
    expectDate('Fly Wed, Feb 10 2027 7am', DateTime(2027, 2, 10, 7));
  });

  test('year rolls forward when no year and date passed', () {
    expectDate('Renew Jan 5', DateTime(2027, 1, 5), hasTime: false);
  });

  test('numeric day/month', () {
    expectDate('Exam 24/10 14:00', DateTime(2026, 10, 24, 14));
    expectDate('Exam 24/10/2026', DateTime(2026, 10, 24));
  });

  test('Buddhist-era years and Thai months', () {
    expectDate('Exam 24/10/2573 14:00', DateTime(2030, 10, 24, 14));
    expectDate('Final 25 ธ.ค.', DateTime(2026, 12, 25));
    expectDate('Final 25 ธันวาคม 2569', DateTime(2026, 12, 25));
  });

  test('ISO and JavaScript formats convert offsets to local', () {
    final js = DateTime.utc(2027, 2, 9, 23, 59, 59).toLocal(); // 06:59:59 at +07:00
    expectDate('Thesis 2027-02-10T06:59:59+07:00', js, hasTime: true);
    expectDate('Thesis Wed Feb 10 2027 06:59:59 GMT+0700 (Indochina Time)', js,
        matched: 'Wed Feb 10 2027 06:59:59 GMT+0700 (Indochina Time)');
    expectDate('Kickoff 2026-11-02', DateTime(2026, 11, 2), hasTime: false);
  });

  test('relative words', () {
    expectDate('Tax tomorrow 9am', DateTime(2026, 10, 19, 9));
    expectDate('Dentist next friday', DateTime(2026, 10, 23), hasTime: false);
    expectDate('Dentist friday', DateTime(2026, 10, 23));
    expectDate('Report in 3 days', DateTime(2026, 10, 21), hasTime: false);
    expectDate('Report in 2 weeks', DateTime(2026, 11, 1));
    expectDate('Meeting tonight', DateTime(2026, 10, 18, 20), hasTime: true);
    expectDate('Call today 6pm', DateTime(2026, 10, 18, 18));
    expectDate('Call 6pm', DateTime(2026, 10, 18, 18), hasTime: true);
  });

  test('24h clock: 7:30 without am/pm is morning', () {
    expectDate('Flight Nov 5 at 7:30', DateTime(2026, 11, 5, 7, 30));
    expectDate('Flight Nov 5 7:30pm', DateTime(2026, 11, 5, 19, 30));
    expectDate('Lunch Nov 5 noon', DateTime(2026, 11, 5, 12));
    expectDate('Launch Nov 5 12am', DateTime(2026, 11, 5, 0));
  });

  test('month names inside ordinary words are not dates', () {
    expect(findDate('Grammar 2 homework', now), isNull);
    expect(findDate('Room 24 Octopus tank', now), isNull);
    expect(findDate('Mayday 5', now), isNull);
  });

  test('no date', () {
    expect(findDate('Buy groceries', now), isNull);
    expect(findDate('Room 24', now), isNull);
  });
}
