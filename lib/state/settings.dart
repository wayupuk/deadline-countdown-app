import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/models.dart';
import '../core/year_format.dart';

/// Local preferences (not synced). Loaded once at startup; every change is saved immediately.
class AppSettings {
  const AppSettings({
    required this.precision,
    required this.showTrayCountdown,
    required this.buddhistYears,
    required this.launchAtLogin,
    required this.groupFilter,
    required this.macImportDone,
  });

  final CountdownPrecision precision;
  final bool showTrayCountdown;
  final bool buddhistYears;

  /// Defaults on where reminders are delivered in-app (Windows/Linux), so they keep arriving.
  final bool launchAtLogin;

  /// Group id, `noGroupFilter`, or null for all.
  final String? groupFilter;
  final bool macImportDone;

  static AppSettings load(SharedPreferences prefs, {required String localeName, required bool inAppReminders}) =>
      AppSettings(
        precision: CountdownPrecision.values
                .where((p) => p.name == prefs.getString('precision'))
                .firstOrNull ??
            CountdownPrecision.hours,
        showTrayCountdown: prefs.getBool('showTrayCountdown') ?? true,
        buddhistYears: prefs.getBool('buddhistYears') ?? localeUsesBuddhistCalendar(localeName),
        launchAtLogin: prefs.getBool('launchAtLogin') ?? inAppReminders,
        groupFilter: prefs.getString('groupFilter'),
        macImportDone: prefs.getBool('macImportDone') ?? false,
      );

  Future<void> save(SharedPreferences prefs) async {
    await prefs.setString('precision', precision.name);
    await prefs.setBool('showTrayCountdown', showTrayCountdown);
    await prefs.setBool('buddhistYears', buddhistYears);
    await prefs.setBool('launchAtLogin', launchAtLogin);
    groupFilter == null ? await prefs.remove('groupFilter') : await prefs.setString('groupFilter', groupFilter!);
    await prefs.setBool('macImportDone', macImportDone);
  }

  AppSettings copyWith({
    CountdownPrecision? precision,
    bool? showTrayCountdown,
    bool? buddhistYears,
    bool? launchAtLogin,
    Object? groupFilter = _keep,
    bool? macImportDone,
  }) =>
      AppSettings(
        precision: precision ?? this.precision,
        showTrayCountdown: showTrayCountdown ?? this.showTrayCountdown,
        buddhistYears: buddhistYears ?? this.buddhistYears,
        launchAtLogin: launchAtLogin ?? this.launchAtLogin,
        groupFilter: identical(groupFilter, _keep) ? this.groupFilter : groupFilter as String?,
        macImportDone: macImportDone ?? this.macImportDone,
      );
}

const _keep = Object();

/// Overridden in `main()` with the loaded instance.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) => throw UnimplementedError('override in main'));

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);

class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() => AppSettings.load(ref.read(sharedPreferencesProvider),
      localeName: Platform.localeName, inAppReminders: Platform.isWindows || Platform.isLinux);

  Future<void> update(AppSettings Function(AppSettings current) change) async {
    state = change(state);
    await state.save(ref.read(sharedPreferencesProvider));
  }
}
