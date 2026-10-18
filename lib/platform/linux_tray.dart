import 'dart:io';

/// Parses `gdbus call … NameHasOwner org.kde.StatusNotifierWatcher` output, e.g. "(true,)".
bool statusNotifierWatcherPresent(String gdbusOutput) => gdbusOutput.trim() == '(true,)';

/// Whether a tray host is running. Without one (e.g. GNOME without the AppIndicator extension) the tray
/// icon is created but never shown, so the app must not hide its window on close.
Future<bool> linuxTrayHostAvailable() async {
  try {
    final result = await Process.run('gdbus', [
      'call', '--session', '--dest', 'org.freedesktop.DBus', '--object-path', '/org/freedesktop/DBus',
      '--method', 'org.freedesktop.DBus.NameHasOwner', 'org.kde.StatusNotifierWatcher',
    ]);
    return result.exitCode == 0 && statusNotifierWatcherPresent('${result.stdout}');
  } catch (_) {
    return false;
  }
}
