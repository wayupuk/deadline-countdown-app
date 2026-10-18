import 'package:deadlines/core/year_format.dart';
import 'package:test/test.dart';

void main() {
  test('labels', () {
    expect(yearLabel(2026, buddhist: false), '2026');
    expect(yearLabel(2026, buddhist: true), '2569 BE');
  });

  test('explicit calendar tag wins', () {
    expect(localeUsesBuddhistCalendar('en_TH@calendar=buddhist'), isTrue);
    expect(localeUsesBuddhistCalendar('en_US@calendar=buddhist'), isTrue);
    expect(localeUsesBuddhistCalendar('en_TH@calendar=gregorian'), isFalse);
  });

  test('Thai region defaults to Buddhist (macOS reports en-TH / en_TH)', () {
    expect(localeUsesBuddhistCalendar('en-TH'), isTrue);
    expect(localeUsesBuddhistCalendar('th_TH'), isTrue);
    expect(localeUsesBuddhistCalendar('en_US'), isFalse);
    expect(localeUsesBuddhistCalendar('th'), isFalse);
  });
}
