import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'state/shell.dart';
import 'ui/desktop/main_window.dart';
import 'ui/desktop/tray_popup.dart';
import 'ui/theme.dart';

class DeadlineApp extends ConsumerWidget {
  const DeadlineApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(shellModeProvider);
    final shell = ref.watch(shellActionsProvider);

    return MaterialApp(
      title: 'Deadline Countdown',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      home: mode == ShellMode.popup && shell != null
          ? TrayPopup(onOpenCalendar: shell.showCalendar, onOpenSettings: shell.showCalendar, onQuit: shell.quit)
          : const MainWindow(),
    );
  }
}
