import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models.dart';
import '../platform/notifications.dart';
import '../state/providers.dart';
import '../state/services.dart';
import '../state/shell.dart';
import 'widgets/group_manager.dart';

/// Settings content (no Scaffold): pushed as a page on desktop, a tab on Android.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final services = ref.watch(servicesProvider);
    final permission = ref.watch(notificationPermissionProvider);
    final scheduled = ref.watch(scheduledCountProvider);
    final shell = ref.watch(shellActionsProvider);
    final inAppReminders = Platform.isWindows || Platform.isLinux;

    Widget section(String title, List<Widget> children) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
              child: Text(title.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
            ),
            Card(child: Column(children: children)),
          ]),
        );

    final (statusText, statusColor) = switch ((services, permission)) {
      (null, _) => ('Unavailable here', theme.colorScheme.outline),
      (_, NotificationPermission.granted) => ('On', const Color(0xFF30D158)),
      (_, NotificationPermission.denied) => ('Off — turn on in system settings', const Color(0xFFFF453A)),
      _ => ('Not set up yet', const Color(0xFFFF9F0A)),
    };

    return ListView(padding: const EdgeInsets.all(20), children: [
      section('Countdown', [
        RadioGroup<CountdownPrecision>(
          groupValue: settings.precision,
          onChanged: (p) => p == null ? null : notifier.update((s) => s.copyWith(precision: p)),
          child: const Column(children: [
            RadioListTile(value: CountdownPrecision.days, title: Text('Days'), subtitle: Text('79d')),
            RadioListTile(value: CountdownPrecision.hours, title: Text('Days + hours'), subtitle: Text('79d 1h')),
            RadioListTile(value: CountdownPrecision.minutes, title: Text('Down to the minute'), subtitle: Text('79d 1h 23m')),
          ]),
        ),
        const Divider(height: 1),
        if (Platform.isMacOS && shell != null)
          SwitchListTile(
            title: const Text('Show countdown next to the menu bar icon'),
            value: settings.showTrayCountdown,
            onChanged: (v) => notifier.update((s) => s.copyWith(showTrayCountdown: v)),
          ),
        SwitchListTile(
          title: const Text('Buddhist-era years (BE)'),
          subtitle: const Text('Shows 2569 instead of 2026'),
          value: settings.buddhistYears,
          onChanged: (v) => notifier.update((s) => s.copyWith(buddhistYears: v)),
        ),
      ]),
      section('Notifications', [
        ListTile(
          leading: Icon(Icons.circle, size: 12, color: statusColor),
          title: const Text('Status'),
          trailing: Text(statusText),
        ),
        ListTile(
          leading: const Icon(Icons.schedule_send_rounded),
          title: Text(inAppReminders ? 'Reminders armed (next 24 h)' : 'Scheduled reminders'),
          trailing: Text(permission == NotificationPermission.granted ? '$scheduled' : '—'),
        ),
        if (inAppReminders)
          const ListTile(
            leading: Icon(Icons.info_outline_rounded),
            title: Text('Reminders only arrive while the app is running'),
            subtitle: Text('Keep "Launch at login" on so it starts with your computer.'),
          ),
        if (services != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Wrap(spacing: 8, runSpacing: 8, children: [
              if (permission != NotificationPermission.granted)
                FilledButton(
                    onPressed: () => ref.read(notificationPermissionProvider.notifier).request(),
                    child: const Text('Allow notifications')),
              OutlinedButton(
                  onPressed: permission == NotificationPermission.granted
                      ? () => services.notifications.show('Deadline Countdown', 'Notifications are working.')
                      : null,
                  child: const Text('Send test notification')),
              TextButton(onPressed: services.notifications.openSystemSettings, child: const Text('Open system settings')),
            ]),
          ),
      ]),
      if (shell != null)
        section('Desktop', [
          _LaunchAtLoginTile(shell: shell),
          ListTile(
            leading: const Icon(Icons.keyboard_command_key_rounded),
            title: const Text('Open the dropdown from anywhere'),
            trailing: Text(shell.hotKeyRegistered ? '⌃⌥D' : 'Used by another app',
                style: TextStyle(color: shell.hotKeyRegistered ? null : const Color(0xFFFF9F0A))),
          ),
          if (!shell.trayAvailable)
            const ListTile(
              leading: Icon(Icons.warning_amber_rounded, color: Color(0xFFFF9F0A)),
              title: Text('Tray icon unavailable'),
              subtitle: Text('On GNOME, install the AppIndicator extension, then restart the app.'),
            ),
        ]),
      section('Groups', [
        ListTile(
          leading: const Icon(Icons.tune_rounded),
          title: const Text('Manage groups…'),
          onTap: () => showGroupManager(context),
        ),
      ]),
    ]);
  }
}

class _LaunchAtLoginTile extends ConsumerStatefulWidget {
  const _LaunchAtLoginTile({required this.shell});
  final ShellActions shell;

  @override
  ConsumerState<_LaunchAtLoginTile> createState() => _LaunchAtLoginTileState();
}

class _LaunchAtLoginTileState extends ConsumerState<_LaunchAtLoginTile> {
  String? _error;

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    return SwitchListTile(
      secondary: const Icon(Icons.power_settings_new_rounded),
      title: const Text('Launch at login'),
      subtitle: _error == null ? null : Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
      value: settings.launchAtLogin,
      onChanged: (v) async {
        final ok = await widget.shell.setLaunchAtLogin(v);
        setState(() => _error = ok ? null : 'Couldn\'t change this. Move the app to Applications and try again.');
        if (ok) await ref.read(settingsProvider.notifier).update((s) => s.copyWith(launchAtLogin: v));
      },
    );
  }
}
