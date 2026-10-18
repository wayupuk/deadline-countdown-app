import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'app.dart';
import 'data/database.dart';
import 'data/mac_import_runner.dart';
import 'data/repository.dart';
import 'platform/desktop_shell.dart';
import 'platform/notifications.dart';
import 'state/providers.dart';
import 'state/selection.dart';
import 'state/services.dart';
import 'state/shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final notices = <String>[];

  tz_data.initializeTimeZones();
  try {
    tz.setLocalLocation(tz.getLocation((await FlutterTimezone.getLocalTimezone()).identifier));
  } catch (_) {
    // Unknown zone name: notifications fall back to UTC-based scheduling of the same instants.
  }

  final prefs = await SharedPreferences.getInstance();
  final opened = await AppDatabase.openDefault();
  if (opened.recoveredFrom != null) {
    notices.add("Your saved deadlines couldn't be read. A copy was kept at ${opened.recoveredFrom}.");
  }
  final repo = DeadlineRepository(opened.db);

  final port = FlutterNotificationPort();
  final osScheduling = Platform.isMacOS || Platform.isAndroid;
  final reminders = ReminderService(port, osScheduling: osScheduling, cap: Platform.isAndroid ? 200 : (osScheduling ? 60 : 1000));
  final desktop = Platform.isMacOS || Platform.isWindows || Platform.isLinux;
  final shell = desktop ? DesktopShell() : null;

  final container = ProviderContainer(overrides: [
    sharedPreferencesProvider.overrideWithValue(prefs),
    repositoryProvider.overrideWithValue(repo),
    shellActionsProvider.overrideWithValue(shell),
    servicesProvider.overrideWithValue(AppServices(notifications: port, reminders: reminders)),
    startupNoticesProvider.overrideWithValue(notices),
  ]);

  await _importFromMacApp(container, repo, notices);

  await port.init(onOpen: (id) async {
    final deadline = (await repo.watchDeadlines().first).where((d) => d.id == id).firstOrNull;
    if (deadline != null) container.read(calendarSelectionProvider.notifier).selectDeadline(deadline);
    await shell?.showCalendar();
  });
  await shell?.init(container);
  _keepRemindersPlanned(container, reminders, osScheduling: osScheduling);

  runApp(UncontrolledProviderScope(container: container, child: const DeadlineApp()));

  // Ask after the UI is up: the system prompt waits for the user, and the app must not sit on a blank window.
  await container.read(notificationPermissionProvider.notifier).request();
  await container.read(exactAlarmsProvider.notifier).refresh();
}

/// First launch on macOS: bring over the SwiftUI app's deadlines once.
Future<void> _importFromMacApp(ProviderContainer container, DeadlineRepository repo, List<String> notices) async {
  if (!Platform.isMacOS || container.read(settingsProvider).macImportDone) return;
  final file = File('${Platform.environment['HOME']}/Library/Application Support/DeadlineCountdown/deadlines.json');
  if (file.existsSync()) {
    final notice = await importMacDeadlines(read: file.readAsString, repo: repo);
    if (notice != null) notices.add(notice);
  }
  await container.read(settingsProvider.notifier).update((s) => s.copyWith(macImportDone: true));
}

/// Re-plans reminders when deadlines change, when the day changes (hourly for in-app delivery,
/// whose window is 24 h), and when the app comes back to the foreground.
void _keepRemindersPlanned(ProviderContainer container, ReminderService reminders, {required bool osScheduling}) {
  Future<void> replan() async {
    final list = container.read(deadlinesProvider).value;
    if (list == null) return;
    container.read(scheduledCountProvider.notifier).set(await reminders.replan(list, DateTime.now()));
  }

  container.listen(deadlinesProvider, (_, _) => replan(), fireImmediately: true);
  var lastKey = '';
  container.listen(nowProvider, (_, now) {
    final key = '${now.year}-${now.month}-${now.day}${osScheduling ? '' : '-${now.hour}'}';
    if (key != lastKey) {
      lastKey = key;
      replan();
    }
  }, fireImmediately: true);
  AppLifecycleListener(onResume: () {
    container.read(nowProvider.notifier).refresh();
    container.read(notificationPermissionProvider.notifier).refresh();
    container.read(exactAlarmsProvider.notifier).refresh();
    replan();
  });
}
