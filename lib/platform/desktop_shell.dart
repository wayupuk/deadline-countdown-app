import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../state/providers.dart';
import 'linux_tray.dart';
import '../state/shell.dart';

/// Desktop chrome around the Flutter UI: tray icon + countdown text, tray popup vs calendar window
/// (one window, two modes), ⌃⌥D hotkey, launch at login, and close-to-tray.
class DesktopShell with WindowListener implements ShellActions {
  late final ProviderContainer _container;
  TrayIcon? _tray;
  var _trayOk = false;
  var _hotKeyOk = false;
  var _quitting = false;

  static const _calendarSize = Size(1180, 760);
  static const _calendarMinimum = Size(860, 560);
  static const _popupSize = Size(380, 600);
  final _hotKey = HotKey(
      key: PhysicalKeyboardKey.keyD, modifiers: [HotKeyModifier.control, HotKeyModifier.alt], scope: HotKeyScope.system);

  @override
  bool get trayAvailable => _trayOk;
  @override
  bool get hotKeyRegistered => _hotKeyOk;

  ShellMode get _mode => _container.read(shellModeProvider);

  Future<void> init(ProviderContainer container) async {
    _container = container;
    await windowManager.ensureInitialized();
    windowManager.addListener(this);
    await windowManager.setPreventClose(true);
    await windowManager.waitUntilReadyToShow(
      const WindowOptions(size: _calendarSize, minimumSize: _calendarMinimum, center: true, title: 'Deadline Countdown'),
      () async {
        await windowManager.show();
        await windowManager.focus();
      },
    );

    if (!Platform.isLinux || await linuxTrayHostAvailable()) _initTray();
    try {
      await hotKeyManager.unregisterAll();
      await hotKeyManager.register(_hotKey, keyDownHandler: (_) => togglePopup());
      _hotKeyOk = true;
    } catch (_) {
      _hotKeyOk = false;
    }

    launchAtStartup.setup(
        appName: 'Deadline Countdown', appPath: Platform.resolvedExecutable, packageName: 'com.wayupuk.deadlines');
    await setLaunchAtLogin(container.read(settingsProvider).launchAtLogin);

    container.listen(trayTextProvider, (_, _) => _updateTrayText(), fireImmediately: true);
    container.listen(settingsProvider.select((s) => s.showTrayCountdown), (_, _) => _updateTrayText());
  }

  @override
  Future<bool> setLaunchAtLogin(bool enabled) async {
    try {
      enabled ? await launchAtStartup.enable() : await launchAtStartup.disable();
      return true;
    } catch (_) {
      return false;
    }
  }

  void _initTray() {
    try {
      final tray = TrayIcon.create();
      final icon = ImageAsset.fromAsset(Platform.isWindows
          ? 'assets/tray/hourglass.ico'
          : Platform.isMacOS
              ? 'assets/tray/hourglass_template.png'
              : 'assets/tray/hourglass.png');
      if (tray == null || icon == null) return;
      tray.icon = icon;
      if (Platform.isMacOS) tray.isIconTemplate = true;

      final menu = Menu.create()!;
      void item(String label, VoidCallback onClick) {
        final i = MenuItem.createWithLabelAndType(label, MenuItemType.normal)!;
        i.addListener((e) {
          if (e is MenuItemClickedEvent) onClick();
        });
        menu.addItem(i);
      }

      item('Show Deadlines', showPopup);
      item('Open Calendar', showCalendar);
      menu.addSeparator();
      item('Quit Deadline Countdown', quit);
      tray.setContextMenu(menu);
      // Linux trays don't report clicks, so any click opens the menu there.
      tray.setContextMenuTrigger(Platform.isLinux ? ContextMenuTrigger.clicked : ContextMenuTrigger.rightClicked);
      tray.addListener((event) {
        if (event is TrayIconClickedEvent) togglePopup();
      });
      tray.setVisible(true);
      _tray = tray;
      _trayOk = true;
    } catch (_) {
      _trayOk = false; // e.g. GNOME without AppIndicator: the app runs as a normal window.
    }
  }

  void _updateTrayText() {
    final tray = _tray;
    if (tray == null) return;
    final text = _container.read(trayTextProvider);
    if (Platform.isMacOS) tray.setTitle(_container.read(settingsProvider).showTrayCountdown ? text.title : null);
    tray.setTooltip(text.tooltip);
  }

  Future<void> togglePopup() async {
    if (_mode == ShellMode.popup && await windowManager.isVisible()) {
      await hidePopup();
    } else {
      await showPopup();
    }
  }

  Future<void> showPopup() async {
    _container.read(shellModeProvider.notifier).set(ShellMode.popup);
    await windowManager.setTitleBarStyle(TitleBarStyle.hidden, windowButtonVisibility: false);
    await windowManager.setMinimumSize(_popupSize);
    await windowManager.setSize(_popupSize);
    await windowManager.setResizable(false);
    await windowManager.setAlwaysOnTop(true);
    await windowManager.setSkipTaskbar(true);
    await _placePopup();
    await windowManager.show();
    await windowManager.focus();
  }

  Future<void> _placePopup() async {
    final bounds = Platform.isMacOS ? _tray?.getBounds() : null;
    if (bounds != null && bounds.width > 0) {
      await windowManager.setPosition(
          Offset(bounds.x + bounds.width / 2 - _popupSize.width / 2, bounds.y + bounds.height + 6));
    } else {
      await windowManager.setAlignment(Platform.isWindows ? Alignment.bottomRight : Alignment.topRight);
    }
  }

  @override
  Future<void> hidePopup() => windowManager.hide();

  @override
  Future<void> showCalendar() async {
    _container.read(shellModeProvider.notifier).set(ShellMode.calendar);
    await windowManager.setAlwaysOnTop(false);
    await windowManager.setSkipTaskbar(false);
    await windowManager.setTitleBarStyle(TitleBarStyle.normal);
    await windowManager.setResizable(true);
    await windowManager.setMinimumSize(_calendarMinimum);
    await windowManager.setSize(_calendarSize);
    await windowManager.center();
    await windowManager.show();
    await windowManager.focus();
  }

  @override
  Future<void> quit() async {
    _quitting = true;
    await hotKeyManager.unregisterAll();
    _tray?.dispose();
    await windowManager.setPreventClose(false);
    await windowManager.destroy();
  }

  @override
  void onWindowBlur() {
    if (_mode == ShellMode.popup) hidePopup();
  }

  @override
  void onWindowClose() {
    // Closing keeps the app in the tray; without a tray, closing quits.
    if (_quitting || !_trayOk) {
      quit();
    } else {
      windowManager.hide();
    }
  }
}
