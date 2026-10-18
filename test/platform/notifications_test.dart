import 'dart:async';

import 'package:deadlines/core/models.dart';
import 'package:deadlines/core/reminders.dart';
import 'package:deadlines/platform/notifications.dart';
import 'package:flutter_test/flutter_test.dart';

class FakePort implements NotificationPort {
  FakePort({this.failFirst = 0, this.delay = Duration.zero});
  final int failFirst;
  final Duration delay;
  final log = <String>[];
  final pending = <String>{};
  var _scheduleCalls = 0;

  @override
  Future<void> cancelPending() async {
    log.add('cancelPending');
    pending.clear();
  }

  @override
  Future<void> schedule(PlannedReminder r) async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (_scheduleCalls++ < failFirst) throw StateError('exact alarms not permitted');
    log.add('schedule ${r.id}');
    pending.add(r.id);
  }
  @override
  Future<void> show(String title, String body) async => log.add('show $title');
  @override
  Future<NotificationPermission> requestPermission() async => NotificationPermission.granted;
  @override
  Future<NotificationPermission> status() async => NotificationPermission.granted;

  @override
  Future<void> openSystemSettings() async {}
  @override
  Future<bool> exactAlarmsAllowed() async => true;
  @override
  Future<void> requestExactAlarms() async {}
}

void main() {
  final now = DateTime(2026, 10, 18, 8);
  final d = Deadline(id: 'a', title: 'A', dueAt: DateTime(2027, 3, 1), createdAt: now, updatedAt: now);

  test('reschedule cancels first and respects the cap', () async {
    final port = FakePort();
    final n = await ReminderService(port, osScheduling: true, cap: 60).replan([d], now);
    expect(port.log.first, 'cancelPending');
    expect(n, 60);
    expect(port.log.where((l) => l.startsWith('schedule')).length, 60);
  });

  test('in-app mode plans a 24h window and schedules nothing with the OS', () async {
    final port = FakePort();
    final service = ReminderService(port, osScheduling: false, cap: 1000);
    final n = await service.replan([d], now);
    expect(n, 1); // only today's 09:00
    expect(port.log.where((l) => l.startsWith('schedule')), isEmpty);
    expect(port.log, isNot(contains('cancelPending')), reason: 'in-app mode must not touch OS notifications');
    service.dispose();
  });

  test('one failing reminder does not stop the rest', () async {
    final port = FakePort(failFirst: 1);
    final n = await ReminderService(port, osScheduling: true, cap: 10).replan([d], now);
    expect(n, 9);
    expect(port.pending.length, 9);
  });

  test('overlapping replans end with exactly the latest plan', () async {
    final port = FakePort(delay: const Duration(milliseconds: 2));
    final service = ReminderService(port, osScheduling: true, cap: 5);
    final early = d.copyWith(dueAt: DateTime(2026, 10, 25, 17));
    final first = service.replan([d], now);
    final second = service.replan([early], now);
    await Future.wait([first, second]);
    final expected = planReminders([early], now, limit: 5).map((r) => r.id).toSet();
    expect(port.pending, expected);
  });

  test('in-app mode shows the reminder when its timer fires, and replan drops old timers', () async {
    final port = FakePort();
    final timers = <Duration, void Function()>{};
    final cancelled = <Duration>[];
    final service = ReminderService(port, osScheduling: false, cap: 1000, startTimer: (delay, cb) {
      timers[delay] = cb;
      return _FakeTimer(() => cancelled.add(delay));
    });
    await service.replan([d], now);
    expect(timers.keys.single, const Duration(hours: 1)); // 08:00 → 09:00
    timers.values.single();
    expect(port.log.last, 'show 📅 A');
    await service.replan([d], now);
    expect(cancelled, [const Duration(hours: 1)]);
    service.dispose();
  });
}

class _FakeTimer implements Timer {
  _FakeTimer(this._onCancel);
  final void Function() _onCancel;
  @override
  void cancel() => _onCancel();
  @override
  bool get isActive => true;
  @override
  int get tick => 0;
}
