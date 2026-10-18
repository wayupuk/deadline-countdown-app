/// Finds a date (and optional time) phrase inside free text, e.g. "Thesis Oct 24 5pm".
///
/// Supported: month names (English, Thai abbreviations and full names), day/month numbers (day first), ISO 8601,
/// JavaScript `Date.toString()` output, relative words (today, tonight, tomorrow, weekdays, in N days/weeks,
/// next week), Buddhist-era years, and times (5pm, 17:00, noon, midnight; HH:MM without am/pm is 24-hour).
library;

class DateMatch {
  const DateMatch(this.start, this.end, this.value, {required this.hasTime});

  /// Character range of the phrase in the input.
  final int start, end;
  final DateTime value;

  /// False when only a day was given (caller decides the time).
  final bool hasTime;
}

const _months = {
  'jan': 1, 'january': 1, 'feb': 2, 'february': 2, 'mar': 3, 'march': 3, 'apr': 4, 'april': 4, 'may': 5,
  'jun': 6, 'june': 6, 'jul': 7, 'july': 7, 'aug': 8, 'august': 8, 'sep': 9, 'sept': 9, 'september': 9,
  'oct': 10, 'october': 10, 'nov': 11, 'november': 11, 'dec': 12, 'december': 12,
  'ม.ค.': 1, 'มกราคม': 1, 'ก.พ.': 2, 'กุมภาพันธ์': 2, 'มี.ค.': 3, 'มีนาคม': 3, 'เม.ย.': 4, 'เมษายน': 4,
  'พ.ค.': 5, 'พฤษภาคม': 5, 'มิ.ย.': 6, 'มิถุนายน': 6, 'ก.ค.': 7, 'กรกฎาคม': 7, 'ส.ค.': 8, 'สิงหาคม': 8,
  'ก.ย.': 9, 'กันยายน': 9, 'ต.ค.': 10, 'ตุลาคม': 10, 'พ.ย.': 11, 'พฤศจิกายน': 11, 'ธ.ค.': 12, 'ธันวาคม': 12,
};

const _weekdays = {
  'mon': 1, 'monday': 1, 'tue': 2, 'tues': 2, 'tuesday': 2, 'wed': 3, 'wednesday': 3, 'thu': 4, 'thur': 4,
  'thurs': 4, 'thursday': 4, 'fri': 5, 'friday': 5, 'sat': 6, 'saturday': 6, 'sun': 7, 'sunday': 7,
};

/// Longest first, so "october" wins over "oct".
String _alt(Iterable<String> words) =>
    (words.toList()..sort((a, b) => b.length.compareTo(a.length))).map(RegExp.escape).join('|');

final _monthAlt = _alt(_months.keys);
final _weekdayAlt = _alt(_weekdays.keys);

// Letter guards keep "Grammar 2" from reading as "mar 2" and "24 Octopus" as "24 Oct".
const _noLetterBefore = r'(?<![A-Za-z])';
const _noLetterAfter = r'(?![A-Za-z])';
const _year = r'(\d{4})';
const _time =
    r'(?:at\s+)?(?:(\d{1,2}):(\d{2})(?::(\d{2}))?\s*(am|pm|a\.m\.|p\.m\.)?|(\d{1,2})\s*(am|pm|a\.m\.|p\.m\.)|(noon|midnight))';

final _js = RegExp(
    '$_noLetterBefore(?:$_weekdayAlt)\\s+($_monthAlt)\\s+(\\d{1,2})\\s+$_year\\s+(\\d{2}):(\\d{2}):(\\d{2})\\s+GMT([+-])(\\d{2})(\\d{2})(?:\\s*\\([^()]*\\))?',
    caseSensitive: false);
