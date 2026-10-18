import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'platform/notifications.dart';
import 'state/services.dart';
import 'state/shell.dart';
import 'ui/desktop/main_window.dart';
import 'ui/desktop/tray_popup.dart';
import 'ui/mobile/home_tabs.dart';
import 'ui/settings_page.dart';
import 'ui/theme.dart';
import 'ui/widgets/banners.dart';

final _navigatorKey = GlobalKey<NavigatorState>();
final _messengerKey = GlobalKey<ScaffoldMessengerState>();

class DeadlineApp extends ConsumerStatefulWidget {
  const DeadlineApp({super.key});

  @override
  ConsumerState<DeadlineApp> createState() => _DeadlineAppState();
}

class _DeadlineAppState extends ConsumerState<DeadlineApp> {
  @override
  void initState() {
    super.initState();
    // Startup notices (import result, recovered database) once the first frame exists.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final notice in ref.read(startupNoticesProvider)) {
        _messengerKey.currentState?.showSnackBar(SnackBar(content: Text(notice), duration: const Duration(seconds: 8)));
      }
    });
  }

  Future<void> _openSettings() async {
    await ref.read(shellActionsProvider)?.showCalendar();
    await _navigatorKey.currentState?.push(MaterialPageRoute<void>(
      builder: (_) => Scaffold(appBar: AppBar(title: const Text('Settings')), body: const SettingsPage()),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(shellModeProvider);
    final shell = ref.watch(shellActionsProvider);
    final services = ref.watch(servicesProvider);
    final denied = ref.watch(notificationPermissionProvider) == NotificationPermission.denied;
    final banner = denied && services != null
        ? NotificationsOffBanner(onOpenSettings: services.notifications.openSystemSettings)
        : null;

    final Widget home;
    if (Platform.isAndroid) {
      home = HomeTabs(banner: banner);
    } else if (shell == null) {
      home = MainWindow(banner: banner, onOpenSettings: _openSettings);
    } else if (mode == ShellMode.popup) {
      home = TrayPopup(onOpenCalendar: shell.showCalendar, onOpenSettings: _openSettings, onQuit: shell.quit, banner: banner);
    } else {
      home = MainWindow(banner: banner, onOpenSettings: _openSettings);
    }

    return MaterialApp(
      title: 'Deadline Countdown',
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigatorKey,
      scaffoldMessengerKey: _messengerKey,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      home: home,
    );
  }
}
