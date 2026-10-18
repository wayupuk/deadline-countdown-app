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

## Install

Download the file for your system from the **[latest release](../../releases/latest)**. The app is free and
open source; it isn't signed with paid Apple/Microsoft certificates, so your system will ask you to confirm
the first time you open it — the steps below show how.

### macOS (12 Monterey or later)

1. Download **`DeadlineCountdown-macos.zip`** and double-click it to unzip.
2. Drag **Deadline Countdown** into your **Applications** folder.
3. Open it. macOS says it "can't verify" the app — click **Done**, then go to
   **System Settings → Privacy & Security**, scroll down, and click **Open Anyway** next to Deadline Countdown.
   *(Or in Terminal: `xattr -dr com.apple.quarantine "/Applications/Deadline Countdown.app"`.)*
4. Click **Allow** when asked about notifications.
5. Look for **⏳** in the menu bar. On MacBooks with a notch, menu bar icons that don't fit are hidden behind it —
   press **⌃⌥D** to open the dropdown anyway, or ⌘-drag other icons to make room.
6. Optional: **Settings → Launch at login** keeps the countdown in your menu bar after restarts.

### Windows (10 or 11, 64-bit)

1. Download **`DeadlineCountdown-windows-x64.zip`**, right-click it → **Extract All…**, and pick a folder you'll
   keep (for example `Documents\DeadlineCountdown`). Don't run it from inside the zip.
2. Open the folder and double-click **`deadlines.exe`**.
3. If "Windows protected your PC" appears, click **More info → Run anyway**.
4. The ⏳ icon is in the system tray; if you don't see it, click **^** next to the clock and drag it onto the taskbar.
   **Ctrl+Alt+D** opens the dropdown from anywhere.
5. Reminders are shown by the app itself, so it must be running: **Launch at login** is on by default. If you move
   the folder later, turn it off and on again in Settings.
6. Optional: right-click `deadlines.exe` → **Pin to Start**.

### Linux (64-bit; Ubuntu 22.04+, Fedora 38+ or similar)

1. Install the two libraries it needs:
   - Ubuntu / Debian: `sudo apt install libgtk-3-0 libkeybinder-3.0-0`
   - Fedora: `sudo dnf install gtk3 keybinder3`
2. Download **`DeadlineCountdown-linux-x64.tar.gz`**, then:
   ```sh
   tar -xzf DeadlineCountdown-linux-x64.tar.gz
   ./DeadlineCountdown/install.sh
   ```
   This installs for your user only (no `sudo`) and adds **Deadline Countdown** to your app menu.
3. **GNOME (Ubuntu's default desktop):** install the
   [AppIndicator and KStatusNotifierItem Support](https://extensions.gnome.org/extension/615/appindicator-support/)
   extension (preinstalled on Ubuntu) so the tray icon appears. Without a tray the app simply stays a normal window.
4. Reminders are shown by the app itself, so keep **Launch at login** on (it is by default).
   **Ctrl+Alt+D** works on X11; on Wayland use the tray icon instead.

### Android (8.0 or later)

1. On your phone, download **`DeadlineCountdown-android.apk`** and open it.
2. If asked, allow your browser to **install unknown apps**, then tap **Install**. If Play Protect warns about an
   unknown developer, tap **More details → Install anyway**.
3. Open the app and tap **Allow** for notifications.
4. If you see **"Reminders may arrive late"**, tap **Allow** and switch on **Alarms & reminders** so reminders come
   at the exact minute.

### Updating and uninstalling

Install a newer release the same way, replacing the old app. Your deadlines are stored separately and are kept.

| | Remove the app | Remove your data too |
|---|---|---|
| macOS | Drag it from Applications to the Trash | Delete `~/Library/Application Support/com.wayupuk.deadlines` |
| Windows | Turn off Launch at login, then delete the folder | Delete `%APPDATA%\com.wayupuk\Deadline Countdown` |
| Linux | `rm -rf ~/.local/share/deadline-countdown ~/.local/bin/deadline-countdown ~/.local/share/applications/deadline-countdown.desktop` | Delete `~/.local/share/com.wayupuk.deadlines` |
| Android | Long-press the icon → **Uninstall** | Removed with the app |

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
