# Toolchain

All large tools live on an APFS disk image on an external drive,
mounted at login; `$DEVTOOLS` below means that volume.
Paths are exported from the shell profile.

| Tool | Version | Location |
|---|---|---|
| Flutter | 3.47.7 (stable, 2026-10-08) | `$DEVTOOLS/flutter` |
| Dart | 3.13.5 | bundled with Flutter |
| Xcode | 26.3 (17C529) | `$DEVTOOLS/Xcode.app` |
| Android SDK | platform 36, build-tools 36.1.0 | `$DEVTOOLS/android-sdk` |
| Android emulator | AVD `pixel36` (android-36, google_apis, arm64) | `~/.android/avd` |
| JDK | 17.0.20 (Homebrew `openjdk@17`) | `/opt/homebrew/opt/openjdk@17` |
| CocoaPods | Homebrew `cocoapods` | `/opt/homebrew/bin/pod` |

Pub cache: `$DEVTOOLS/pub-cache`. Gradle cache: `$DEVTOOLS/gradle`.

Resolved package versions are pinned in `pubspec.lock`. Notable: flutter_riverpod 3.4, drift 2.35
(SQLite bundled by `sqlite3` 3.x — `sqlite3_flutter_libs` is obsolete and not used),
flutter_local_notifications 22.3, tray_manager 0.8, window_manager 0.5, hotkey_manager 0.2.
