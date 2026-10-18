/// "2026", or "2569 BE" for Buddhist-era display.
String yearLabel(int gregorianYear, {required bool buddhist}) => buddhist ? '${gregorianYear + 543} BE' : '$gregorianYear';

/// Whether dates should show Buddhist-era years by default. An explicit `@calendar=` tag decides; otherwise
/// the Thai region (macOS reports e.g. `en-TH` / `en_TH`) defaults to the Buddhist calendar, as macOS does.
bool localeUsesBuddhistCalendar(String localeName) {
  final lower = localeName.toLowerCase();
  final tag = RegExp(r'calendar=(\w+)').firstMatch(lower);
  if (tag != null) return tag[1] == 'buddhist';
  return RegExp(r'[-_]th\b').hasMatch(lower);
}
