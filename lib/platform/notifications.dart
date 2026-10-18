import 'dart:async';
import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../core/models.dart' show Deadline;
import '../core/reminders.dart';

enum NotificationPermission { granted, denied, unknown }

/// What the app needs from the OS notification system. Faked in tests.
abstract class NotificationPort {
  Future<NotificationPermission> requestPermission();
  Future<NotificationPermission> status();
  Future<void> cancelAll();

  /// OS-scheduled delivery (macOS, Android).
  Future<void> schedule(PlannedReminder r);

  /// Immediate delivery (test notification, in-app timers on Windows/Linux).
  Future<void> show(String title, String body);
  Future<void> openSystemSettings();

  /// Android only: whether reminders can fire at the exact minute. Always true elsewhere.
  Future<bool> exactAlarmsAllowed();

  /// Android only: opens the system "Alarms & reminders" page. Only call on a user action.
  Future<void> requestExactAlarms();
}

typedef TimerStarter = Timer Function(Duration delay, void Function() callback);

/// Keeps pending notifications equal to the current plan. On macOS/Android the OS delivers them
/// ([osScheduling]); on Windows/Linux the app holds a timer per reminder for the next 24 h and must be running.
class ReminderService {
  ReminderService(this.port, {required this.osScheduling, required this.cap, TimerStarter? startTimer})
      : _startTimer = startTimer ?? ((d, cb) => Timer(d, cb));

  final NotificationPort port;
  final bool osScheduling;
  final int cap;
  final TimerStarter _startTimer;
  final _timers = <Timer>[];

  /// Cancels everything pending, then schedules the fresh plan. Returns how many reminders are pending.
  Future<int> replan(List<Deadline> all, DateTime now) async {
    _cancelTimers();
    await port.cancelAll();
    final plan = planReminders(all, now, limit: cap, until: osScheduling ? null : now.add(const Duration(hours: 24)));
    for (final r in plan) {
      if (osScheduling) {
        await port.schedule(r);
      } else {
        _timers.add(_startTimer(r.fireAt.difference(now), () => port.show(r.title, r.body)));
      }
    }
    return plan.length;
  }

  void dispose() => _cancelTimers();

  void _cancelTimers() {
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
  }
}

/// [NotificationPort] backed by flutter_local_notifications. Call [init] once at startup, after
/// `tz.setLocalLocation(...)`.
class FlutterNotificationPort implements NotificationPort {
  FlutterNotificationPort([FlutterLocalNotificationsPlugin? plugin])
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  var _exactAlarms = true;

  /// Taps on a notification report the deadline id (the payload).
  Future<void> init({void Function(String deadlineId)? onOpen}) async {
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        macOS: DarwinInitializationSettings(
            requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false),
        linux: LinuxInitializationSettings(defaultActionName: 'Open'),
        windows: WindowsInitializationSettings(
            appName: 'Deadline Countdown',
            appUserModelId: 'com.wayupuk.deadlines',
            guid: '5b8f2c1e-7d3a-4e9b-a6f0-2c4d8e1b9a73'),
      ),
      onDidReceiveNotificationResponse: (response) {
        final id = response.payload;
        if (id != null && id.isNotEmpty) onOpen?.call(id);
      },
    );
  }

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails('reminders', 'Reminders',
        channelDescription: 'Daily countdowns and due-now alerts',
        importance: Importance.high,
        priority: Priority.high),
    macOS: DarwinNotificationDetails(),
    linux: LinuxNotificationDetails(),
    windows: WindowsNotificationDetails(),
  );

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  MacOSFlutterLocalNotificationsPlugin? get _macos =>
      _plugin.resolvePlatformSpecificImplementation<MacOSFlutterLocalNotificationsPlugin>();

  @override
  Future<NotificationPermission> requestPermission() async {
    if (Platform.isMacOS) {
      await _macos?.requestPermissions(alert: true, sound: true, badge: true);
    } else if (Platform.isAndroid) {
      // Exact alarms are requested only from Settings (requestExactAlarms), never automatically.
      await _android?.requestNotificationsPermission();
    }
    return status();
  }

  @override
  Future<NotificationPermission> status() async {
    if (Platform.isMacOS) {
      final options = await _macos?.checkPermissions();
      if (options == null) return NotificationPermission.unknown;
      return options.isEnabled ? NotificationPermission.granted : NotificationPermission.denied;
    }
    if (Platform.isAndroid) {
      _exactAlarms = await _android?.canScheduleExactNotifications() ?? false;
      final enabled = await _android?.areNotificationsEnabled();
      if (enabled == null) return NotificationPermission.unknown;
      return enabled ? NotificationPermission.granted : NotificationPermission.denied;
    }
    return NotificationPermission.granted; // Windows/Linux don't gate app notifications.
  }

  /// Android: whether reminders can be exact (else they may arrive a few minutes late).
  bool get exactAlarms => _exactAlarms;

  @override
  Future<bool> exactAlarmsAllowed() async {
    if (!Platform.isAndroid) return true;
    _exactAlarms = await _android?.canScheduleExactNotifications() ?? false;
    return _exactAlarms;
  }

  @override
  Future<void> requestExactAlarms() async {
    if (Platform.isAndroid) await _android?.requestExactAlarmsPermission();
  }

  @override
  Future<void> cancelAll() => _plugin.cancelAll();

  @override
  Future<void> schedule(PlannedReminder r) => _plugin.zonedSchedule(
        id: stableNotificationId(r.id),
        scheduledDate: tz.TZDateTime.from(r.fireAt, tz.local),
        notificationDetails: _details,
        androidScheduleMode:
            _exactAlarms ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle,
        title: r.title,
        body: r.body,
        payload: r.deadlineId,
      );

  @override
  Future<void> show(String title, String body) => _plugin.show(
      id: stableNotificationId('$title${DateTime.now().microsecondsSinceEpoch}'),
      title: title,
      body: body,
      notificationDetails: _details);

  @override
  Future<void> openSystemSettings() async {
    await _plugin.openAppNotificationSettings();
  }
}
