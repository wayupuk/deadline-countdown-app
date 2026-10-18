import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'data/database.dart';
import 'data/repository.dart';
import 'platform/desktop_shell.dart';
import 'state/providers.dart';
import 'state/shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final opened = await AppDatabase.openDefault();
  final desktop = Platform.isMacOS || Platform.isWindows || Platform.isLinux;
  final shell = desktop ? DesktopShell() : null;

  final container = ProviderContainer(overrides: [
    sharedPreferencesProvider.overrideWithValue(prefs),
    repositoryProvider.overrideWithValue(DeadlineRepository(opened.db)),
    shellActionsProvider.overrideWithValue(shell),
  ]);
  await shell?.init(container);

  runApp(UncontrolledProviderScope(container: container, child: const DeadlineApp()));
}
