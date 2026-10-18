# Deadline Countdown (Flutter) — Project 1 Design Spec

Date: 2026-10-18
Status: Draft — awaiting review

## Where this fits

The user wants the Deadline Countdown app on Android, Windows, Linux and macOS, with Google Classroom
import, groups, priorities, and shared calendar spaces for many users. That is split into four projects,
each with its own spec → plan → build:

1. **This spec — standalone Flutter app**: today's Mac app features + groups + priority, all four platforms, local data only.
2. Accounts + shared spaces: sign-in, sync backend, invites, roles (owner / editor / viewer), live updates.
3. Google Classroom import: each user's own assignments into their personal space only (never shared automatically).
4. Release: installers, store listings, Google OAuth verification (needed beyond 100 Classroom test users).

Project 1 must not build anything from projects 2–4, but its data model must make project 2 possible without a rewrite.

## Decisions (from Q&A)

| Topic | Decision |
|---|---|
| Framework | Flutter, one codebase for Android, Windows, Linux, macOS |
| Mac SwiftUI app | Kept and untouched; replaced only once this app has parity |
| Groups | Named list with a color; a deadline belongs to at most one group ("No group" is gray) |
| Priority | Low / Normal / High / Urgent, set by the user; changes sort order and adds reminders |
| Shared-space roles (project 2) | Owner, editor, viewer |
| Classroom data (project 3) | Private to the importing user |
| Toolchain location | an APFS disk image on an external drive, mounted as `$DEVTOOLS` |

## Constraints

- The internal disk had little free space. Flutter SDK, pub cache, Android SDK, Gradle cache and Xcode live on
  `$DEVTOOLS`, an APFS disk image on an external drive that mounts at login.
