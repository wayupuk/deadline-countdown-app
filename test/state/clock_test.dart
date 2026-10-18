import 'dart:async';

import 'package:deadlines/state/clock.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('schedules next tick for the nearest deadline boundary', () {
    final delays = <Duration>[];
    final now = DateTime(2026, 10, 18, 16, 37, 10);
    final ticker = MinuteTicker(
        now: () => now,
        schedule: (d, cb) {
          delays.add(d);
          return null;
        },
        nextDue: () => DateTime(2026, 10, 18, 17, 59, 59));
    ticker.start((_) {});
    expect(delays.single.inMilliseconds, closeTo(49010, 20));
  });

  test('each tick reports the time and re-arms; stop cancels', () {
    final callbacks = <void Function()>[];
    final ticks = <DateTime>[];
    var now = DateTime(2026, 10, 18, 16, 37);
    final ticker = MinuteTicker(
        now: () => now,
        schedule: (d, cb) {
          callbacks.add(cb);
          return null;
        },
        nextDue: () => null);
    ticker.start(ticks.add);
    now = now.add(const Duration(minutes: 1));
    callbacks.last();
    expect(ticks, [now]);
    expect(callbacks.length, 2); // re-armed
    ticker.poke();
    expect(ticks.length, 2);
    ticker.stop();
  });

  test('real timer fires', () async {
    final fired = Completer<void>();
    final ticker = MinuteTicker(nextDue: () => DateTime.now().add(const Duration(milliseconds: 50)));
    ticker.start((_) => fired.isCompleted ? null : fired.complete());
    await fired.future.timeout(const Duration(seconds: 2));
    ticker.stop();
  });
}