final _iso = RegExp(r'(?<!\d)(\d{4})-(\d{2})-(\d{2})(?:[T ](\d{2}):(\d{2})(?::(\d{2}))?(Z|[+-]\d{2}:?\d{2})?)?');
final _monthFirst = RegExp(
    '(?:$_noLetterBefore(?:$_weekdayAlt),?\\s+)?$_noLetterBefore($_monthAlt)\\.?$_noLetterAfter\\s*(\\d{1,2})(?:st|nd|rd|th)?(?:,?\\s+$_year)?(?![\\d:])',
    caseSensitive: false);
final _dayFirst = RegExp(
    '(?<![\\d/])(\\d{1,2})(?:st|nd|rd|th)?\\s+$_noLetterBefore($_monthAlt)\\.?$_noLetterAfter(?:\\s+$_year)?(?![\\d:])',
    caseSensitive: false);
final _numeric = RegExp(r'(?<![\d/])(\d{1,2})/(\d{1,2})(?:/(\d{2,4}))?(?![\d/])');
final _relative = RegExp(
    '\\b(today|tonight|tomorrow|next week)\\b|\\b(?:(this|next)\\s+)?($_weekdayAlt)\\b|\\bin\\s+(\\d+)\\s+(days?|weeks?)\\b',
    caseSensitive: false);
final _timeRe = RegExp('(?<![\\w:/])$_time(?![\\w:])', caseSensitive: false);
final _gapAfter = RegExp(r'^[\s,]*$');
final _gapBefore = RegExp(r'^[\s,]*(on\s+)?$', caseSensitive: false);

/// Buddhist-era years (2400+) → Gregorian; two-digit years → 20xx.
int _gregorian(int year) => year >= 2400 ? year - 543 : (year < 100 ? 2000 + year : year);