- Xcode must be downloaded by the user from developer.apple.com (App Store can't install to an external volume).
  It's required only for the macOS build.
- Windows and Linux builds can't be produced on a Mac → GitHub Actions (`windows-latest`, `ubuntu-latest`).
  Needs a GitHub repository; `gh` is currently logged out.
- `NSDataDetector` (used by the Mac app's quick add) doesn't exist elsewhere → quick add parser is reimplemented in Dart.

## Architecture

```
deadline_countdown_app/
├── lib/
│   ├── core/            # pure Dart, no Flutter imports — fully unit-tested
│   │   ├── models/      # Deadline, Group, Priority, Settings value types
│   │   ├── countdown/   # formatter (precision), tick timing, progress
│   │   ├── reminders/   # planner: daily + priority + due-now notices
│   │   ├── quick_add/   # natural-language parser
│   │   └── import/      # Mac app deadlines.json importer
│   ├── data/            # Drift (SQLite) database, repositories
│   ├── platform/        # notifications, tray, hotkey, launch-at-login adapters per OS
│   ├── state/           # Riverpod providers
│   └── ui/              # desktop (window + tray popup) and mobile layouts, shared widgets
├── test/                # unit tests (core) + widget tests (key screens)
└── .github/workflows/   # CI: test + build android, linux, windows, macos
```

Packages (pinned in the plan after checking current versions): `flutter_riverpod`, `drift` + `sqlite3_flutter_libs`,
`flutter_local_notifications`, `timezone`, `tray_manager`, `window_manager`, `hotkey_manager`,
`launch_at_startup`, `intl`, `uuid`.

Identifiers: app name **Deadline Countdown**, application/bundle id **`com.wayupuk.deadlines`** on every platform
(distinct from the Mac app's `com.wayupuk.DeadlineCountdown`, so both can be installed side by side).

## Data model (sync-ready)

All records: `id` (UUID v4 string), `createdAt`, `updatedAt` (UTC), `deletedAt` (UTC, nullable — soft delete).
Lists never show soft-deleted rows. Project 2 will add `spaceId` and `createdBy`.

**Group**: `name` (required, ≤ 40 chars), `color` (one of the Mac app's 9 colors), `sortOrder` (int).

**Deadline**: `title` (required), `dueAt` (UTC instant), `groupId` (nullable), `priority`
(`low | normal | high | urgent`, default `normal`), `notes`, `reminderEnabled` (default true),
`reminderHour`/`reminderMinute` (local wall-clock, default 09:00).

**Settings** (local, not synced): countdown precision (`days | hours | minutes`, default `hours`),
show countdown next to tray icon, Buddhist-era years (default on when the OS locale has `calendar=buddhist`),
launch at login (desktop; default on for Windows/Linux), selected group filter.

## Behavior carried over from the Mac app

Each rule below already has checks in the Mac app's `DeadlineCoreChecks`; they are ported as Dart unit tests.

- **Countdown text**: `short` with precision (`79d`, `79d 1h`, `79d 1h 23m`; under a day `4h 12m`; under an hour
  `12m`; `<1m`; `Overdue`); `clock` (`12d 04:22:51`); `sentence` (`5 days, 3 hours left`, `Due now`).
  Units truncate, never round up. Progress = elapsed share of `createdAt…dueAt`, clamped 0…1.
- **Exact minute ticks**: the shared clock re-arms for the moment the nearest deadline's minute changes
  (`secondsUntilNextChange`), and on wake/day change.
- **Daily reminders**: at each deadline's local reminder time, strictly after now and before `dueAt`; wall-clock
  stable across DST; "due now" notice at `dueAt`; none for overdue deadlines; reminder text computed at fire time.
- **Quick add** (Dart parser, same cases as today): `Thesis Oct 24 5pm`, `tomorrow 9am`, `next friday`, `in 3 days`,
  `24/10 14:00` (day first), ISO `2027-02-10T06:59:59+07:00`, JavaScript `Wed Feb 10 2027 06:59:59 GMT+0700 (Indochina Time)`,
  ranges `due by` / `before` / `until` → end date, Thai month abbreviations (`25 ธ.ค.`), Buddhist-era years (`2569`),
  connector words trimmed from the title, inner punctuation kept, no time → 23:59, errors: empty / no date / no title / in the past.
  Supported phrasing is the spec; anything else shows "Add a date…" rather than guessing.
- **Mac data import**: on first launch on macOS, if `~/Library/Application Support/DeadlineCountdown/deadlines.json`
  exists, import it once (dates are seconds since 2001-01-01; ids kept). Imported deadlines go to "No group";
  per-deadline colors are not kept (groups own colors now). A notice says how many were imported.

## New: groups and priority

- Groups: create / rename / recolor / reorder / delete (deadlines in a deleted group move to "No group", after confirmation).
- Filter by group in the sidebar (desktop), chips (Android) and the tray popup; filter persists.
- Sort for "Upcoming": priority (urgent → low), then `dueAt` ascending. "Past": `dueAt` descending.
  The tray countdown always shows the **nearest** upcoming deadline regardless of priority.
- Extra reminders (on top of daily ones; all off when the deadline's reminders are off, except "due now"):
  High → 24 h before; Urgent → 24 h, 3 h and 1 h before. Skipped if already past.
- Quick add accepts an optional priority marker `!` (high) or `!!` (urgent) and `#group` (existing group name,
  case-insensitive; unknown → error "No group named …").

## Platforms

| | Tray / menu bar | Main UI | Reminder delivery | Pending cap |
|---|---|---|---|---|
| macOS | Icon + countdown text; click → popup window (cards, quick add, group filter); ⌃⌥D toggles | Month calendar + sidebar + detail | OS-scheduled (`zonedSchedule`) | 60 (OS max 64) |
| Windows | Icon; countdown in tooltip; same popup; ⌃⌥D | Same | In-app scheduler while running in tray | 24 h window, re-planned |
| Linux | AppIndicator icon (GNOME needs the AppIndicator extension; KDE native); popup | Same | In-app scheduler while running in tray | 24 h window, re-planned |
| Android | — | Tabs: Upcoming (quick add, chips, cards) / Calendar / Settings | OS-scheduled exact alarms (requests notification + "Alarms & reminders" permission) | 200 |

Windows/Linux reminders fire only while the app runs; launch at login defaults on there, and Settings says so.

## Error handling

| Situation | Behavior |
|---|---|
| Notification permission denied | Banner with button to the OS settings page (all platforms) |
| Exact-alarm permission denied (Android) | Banner; reminders fall back to inexact delivery (may arrive minutes late) |
| Database open/migration failure | Copy the DB file aside (`deadlines.corrupt-<time>.db`), start fresh, show the path |
| Mac import file unreadable | Skip import, show notice, don't retry automatically |
| Tray unavailable (Linux without AppIndicator) | App runs as a normal window; Settings explains how to enable the tray |
| Hotkey taken by another app | Settings shows "⌃⌥D is used by another app" |

## Testing

- Unit tests (`flutter test test/core`): every carried-over rule above plus groups/priority sorting, extra reminders,
  quick-add `!`/`#group`, Mac import (sample JSON from the Mac app's format), soft-delete filtering.
- Widget tests: quick add field states, Upcoming list sort/filter, editor validation.
- CI (GitHub Actions): tests + build artifacts for Android (APK), Linux (bundle), Windows (zip), macOS (app).
- Manual on this Mac: macOS app (tray, popup, notifications, import of the 3 current deadlines) and Android emulator.
  Windows/Linux: run the CI artifacts on a real machine or VM when available — not verifiable from this Mac.

## Out of scope (projects 2–4)

Accounts, sync, shared spaces, Google Classroom, store publishing, Android home-screen widget, iOS.
