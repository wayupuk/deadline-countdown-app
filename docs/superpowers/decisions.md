# Decisions made while building project 1

Every deliberate deviation from the plan (`Ruling:`), with what it costs if wrong, and the review findings deferred for later. Copied from the build ledger.

## Rulings

- Setup: Ruling: no worktree — brand-new repo with nothing on main to protect; user asked to proceed — cost if wrong: none (history is linear from scaffold).
- - T2/T9: Drift generates row classes `Deadline`/`Group` from tables Deadlines/Groups → clash with core models in repository_test (imports both unprefixed). Ruling: annotate tables @DataClassName('DeadlineRow') / @DataClassName('GroupRow'); repository maps db.DeadlineRow/db.GroupRow — cost if wrong: renames in one file.
- Task 0: Ruling: Android platform 36 / build-tools 36.1.0 / AVD pixel36 instead of plan's 35 — 36 is current and what Flutter 3.47 targets — cost if wrong: one sdkmanager install.
- Task 0: Ruling: Xcode license + runFirstLaunch need sudo (user's password) — deferred to before Task 13; DEVELOPER_DIR used meanwhile — cost if wrong: macOS build blocked until user runs two commands.
- Task 1: Ruling: removed sqlite3_flutter_libs — 0.6.0+eol is a no-op for sqlite3 3.x, which bundles SQLite itself — cost if wrong: re-add one dependency.
- Task 1: Ruling: display name "Deadline Countdown" set on all platforms; binary names stay "deadlines" — cost if wrong: cosmetic.
- Task 2: Ruling: tests run with Command Line Tools (DEVELOPER_DIR unset) — sqlite3 native-asset build needs lipo and Xcode's license isn't accepted yet — cost if wrong: none, CLT is the host toolchain for tests
- Task 4: Ruling: daily loop also stops past `until` — avoids walking every day to a far deadline in in-app mode; same output — cost if wrong: none (tests cover window)
- Task 5: Ruling: added letter guards on English month/weekday names (+ test 'month names inside ordinary words are not dates', RED without guards → GREEN) — plan's regex read 'Grammar 2' as March 2 — cost if wrong: a month typed glued to letters isn't recognised
- Task 6: Ruling: date grammar time lookahead changed to (?!\w|:\d) — plan's (?![\w:]) rejected '9am:'; test 'Nov 5 2030 9am: call mom' RED→GREEN — cost if wrong: none
- Task 7: Ruling: Thai region (en-TH/th_TH) defaults to Buddhist years; explicit @calendar= tag wins — macOS reports 'en-TH' with no calendar tag although this Mac displays BE; plan's test expected th_TH=false — cost if wrong: a Thai-region user who prefers Gregorian flips one setting
- Task 8: Ruling: CI pinned to Flutter 3.47.7 (matches local) — cost if wrong: manual bump later
- Task 8: Ruling: remote switched to HTTPS with repo-local gh credential helper — SSH key not set up for GitHub — cost if wrong: none
- Task 9: Ruling: Drift option is storeDateTimeAsText in 2.35 (plan said storeDateTimeValuesAsText) — cost if wrong: none
- Task 9: Ruling: repository returns createdAt/updatedAt/deletedAt as UTC, dueAt as local; added test 'round-trips every field' — catches column-mapping slips the plan's tests wouldn't — cost if wrong: none
- Task 10: Ruling: Scheduler returns Timer? (tests return null) instead of the plan's static _lastTimer hack — cost if wrong: none
- Task 10: Ruling: AppSettings.load/save are pure over SharedPreferences with localeName/inAppReminders injected; SettingsNotifier.update(fn) — testable without Platform — cost if wrong: none
- Task 10: Ruling: added settings_test and providers_test (nearestProvider) — plan only tested the ticker — cost if wrong: none
- Task 11: Ruling: ReminderService lives in notifications.dart (no separate in_app_reminders.dart); timers injectable; added test 'in-app mode shows the reminder when its timer fires, and replan drops old timers' — cost if wrong: none
- Task 11: Ruling: kept in-app delivery on Windows even though flutter_local_notifications 22 can schedule Windows toasts — spec decision; possible later improvement — cost if wrong: Windows reminders need the app running
- Task 11: Ruling: models imported 'show Deadline' in notifications.dart — plugin exports its own Priority — cost if wrong: none
- Task 12: Ruling: added core/date_format.dart (dueLabel/dueLabelLong/monthTitle, BE-aware) with tests — UI needed one tested place for date text — cost if wrong: none
- Task 12: Ruling: widget tests use FakeRepository (implements DeadlineRepository) instead of an in-memory Drift DB — avoids DB stream timers in widget tests; Drift itself is covered by test/data — cost if wrong: none
- Task 12: Ruling: added group_manager_test (add, delete-with-confirm moves deadlines to No group) — spec requires group CRUD; plan had no test — cost if wrong: none
- Task 12: Ruling: editor is a Dialog on all platforms with a fixed footer (Cancel / Add Deadline); 'New group…' inside the group dropdown — cost if wrong: layout tweak
- Task 13: Ruling: tray uses tray_manager 0.8's native TrayIcon API (legacy API deprecated); Linux: clicks don't emit events → context menu on any click — cost if wrong: Linux users open the popup via menu
- Task 13: Ruling: CI Linux packages libx11-dev/libxi-dev replace libayatana-appindicator3-dev (tray_manager 0.8 README) — cost if wrong: Linux CI build fails, one-line fix
- Task 13: Ruling: launch at login on macOS via SMAppService in MainFlutterWindow.swift instead of LaunchAtLogin SPM package — no Xcode GUI step — cost if wrong: macOS 12 users can't toggle it (needs 13+)
- Task 13: Ruling: macOS app sandbox disabled (Debug+Release) — sandbox blocks the Mac-app import and isn't needed outside the App Store; revisit in project 4 — cost if wrong: App Store submission needs re-enabling + file-picker import
- Task 13: Ruling: AppDelegate keeps running after last window closes; Dock click reopens — tray app behavior — cost if wrong: none
- Task 13: Ruling: DayCell detects double-click from tap timestamps (no DoubleTapGestureRecognizer) — recognizer delayed every chip tap by 300 ms — cost if wrong: none
- Task 13: Ruling: app + tray icons generated by tool/make_icons.swift + tool/pack_ico.py (committed outputs) — cost if wrong: none
- Task 14/15: Ruling: Task 15 executed before Task 14 — Android Settings tab needs Task 15's SettingsPage — cost if wrong: none
- Task 15: Ruling: services layer (servicesProvider, notificationPermissionProvider, scheduledCountProvider, startupNoticesProvider) so Settings/banners read status without platform calls in tests — cost if wrong: none
- Task 15: Ruling: precision uses RadioGroup (RadioListTile groupValue deprecated in Flutter 3.47) — cost if wrong: none
- Task 15: Ruling: reminders re-planned on deadline change, day change (hourly for in-app 24 h window), and app resume — cost if wrong: in-app reminders >24h away wait for the next hourly replan (by design)
- Task 15: Ruling: settings test scoped to CountdownCard (radio subtitle also shows '79d 1h') — cost if wrong: none
- Task 14: Ruling: exact-alarm permission requested only from a Settings button (plan said on first launch) — automatic request opened the system page at every launch on Android 16 — cost if wrong: users who skip Settings get inexact (minutes-late) reminders until they tap Allow
- Task 14: Ruling: month grid title shrinks to fit (FittedBox) — 167 px overflow at phone width caught by home_tabs_test — cost if wrong: none
- Task 8: Ruling: macOS removed from CI build matrix — macOS minutes count 10x on private-repo free allowance; macOS is built locally — cost if wrong: no CI macOS artifact
- Task 13/15: Ruling: notification permission requested after runApp (plan: before) — awaiting the macOS prompt before runApp left a black window — cost if wrong: none
- Final: Ruling: I5 rename-failure fallback (fresh file beside the damaged one) and BUSY rethrow have no automated test — can't force a Windows rename failure / BUSY in a unit test — cost if wrong: Windows recovery edge case unverified

## Final review: fixed

- C1 tray countdown never ticks — tray_text_test 'tray text follows the clock' RED→GREEN, suite 82/82
- C2 Android exact-alarm default/abort — notifications_test 'one failing reminder does not stop the rest' RED→GREEN + emulator: exact denied → inexact alarms (window +1h) survive cold restart, suite 82/82
- I1 cancelAll wiped delivered notifications — notifications_test cancelPending/in-app-no-cancel RED→GREEN, suite 82/82
- I2 overlapping replans — notifications_test 'overlapping replans end with exactly the latest plan' RED→GREEN, suite 82/82
- I3 cap crowded out due/priority — reminders_test 'cap keeps every due-now and priority reminder' RED→GREEN, suite 82/82
- I4 stale group filter — sorting_test 'filter pointing at a deleted group falls back to all' RED→GREEN, suite 82/82
- I5 DB recovery treated any error as corruption — repository_test corrupt+journal RED→GREEN (test asserts no stale journal + fresh DB usable), suite 82/82
- I6 single instance (Windows mutex + FindWindow, Linux unique GApplication + present existing window) — native code, verified by CI compile only — cost if wrong: duplicate instances on Windows/Linux
- I7 GNOME without tray host — linux_tray_test RED→GREEN for the D-Bus check; end-to-end Linux unverified (no Linux machine)
- I8 Mac import could crash startup — mac_import_runner_test (FileSystemException, TypeError) RED→GREEN, suite 82/82
- I9 missing exact-alarm banner — home_tabs_test 'warns when reminders cannot be exact' RED→GREEN + emulator screenshot, suite 82/82

## Final review: deferred (minor)

- hotkey conflicts never detected on Windows/macOS; Windows/Linux show Mac-style ⌃⌥ symbols
- date grammar false positives (SAT/Sun/wed words, '1/2 of', Feb 30/25:00/13pm roll over, 'tonight 11pm')
- two-digit BE years ('25/12/69' → 2069)
- '#Thesis Work' (group names with spaces) not matched
- calendar window opens at every login (should start hidden when launched at login)
- Dock click in popup mode shows the popup window, not the calendar
- double Enter in quick add can create a duplicate; Details… after some errors clears the text
- Android notification tap from a closed app doesn't open the deadline (getNotificationAppLaunchDetails unused)
- daily and priority reminder can fire in the same minute
- Windows/Linux in-app reminders missed during sleep are not shown on wake

## Not verified

- Windows and Linux builds are compiled by CI but have never been run on a real Windows or Linux machine.
- Windows/Linux data-folder paths in the README follow path_provider's conventions; not checked on a real install.
- macOS tray popup and ⌃⌥D were not exercised automatically (no Accessibility permission for synthetic input).
