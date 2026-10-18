import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../platform/notifications.dart';

/// Platform services created in `main()`. Null in widget tests.
class AppServices {
  AppServices({required this.notifications, required this.reminders});
  final NotificationPort notifications;
  final ReminderService reminders;
}

final servicesProvider = Provider<AppServices?>((ref) => null);

/// Messages to show once after startup (imports, recovered database).
final startupNoticesProvider = Provider<List<String>>((ref) => const []);

final notificationPermissionProvider =
    NotifierProvider<NotificationPermissionNotifier, NotificationPermission>(NotificationPermissionNotifier.new);

class NotificationPermissionNotifier extends Notifier<NotificationPermission> {
  @override
  NotificationPermission build() => NotificationPermission.unknown;

  Future<void> refresh() async {
    final services = ref.read(servicesProvider);
    if (services != null) state = await services.notifications.status();
  }

  Future<void> request() async {
    final services = ref.read(servicesProvider);
    if (services != null) state = await services.notifications.requestPermission();
  }
}

/// Android: whether reminders fire at the exact minute ("Alarms & reminders" permission).
final exactAlarmsProvider = NotifierProvider<ExactAlarmsNotifier, bool>(ExactAlarmsNotifier.new);

class ExactAlarmsNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  Future<void> refresh() async {
    final services = ref.read(servicesProvider);
    if (services != null) state = await services.notifications.exactAlarmsAllowed();
  }

  Future<void> request() async => ref.read(servicesProvider)?.notifications.requestExactAlarms();
}

/// How many reminders are currently pending (OS) or armed (in-app).
final scheduledCountProvider = NotifierProvider<ScheduledCountNotifier, int>(ScheduledCountNotifier.new);

class ScheduledCountNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void set(int count) => state = count;
}
