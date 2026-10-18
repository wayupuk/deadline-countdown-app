import 'package:deadlines/core/countdown.dart';
import 'package:deadlines/core/models.dart';
import 'package:test/test.dart';

void main() {
  final now = DateTime(2026, 10, 18, 12);
  Duration dhms(int d, [int h = 0, int m = 0, int s = 0]) => Duration(days: d, hours: h, minutes: m, seconds: s);

  test('short, default hours precision', () {
    expect(shortCountdown(now, now.add(dhms(3, 4, 10))), '3d 4h');
    expect(shortCountdown(now, now.add(dhms(0, 4, 12))), '4h 12m');
    expect(shortCountdown(now, now.add(dhms(0, 0, 12, 30))), '12m');
    expect(shortCountdown(now, now.add(dhms(0, 0, 0, 30))), '<1m');
    expect(shortCountdown(now, now), 'Overdue');
    expect(shortCountdown(now, now.subtract(dhms(0, 1))), 'Overdue');
  });

  test('short precision', () {
    final far = now.add(dhms(3, 4, 10, 30));
    expect(shortCountdown(now, far, precision: CountdownPrecision.days), '3d');
    expect(shortCountdown(now, now.add(dhms(0, 4, 12, 30)), precision: CountdownPrecision.days), '4h');
    expect(shortCountdown(now, far, precision: CountdownPrecision.minutes), '3d 4h 10m');
    expect(shortCountdown(now, now.add(dhms(3, 0, 10)), precision: CountdownPrecision.minutes), '3d 0h 10m');
    expect(shortCountdown(now, now.add(dhms(0, 0, 12, 30)), precision: CountdownPrecision.minutes), '12m');
  });

  test('clock', () {
    expect(clockCountdown(now, now.add(dhms(12, 4, 22, 51))), '12d 04:22:51');
    expect(clockCountdown(now, now.add(dhms(0, 4, 22, 51))), '04:22:51');
    expect(clockCountdown(now, now.subtract(dhms(0, 0, 0, 10))), '00:00:00');
  });

  test('sentence', () {
    final t = DateTime(2026, 10, 18, 9);
    expect(sentenceCountdown(t, t.add(dhms(5, 3))), '5 days, 3 hours left');
    expect(sentenceCountdown(t, t.add(dhms(1))), '1 day left');
    expect(sentenceCountdown(t, t.add(dhms(1, 1))), '1 day, 1 hour left');
    expect(sentenceCountdown(t, t.add(dhms(0, 3, 5))), '3 hours, 5 minutes left');
    expect(sentenceCountdown(t, t.add(dhms(0, 2))), '2 hours left');
    expect(sentenceCountdown(t, t.add(dhms(0, 0, 1))), '1 minute left');
    expect(sentenceCountdown(t, t.add(dhms(0, 0, 0, 20))), 'Less than a minute left');
    expect(sentenceCountdown(t, t), 'Due now');
  });

  test('untilNextChange', () {
    final base = DateTime(2026, 10, 18, 16, 37);
    bool near(Duration a, double secs) => (a.inMicroseconds / 1e6 - secs).abs() < 0.05;
    expect(near(untilNextChange(base.add(const Duration(milliseconds: 12500)), null), 47.5), isTrue);
    expect(near(untilNextChange(base, DateTime(2026, 10, 18, 17)), 0), isTrue);
    expect(untilNextChange(base, DateTime(2026, 10, 18, 17)) > Duration.zero, isTrue);
    expect(near(untilNextChange(base.add(const Duration(seconds: 10)), DateTime(2026, 10, 18, 17, 59, 59)), 49), isTrue);
    final due = DateTime(2026, 10, 18, 17, 59, 59);
    final start = base.add(const Duration(seconds: 10));
    final tick = start.add(untilNextChange(start, due));
    expect(shortCountdown(start, due, precision: CountdownPrecision.minutes),
        isNot(shortCountdown(tick, due, precision: CountdownPrecision.minutes)));
  });
}
