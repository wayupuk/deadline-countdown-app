import 'models.dart';

/// Whole units of a non-negative duration. Units truncate, so a countdown never claims more time than is left.
class _Parts {
  _Parts(Duration d) : total = d.isNegative ? 0 : d.inSeconds;
  final int total;
  int get days => total ~/ 86400;
  int get hours => total % 86400 ~/ 3600;
  int get minutes => total % 3600 ~/ 60;
  int get seconds => total % 60;
}

/// "3d 4h" (hours), "3d" (days), "3d 4h 10m" (minutes); also "4h 12m", "12m", "<1m", "Overdue".
/// Starts at the largest non-zero unit and shows `precision.unitCount` units, never finer than minutes.
String shortCountdown(DateTime now, DateTime due, {CountdownPrecision precision = CountdownPrecision.hours}) {
  final left = due.difference(now);
  if (left <= Duration.zero) return 'Overdue';
  final p = _Parts(left);
  final units = [(p.days, 'd'), (p.hours, 'h'), (p.minutes, 'm')];
  final first = units.indexWhere((u) => u.$1 > 0);
  if (first < 0) return '<1m';
  final end = (first + precision.unitCount).clamp(0, units.length);
  return units.sublist(first, end).map((u) => '${u.$1}${u.$2}').join(' ');
}

/// "12d 04:22:51", or "04:22:51" under a day. Past dates show "00:00:00".
String clockCountdown(DateTime now, DateTime due) {
  final p = _Parts(due.difference(now));
  String two(int v) => v.toString().padLeft(2, '0');
  final hms = '${two(p.hours)}:${two(p.minutes)}:${two(p.seconds)}';
  return p.days > 0 ? '${p.days}d $hms' : hms;
}

/// Notification text: "5 days, 3 hours left", "Due now".
String sentenceCountdown(DateTime now, DateTime due) {
  final left = due.difference(now);
  if (left <= Duration.zero) return 'Due now';
  final p = _Parts(left);
  final List<(int, String)> units;
  if (p.days > 0) {
    units = [(p.days, 'day'), (p.hours, 'hour')];
  } else if (p.hours > 0) {
    units = [(p.hours, 'hour'), (p.minutes, 'minute')];
  } else if (p.minutes > 0) {
    units = [(p.minutes, 'minute')];
  } else {
    return 'Less than a minute left';
  }
  final text = units.where((u) => u.$1 > 0).map((u) => '${u.$1} ${u.$2}${u.$1 == 1 ? '' : 's'}').join(', ');
  return '$text left';
}

/// Time until a minute-precision countdown to [nextDue] changes. Countdowns round down, so "23m" becomes
/// "22m" just after 23:00 remains — hence the 10 ms margin. A deadline at 06:59:59 changes at :59 past each
/// minute; with no upcoming deadline, the next wall-clock minute.
Duration untilNextChange(DateTime now, DateTime? nextDue) {
  const margin = Duration(milliseconds: 10);
  final remaining = nextDue?.difference(now) ?? Duration.zero;
  if (remaining > Duration.zero) {
    return Duration(microseconds: remaining.inMicroseconds % Duration.microsecondsPerMinute) + margin;
  }
  final intoMinute = now.microsecondsSinceEpoch % Duration.microsecondsPerMinute;
  return Duration(microseconds: Duration.microsecondsPerMinute - intoMinute) + margin;
}
