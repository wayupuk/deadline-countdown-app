import 'dart:async';

import '../core/countdown.dart';

/// Starts a timer; returns it so it can be cancelled (tests may return null).
typedef Scheduler = Timer? Function(Duration delay, void Function() callback);

/// Calls back exactly when the nearest countdown's minute changes, then re-arms. `poke()` re-plans
/// immediately (after edits, waking from sleep, or a new day).
class MinuteTicker {
  MinuteTicker({DateTime Function()? now, Scheduler? schedule, required this.nextDue})
      : _now = now ?? DateTime.now,
        _schedule = schedule ?? ((d, cb) => Timer(d, cb));

  final DateTime Function() _now;
  final Scheduler _schedule;
  final DateTime? Function() nextDue;
  Timer? _active;
  void Function(DateTime now)? _onTick;

  void start(void Function(DateTime now) onTick) {
    _onTick = onTick;
    _arm();
  }

  void poke() {
    _active?.cancel();
    _onTick?.call(_now());
    _arm();
  }

  void stop() {
    _active?.cancel();
    _active = null;
    _onTick = null;
  }

  void _arm() {
    _active = _schedule(untilNextChange(_now(), nextDue()), () {
      _onTick?.call(_now());
      if (_onTick != null) _arm();
    });
  }
}
