# Deadline Countdown

Count down to your deadlines and get a reminder every day until they're due — on **macOS, Windows,
Linux and Android**. Built with Flutter.

- **Live countdowns** in the menu bar / system tray (`⏳ 3d 4h`), a dropdown with countdown cards, and a
  Calendar-style month view.
- **Quick add**: type a name and a date in one line and press Enter — `Thesis Oct 24 5pm`.
- **Daily reminders** at a time you choose per deadline, plus a "due now" alert.
- **Groups** (each with a color) and **priority** (Low / Normal / High / Urgent). High and Urgent get extra
  reminders a day, 3 hours and an hour before.
- Countdown precision from days down to the minute, Buddhist-era (BE) years, light and dark mode.

## Quick add

| You type | You get |
|---|---|
| `Thesis Oct 24 5pm` | Thesis, 24 Oct 17:00 |
| `Tax filing tomorrow 9am` | tomorrow 09:00 |
| `Report due by 30 Oct` | Report, 30 Oct 23:59 (no time → end of day) |
| `Dentist next friday` · `Essay in 3 days` | relative dates |
| `Exam 24/10 14:00` · `Final 25 ธ.ค.` · `Exam 24/10/2569` | day-first numbers, Thai months, BE years |
| `Thesis Wed Feb 10 2027 06:59:59 GMT+0700 (Indochina Time)` | JavaScript date format, time zones converted |
| `Lab report Friday 5pm !! #Physics` | `!` High, `!!` Urgent, `#group` puts it in a group |

`7:30` without am/pm means 07:30. A preview under the field shows how your text was read before you save.

## Platforms

| | Tray / menu bar | Reminders |
|---|---|---|
| macOS 12+ | Icon + countdown text; click for the dropdown; ⌃⌥D from anywhere | Scheduled with macOS |
| Windows 10+ | Icon (countdown in the tooltip); click for the dropdown; ⌃⌥D | Delivered by the app while it runs — keep **Launch at login** on |
| Linux | Tray icon menu (GNOME needs the AppIndicator extension) | Same as Windows |
| Android 8+ | — (tabs: Upcoming, Calendar, Settings) | Scheduled with Android; allow **Alarms & reminders** in Settings for on-time delivery |

## Download

Builds for every platform are attached to each [CI run](../../actions) (Artifacts section).
The app isn't code-signed, so on macOS right-click → **Open** the first time, and on Windows choose
**More info → Run anyway**.

## Build from source

Requires Flutter 3.47.x (see [`docs/toolchain.md`](docs/toolchain.md)).

```sh
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # generates the database code
flutter run -d macos        # or windows, linux, an Android device/emulator
```

Linux build machines need: `sudo apt-get install libgtk-3-dev libx11-dev libxi-dev libkeybinder-3.0-dev ninja-build`.

## Tests

```sh
TZ=America/New_York flutter test
```

The time zone is fixed because the reminder tests check daylight-saving behavior. All rules (countdowns,
reminder planning, quick add, sorting, import) live in `lib/core/` as plain Dart with unit tests; widget tests
cover the main screens.

## Project layout

```
lib/core/        rules, no Flutter imports: models, countdown text, reminder planning, quick-add parser
lib/data/        SQLite database (Drift) and repository — soft deletes, ready for sync
lib/state/       Riverpod providers: settings, minute-exact clock, selection
lib/platform/    notifications, tray/window/hotkey shell
lib/ui/          desktop (calendar window, tray popup) and mobile (tabs) screens
docs/superpowers design spec and implementation plan
```

Coming from the original SwiftUI Mac app? On first launch on macOS, its deadlines are imported automatically.

## License

[MIT](LICENSE)
