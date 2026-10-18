import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Desktop: the single window is either the calendar or the tray popup.
enum ShellMode { calendar, popup }

final shellModeProvider = NotifierProvider<ShellModeNotifier, ShellMode>(ShellModeNotifier.new);

class ShellModeNotifier extends Notifier<ShellMode> {
  @override
  ShellMode build() => ShellMode.calendar;

  void set(ShellMode mode) => state = mode;
}

/// Actions the desktop shell offers to the UI (open calendar, toggle popup, quit). Null on Android.
abstract class ShellActions {
  Future<void> showCalendar();
  Future<void> hidePopup();
  Future<void> quit();
  bool get trayAvailable;
  bool get hotKeyRegistered;
  Future<bool> setLaunchAtLogin(bool enabled);
}

final shellActionsProvider = Provider<ShellActions?>((ref) => null);
