import 'package:deadlines/core/models.dart';
import 'package:deadlines/state/settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('defaults depend on locale and platform', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final thai = AppSettings.load(prefs, localeName: 'en-TH', inAppReminders: true);
    expect(thai.precision, CountdownPrecision.hours);
    expect(thai.buddhistYears, isTrue);
    expect(thai.launchAtLogin, isTrue);
    expect(thai.showTrayCountdown, isTrue);
    expect(thai.groupFilter, isNull);
    expect(thai.macImportDone, isFalse);
    final us = AppSettings.load(prefs, localeName: 'en_US', inAppReminders: false);
    expect((us.buddhistYears, us.launchAtLogin), (false, false));
  });

  test('saved values survive a reload', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final s = AppSettings.load(prefs, localeName: 'en_US', inAppReminders: false).copyWith(
        precision: CountdownPrecision.minutes, buddhistYears: true, groupFilter: 'g1', macImportDone: true);
    await s.save(prefs);
    final back = AppSettings.load(prefs, localeName: 'en_US', inAppReminders: false);
    expect((back.precision, back.buddhistYears, back.groupFilter, back.macImportDone),
        (CountdownPrecision.minutes, true, 'g1', true));
    await back.copyWith(groupFilter: null).save(prefs);
    expect(AppSettings.load(prefs, localeName: 'en_US', inAppReminders: false).groupFilter, isNull);
  });
}