/// Finds the earliest date phrase in [text]; an adjacent time (before or after, optional "at") is included.
/// A time with no date means today. A month/day without a year that has already passed means next year.
DateMatch? findDate(String text, DateTime now) {
  final candidates = <DateMatch>[];
  final today = DateTime(now.year, now.month, now.day);

  DateTime rollForward(int month, int day, String? year) {
    if (year != null) return DateTime(_gregorian(int.parse(year)), month, day);
    final thisYear = DateTime(now.year, month, day);
    return thisYear.isBefore(today) ? DateTime(now.year + 1, month, day) : thisYear;
  }

  for (final m in _js.allMatches(text)) {
    final month = _months[m[1]!.toLowerCase()]!;
    final sign = m[7] == '-' ? -1 : 1;
    final offset = Duration(hours: int.parse(m[8]!), minutes: int.parse(m[9]!)) * sign;
    final utc = DateTime.utc(_gregorian(int.parse(m[3]!)), month, int.parse(m[2]!), int.parse(m[4]!),
            int.parse(m[5]!), int.parse(m[6]!))
        .subtract(offset);
    candidates.add(DateMatch(m.start, m.end, utc.toLocal(), hasTime: true));
  }

  for (final m in _iso.allMatches(text)) {
    final y = _gregorian(int.parse(m[1]!)), mo = int.parse(m[2]!), d = int.parse(m[3]!);
    if (m[4] == null) {
      candidates.add(DateMatch(m.start, m.end, DateTime(y, mo, d), hasTime: false));
      continue;
    }
    final h = int.parse(m[4]!), mi = int.parse(m[5]!), s = int.parse(m[6] ?? '0');
    final zone = m[7];
    final DateTime value;
    if (zone == null) {
      value = DateTime(y, mo, d, h, mi, s);
    } else if (zone == 'Z') {
      value = DateTime.utc(y, mo, d, h, mi, s).toLocal();
    } else {
      final digits = zone.replaceAll(':', '');
      final offset = Duration(hours: int.parse(digits.substring(1, 3)), minutes: int.parse(digits.substring(3, 5))) *
          (digits.startsWith('-') ? -1 : 1);
      value = DateTime.utc(y, mo, d, h, mi, s).subtract(offset).toLocal();
    }
    candidates.add(DateMatch(m.start, m.end, value, hasTime: true));
  }

  for (final m in _monthFirst.allMatches(text)) {
    candidates.add(
        DateMatch(m.start, m.end, rollForward(_months[m[1]!.toLowerCase()]!, int.parse(m[2]!), m[3]), hasTime: false));
  }
  for (final m in _dayFirst.allMatches(text)) {
    candidates.add(
        DateMatch(m.start, m.end, rollForward(_months[m[2]!.toLowerCase()]!, int.parse(m[1]!), m[3]), hasTime: false));
  }
  for (final m in _numeric.allMatches(text)) {
    final day = int.parse(m[1]!), month = int.parse(m[2]!);
    if (month < 1 || month > 12 || day < 1 || day > 31) continue;
    candidates.add(DateMatch(m.start, m.end, rollForward(month, day, m[3]), hasTime: false));
  }

  for (final m in _relative.allMatches(text)) {
    final word = m[1]?.toLowerCase();
    DateTime inDays(int n) => DateTime(today.year, today.month, today.day + n);
    if (word == 'today') {
      candidates.add(DateMatch(m.start, m.end, today, hasTime: false));
    } else if (word == 'tonight') {
      candidates.add(DateMatch(m.start, m.end, DateTime(today.year, today.month, today.day, 20), hasTime: true));
    } else if (word == 'tomorrow') {
      candidates.add(DateMatch(m.start, m.end, inDays(1), hasTime: false));
    } else if (word == 'next week') {
      candidates.add(DateMatch(m.start, m.end, inDays(7), hasTime: false));
    } else if (m[3] != null) {
      final target = _weekdays[m[3]!.toLowerCase()]!;
      var ahead = (target - today.weekday + 7) % 7;
      if (ahead == 0 && m[2]?.toLowerCase() == 'next') ahead = 7;
      candidates.add(DateMatch(m.start, m.end, inDays(ahead), hasTime: false));
    } else if (m[4] != null) {
      final n = int.parse(m[4]!) * (m[5]!.toLowerCase().startsWith('week') ? 7 : 1);
      candidates.add(DateMatch(m.start, m.end, inDays(n), hasTime: false));
    }
  }

  // Earliest start wins; at equal starts the longest wins (so "Wed Feb 10 2027 …" beats "Wed").
  candidates.sort((a, b) => a.start != b.start ? a.start.compareTo(b.start) : b.end.compareTo(a.end));
  final times = _timeRe.allMatches(text).toList();

  if (candidates.isEmpty) {
    if (times.isEmpty) return null;
    final t = times.first;
    final (h, mi, s) = _clock(t);
    return DateMatch(t.start, t.end, DateTime(now.year, now.month, now.day, h, mi, s), hasTime: true);
  }

  final best = candidates.first;
  if (best.hasTime) return best;

  // Attach a time directly after (or before) the date, separated only by spaces/commas (or "on").
  for (final t in times) {
    final after = t.start >= best.end && _gapAfter.hasMatch(text.substring(best.end, t.start));
    final before = t.end <= best.start && _gapBefore.hasMatch(text.substring(t.end, best.start));
    if (after || before) {
      final (h, mi, s) = _clock(t);
      final v = best.value;
      return DateMatch(before ? t.start : best.start, after ? t.end : best.end,
          DateTime(v.year, v.month, v.day, h, mi, s),
          hasTime: true);
    }
  }
  return best;
}

(int, int, int) _clock(RegExpMatch t) {
  final word = t[7]?.toLowerCase();
  if (word == 'noon') return (12, 0, 0);
  if (word == 'midnight') return (0, 0, 0);
  var h = int.parse(t[1] ?? t[5]!);
  final mi = int.parse(t[2] ?? '0'), s = int.parse(t[3] ?? '0');
  final ampm = (t[4] ?? t[6])?.toLowerCase().replaceAll('.', '');
  if (ampm == 'pm' && h < 12) h += 12;
  if (ampm == 'am' && h == 12) h = 0;
  return (h, mi, s);
}
