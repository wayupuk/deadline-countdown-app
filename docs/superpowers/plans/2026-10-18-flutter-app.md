# Deadline Countdown (Flutter) — Project 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A Flutter app for macOS, Android, Windows and Linux with everything the SwiftUI Mac app does today, plus groups and priority, storing data locally in a sync-ready format.

**Architecture:** All rules (countdown text, reminder planning, quick-add parsing, Mac import, sorting) live in pure Dart under `lib/core/` with unit tests ported from the Mac app's 109 checks. Drift/SQLite stores data; Riverpod exposes it; thin platform adapters handle notifications, tray, hotkey and launch-at-login; UI has a desktop layout (tray popup + calendar window) and a mobile layout (tabs).

**Tech Stack:** Flutter (stable), Dart 3, flutter_riverpod, drift + sqlite3_flutter_libs, flutter_local_notifications + timezone + flutter_timezone, tray_manager, window_manager, hotkey_manager, launch_at_startup, intl, uuid, path_provider.

**Spec:** `docs/superpowers/specs/2026-10-18-flutter-app-design.md`

## Global Constraints

- Project root: `~/code/deadline_countdown_app`. Platforms: android, macos, windows, linux.
- App name **Deadline Countdown**; application/bundle id **`com.wayupuk.deadlines`** on every platform.
- Toolchain lives on `$DEVTOOLS` (APFS sparse bundle): Flutter SDK `$DEVTOOLS/flutter`, `PUB_CACHE=$DEVTOOLS/pub-cache`, `ANDROID_HOME=$DEVTOOLS/android-sdk`, `GRADLE_USER_HOME=$DEVTOOLS/gradle`, Xcode at `$DEVTOOLS/Xcode.app` (user downloads it).
- `lib/core/**` must not import `package:flutter/*`. Run core tests with `TZ=America/New_York` (DST checks depend on it); CI sets the same.
- Every record: `id` (UUID v4), `createdAt`, `updatedAt` (UTC), `deletedAt` (UTC, nullable). Queries exclude soft-deleted rows.
- Priorities: `low | normal | high | urgent` (default `normal`). Colors: `blue, purple, pink, red, orange, yellow, green, teal, graphite`.
- Pending-notification caps: macOS 60, Android 200; Windows/Linux plan a rolling 24 h window in-app.
- Countdown units truncate, never round up. No time typed in quick add → 23:59 local.
- Hotkey ⌃⌥D (desktop). Mac data file: `~/Library/Application Support/DeadlineCountdown/deadlines.json`, dates = seconds since 2001-01-01T00:00:00Z.

## Review Focus

1. Quick add `Jan 5` typed in October → must mean **next** January, not a date in the past (Task 6 test `year rolls forward`).
2. Quick add `7:30` with no am/pm → 07:30 (24-hour reading), shown in the preview before saving (Task 6 test `24h clock`).
3. Deleting a group that still has deadlines → deadlines move to "No group", never deleted (Task 9 test `deleting a group keeps its deadlines`).
4. Reminder for a deadline edited to an earlier time → old pending notifications gone (Task 11: adapter cancels all before scheduling; test `reschedule cancels first` with a fake plugin).
5. Corrupt/locked database file → app still opens with an empty list and a message (Task 9 test `corrupt file is moved aside`).

---

## File Structure

```
lib/
  main.dart                          # bootstrap: DB, timezone, platform adapters, runApp
  app.dart                           # MaterialApp, theme, layout switch (desktop vs mobile)
  core/
    models.dart                      # Priority, DeadlineColor, Group, Deadline, CountdownPrecision
    sorting.dart                     # upcoming/past ordering, group filter
    countdown.dart                   # short/clock/sentence/progress/secondsUntilNextChange
    reminders.dart                   # planReminders, PlannedReminder, stableNotificationId
    quick_add/
      date_grammar.dart              # finds a date/time phrase in text → DateMatch
      quick_add_parser.dart          # title, priority markers, #group, errors
    mac_import.dart                  # parses the SwiftUI app's deadlines.json
    year_format.dart                 # Gregorian / Buddhist-era year labels
  data/
    database.dart                    # Drift tables + DB open/corruption handling
    database.g.dart                  # generated
    repository.dart                  # CRUD with soft delete, group delete semantics
  platform/
    notifications.dart               # NotificationPort interface + FlutterLocalNotifications adapter
    in_app_reminders.dart            # Windows/Linux timer-based delivery
    desktop_shell.dart               # tray, popup window, hotkey, launch at login
  state/
    providers.dart                   # Riverpod providers: db, repo, deadlines, groups, settings, clock
    clock.dart                       # minute-exact ticker
    settings.dart                    # SharedPreferences-backed settings
  ui/
    widgets/countdown_card.dart
    widgets/quick_add_field.dart
    widgets/deadline_editor.dart
    widgets/group_manager.dart
    widgets/banners.dart
    desktop/main_window.dart         # sidebar + month grid + detail
    desktop/month_grid.dart
    desktop/detail_pane.dart
    desktop/tray_popup.dart
    mobile/home_tabs.dart            # Upcoming / Calendar / Settings
    settings_page.dart
test/core/*_test.dart                # one file per core unit
test/data/repository_test.dart
test/ui/*_test.dart                  # widget tests
.github/workflows/ci.yml
```

---

### Task 0: Toolchain on $DEVTOOLS

**Files:** Modify the shell profile (append a marked block). No project files.

- [ ] **Step 1: Confirm the volume is mounted**

Run: `diskutil info $DEVTOOLS | grep "File System Personality"`
Expected: `APFS`

- [ ] **Step 2: Install Flutter SDK (stable) on the volume**

```bash
git clone --depth 1 -b stable https://github.com/flutter/flutter.git $DEVTOOLS/flutter
```

- [ ] **Step 3: Add environment block to the shell profile** (back it up first)

```bash
# >>> DevTools (Deadline Countdown) >>>
export PATH="$DEVTOOLS/flutter/bin:$PATH"
export PUB_CACHE="$DEVTOOLS/pub-cache"
export ANDROID_HOME="$DEVTOOLS/android-sdk"
export GRADLE_USER_HOME="$DEVTOOLS/gradle"
export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"
# <<< DevTools <<<
```

- [ ] **Step 4: JDK 17 for Android builds**: `brew install openjdk@17`, then `flutter config --jdk-dir "$(brew --prefix openjdk@17)/libexec/openjdk.jdk/Contents/Home"`

- [ ] **Step 5: Android SDK command-line tools** — download the macOS "commandlinetools" zip from developer.android.com/studio#command-tools into the volume, unzip to `$ANDROID_HOME/cmdline-tools/latest`, then:

```bash
yes | sdkmanager --licenses
sdkmanager "platform-tools" "platforms;android-35" "build-tools;35.0.0" "emulator" "system-images;android-35;google_apis;arm64-v8a"
avdmanager create avd -n pixel35 -k "system-images;android-35;google_apis;arm64-v8a" -d pixel_8
```

- [ ] **Step 6: Xcode (after the user has expanded it on the volume)**

```bash
sudo xcode-select -s $DEVTOOLS/Xcode.app
sudo xcodebuild -license accept && xcodebuild -runFirstLaunch
brew install cocoapods
defaults write com.apple.dt.Xcode IDECustomDerivedDataLocation $DEVTOOLS/DerivedData
```

- [ ] **Step 7: Verify**: `flutter doctor -v`
Expected: Flutter ✓, Android toolchain ✓, Xcode ✓ (or Xcode pending if not yet downloaded — Tasks 1–10 don't need it). Record versions in `docs/toolchain.md`.

---

### Task 1: Scaffold the project

**Files:** Create the Flutter project, `analysis_options.yaml`, `.gitignore`, `docs/toolchain.md`.

**Interfaces:** Produces package name `deadlines` (import prefix `package:deadlines/...`).

- [ ] **Step 1: Create**

```bash
cd ~/code
flutter create --org com.wayupuk --project-name deadlines --platforms android,macos,windows,linux deadline_countdown_app
```
(The folder already holds `docs/`; `flutter create` adds files around it.)

- [ ] **Step 2: Set ids and display name**
  - Android `android/app/build.gradle(.kts)`: `applicationId = "com.wayupuk.deadlines"`; `android/app/src/main/AndroidManifest.xml` `android:label="Deadline Countdown"`.
  - macOS `macos/Runner/Configs/AppInfo.xcconfig`: `PRODUCT_NAME = Deadline Countdown`, `PRODUCT_BUNDLE_IDENTIFIER = com.wayupuk.deadlines`.
  - Windows `windows/runner/Runner.rc` + `main.cpp` window title: `Deadline Countdown`.
  - Linux `linux/CMakeLists.txt`: `APPLICATION_ID "com.wayupuk.deadlines"`, `BINARY_NAME "deadlines"`.

- [ ] **Step 3: Dependencies**

```bash
flutter pub add flutter_riverpod drift sqlite3_flutter_libs path_provider path shared_preferences \
  flutter_local_notifications timezone flutter_timezone tray_manager window_manager hotkey_manager \
  launch_at_startup intl uuid
flutter pub add --dev drift_dev build_runner
```
Record the resolved versions from `pubspec.lock` in `docs/toolchain.md`.

- [ ] **Step 4: Lints** — `analysis_options.yaml`: include `package:flutter_lints/flutter.yaml`; add `prefer_single_quotes: true`, `always_declare_return_types: true`.

- [ ] **Step 5: Verify**: `flutter analyze && flutter test` → no issues, default test passes. Delete the default counter test afterwards.

- [ ] **Step 6: Commit**: `git init && git add -A && git commit -m "chore: scaffold Flutter app (android, macos, windows, linux)"`

---

### Task 2: Core models and sorting

**Files:** Create `lib/core/models.dart`, `lib/core/sorting.dart`; Test `test/core/sorting_test.dart`.

**Interfaces — Produces:**
```dart
enum Priority { low, normal, high, urgent }            // rank = index
enum DeadlineColor { blue, purple, pink, red, orange, yellow, green, teal, graphite }
enum CountdownPrecision { days, hours, minutes }      // unitCount 1, 2, 3
class Group { String id; String name; DeadlineColor color; int sortOrder; DateTime createdAt, updatedAt; DateTime? deletedAt; }
class Deadline { String id; String title; DateTime dueAt; String? groupId; Priority priority; String notes;
                 bool reminderEnabled; int reminderHour, reminderMinute; DateTime createdAt, updatedAt; DateTime? deletedAt;
                 bool isOverdue(DateTime now); double progress(DateTime now); Deadline copyWith({...}); }
List<Deadline> upcoming(Iterable<Deadline> all, DateTime now, {String? groupFilter});
List<Deadline> past(Iterable<Deadline> all, DateTime now, {String? groupFilter});
Deadline? nearest(Iterable<Deadline> all, DateTime now);   // ignores priority
const noGroupFilter = '__none__';                           // filter value for "No group"
```

- [ ] **Step 1: Write the failing test** `test/core/sorting_test.dart`

```dart
import 'package:deadlines/core/models.dart';
import 'package:deadlines/core/sorting.dart';
import 'package:test/test.dart';

Deadline d(String title, DateTime due, {Priority p = Priority.normal, String? group, DateTime? deleted}) => Deadline(
      id: title, title: title, dueAt: due, groupId: group, priority: p,
      createdAt: DateTime.utc(2026, 1, 1), updatedAt: DateTime.utc(2026, 1, 1), deletedAt: deleted);

void main() {
  final now = DateTime(2026, 10, 18, 12);
  final a = d('a', now.add(const Duration(days: 3)));
  final b = d('b', now.add(const Duration(days: 1)));
  final u = d('u', now.add(const Duration(days: 9)), p: Priority.urgent);
  final h = d('h', now.add(const Duration(days: 5)), p: Priority.high, group: 'g1');
  final old1 = d('old1', now.subtract(const Duration(days: 1)));
  final old3 = d('old3', now.subtract(const Duration(days: 3)));
  final gone = d('gone', now.add(const Duration(days: 2)), deleted: DateTime.utc(2026, 10, 1));
  final all = [a, b, u, h, old1, old3, gone];

  test('upcoming: priority first, then soonest', () {
    expect(upcoming(all, now).map((x) => x.title), ['u', 'h', 'b', 'a']);
  });
  test('past: most recent first', () {
    expect(past(all, now).map((x) => x.title), ['old1', 'old3']);
  });
  test('nearest ignores priority', () {
    expect(nearest(all, now)?.title, 'b');
  });
  test('soft-deleted never listed', () {
    expect(upcoming(all, now).any((x) => x.title == 'gone'), isFalse);
    expect(nearest([gone], now), isNull);
  });
  test('group filter, including No group', () {
    expect(upcoming(all, now, groupFilter: 'g1').map((x) => x.title), ['h']);
    expect(upcoming(all, now, groupFilter: noGroupFilter).map((x) => x.title), ['u', 'b', 'a']);
  });
  test('progress clamps and survives zero span', () {
    final x = Deadline(id: 'x', title: 'x', dueAt: DateTime(2026, 10, 11), createdAt: DateTime(2026, 10, 1), updatedAt: DateTime(2026, 10, 1));
    expect(x.progress(DateTime(2026, 10, 6)), 0.5);
    expect(x.progress(DateTime(2026, 9, 1)), 0.0);
    expect(x.progress(DateTime(2026, 12, 1)), 1.0);
    final z = x.copyWith(dueAt: x.createdAt);
    expect(z.progress(x.createdAt), 1.0);
    expect(x.isOverdue(DateTime(2026, 10, 11)), isTrue);
  });
}
```

- [ ] **Step 2: Run** `TZ=America/New_York flutter test test/core/sorting_test.dart` → FAIL (missing files).

- [ ] **Step 3: Implement** `lib/core/models.dart`

```dart
enum Priority { low, normal, high, urgent }

enum DeadlineColor { blue, purple, pink, red, orange, yellow, green, teal, graphite }

enum CountdownPrecision {
  days(1), hours(2), minutes(3);
  const CountdownPrecision(this.unitCount);
  final int unitCount;
}

class Group {
  Group({required this.id, required this.name, required this.color, this.sortOrder = 0,
      required this.createdAt, required this.updatedAt, this.deletedAt});
  final String id;
  final String name;
  final DeadlineColor color;
  final int sortOrder;
  final DateTime createdAt, updatedAt;
  final DateTime? deletedAt;

  Group copyWith({String? name, DeadlineColor? color, int? sortOrder, DateTime? updatedAt, DateTime? deletedAt}) => Group(
      id: id, name: name ?? this.name, color: color ?? this.color, sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt, updatedAt: updatedAt ?? this.updatedAt, deletedAt: deletedAt ?? this.deletedAt);
}

class Deadline {
  Deadline({required this.id, required this.title, required this.dueAt, this.groupId,
      this.priority = Priority.normal, this.notes = '', this.reminderEnabled = true,
      this.reminderHour = 9, this.reminderMinute = 0,
      required this.createdAt, required this.updatedAt, this.deletedAt});
  final String id;
  final String title;
  final DateTime dueAt;
  final String? groupId;
  final Priority priority;
  final String notes;
  final bool reminderEnabled;
  final int reminderHour, reminderMinute;
  final DateTime createdAt, updatedAt;
  final DateTime? deletedAt;

  bool isOverdue(DateTime now) => !dueAt.isAfter(now);

  /// Elapsed share of createdAt…dueAt, clamped to 0…1.
  double progress(DateTime now) {
    final total = dueAt.difference(createdAt).inMicroseconds;
    if (total <= 0) return 1;
    return (now.difference(createdAt).inMicroseconds / total).clamp(0.0, 1.0);
  }

  Deadline copyWith({String? title, DateTime? dueAt, Object? groupId = _keep, Priority? priority, String? notes,
      bool? reminderEnabled, int? reminderHour, int? reminderMinute, DateTime? updatedAt, DateTime? deletedAt}) => Deadline(
      id: id, title: title ?? this.title, dueAt: dueAt ?? this.dueAt,
      groupId: identical(groupId, _keep) ? this.groupId : groupId as String?,
      priority: priority ?? this.priority, notes: notes ?? this.notes,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled, reminderHour: reminderHour ?? this.reminderHour,
      reminderMinute: reminderMinute ?? this.reminderMinute, createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt, deletedAt: deletedAt ?? this.deletedAt);
}

const _keep = Object();
```

`lib/core/sorting.dart`

```dart
import 'models.dart';

/// Filter value meaning "deadlines without a group".
const noGroupFilter = '__none__';

Iterable<Deadline> _visible(Iterable<Deadline> all, String? groupFilter) => all.where((d) =>
    d.deletedAt == null &&
    (groupFilter == null || (groupFilter == noGroupFilter ? d.groupId == null : d.groupId == groupFilter)));

/// Not yet due: urgent → low, then soonest first.
List<Deadline> upcoming(Iterable<Deadline> all, DateTime now, {String? groupFilter}) =>
    _visible(all, groupFilter).where((d) => !d.isOverdue(now)).toList()
      ..sort((a, b) {
        final byPriority = b.priority.index.compareTo(a.priority.index);
        return byPriority != 0 ? byPriority : a.dueAt.compareTo(b.dueAt);
      });

/// Already due: most recent first.
List<Deadline> past(Iterable<Deadline> all, DateTime now, {String? groupFilter}) =>
    _visible(all, groupFilter).where((d) => d.isOverdue(now)).toList()..sort((a, b) => b.dueAt.compareTo(a.dueAt));

/// The soonest upcoming deadline regardless of priority — what the tray countdown shows.
Deadline? nearest(Iterable<Deadline> all, DateTime now) {
  Deadline? best;
  for (final d in _visible(all, null)) {
    if (!d.isOverdue(now) && (best == null || d.dueAt.isBefore(best.dueAt))) best = d;
  }
  return best;
}
```

- [ ] **Step 4: Run** the test → PASS. Add `test` as dev dependency if the import fails: `flutter pub add --dev test`.
- [ ] **Step 5: Commit** `git commit -am "feat(core): models, priority-aware sorting, group filter"`

---

### Task 3: Countdown formatting and tick timing

**Files:** Create `lib/core/countdown.dart`; Test `test/core/countdown_test.dart`.

**Interfaces — Produces:**
```dart
String shortCountdown(DateTime now, DateTime due, {CountdownPrecision precision = CountdownPrecision.hours});
String clockCountdown(DateTime now, DateTime due);
String sentenceCountdown(DateTime now, DateTime due);
Duration untilNextChange(DateTime now, DateTime? nextDue);
```

- [ ] **Step 1: Failing test** (ported from the Mac app's checks)

```dart
import 'package:deadlines/core/countdown.dart';
import 'package:deadlines/core/models.dart';
import 'package:test/test.dart';

void main() {
  final now = DateTime(2026, 10, 18, 12);
  Duration dhms(int d, [int h = 0, int m = 0, int s = 0]) => Duration(days: d, hours: h, minutes: m, seconds: s);

  test('short, default hours precision', () {
    expect(shortCountdown(now, now.add(dhms(3, 4, 10))), '3d 4h');
    expect(shortCountdown(now, now.add(dhms(0, 4, 12))), '4h 12m');
    expect(shortCountdown(now, now.add(dhms(0, 0, 12, 30))), '12m');
    expect(shortCountdown(now, now.add(dhms(0, 0, 0, 30))), '<1m');
    expect(shortCountdown(now, now), 'Overdue');
    expect(shortCountdown(now, now.subtract(dhms(0, 1))), 'Overdue');
  });
  test('short precision', () {
    final far = now.add(dhms(3, 4, 10, 30));
    expect(shortCountdown(now, far, precision: CountdownPrecision.days), '3d');
    expect(shortCountdown(now, now.add(dhms(0, 4, 12, 30)), precision: CountdownPrecision.days), '4h');
    expect(shortCountdown(now, far, precision: CountdownPrecision.minutes), '3d 4h 10m');
    expect(shortCountdown(now, now.add(dhms(3, 0, 10)), precision: CountdownPrecision.minutes), '3d 0h 10m');
    expect(shortCountdown(now, now.add(dhms(0, 0, 12, 30)), precision: CountdownPrecision.minutes), '12m');
  });
  test('clock', () {
    expect(clockCountdown(now, now.add(dhms(12, 4, 22, 51))), '12d 04:22:51');
    expect(clockCountdown(now, now.add(dhms(0, 4, 22, 51))), '04:22:51');
    expect(clockCountdown(now, now.subtract(dhms(0, 0, 0, 10))), '00:00:00');
  });
  test('sentence', () {
    final t = DateTime(2026, 10, 18, 9);
    expect(sentenceCountdown(t, t.add(dhms(5, 3))), '5 days, 3 hours left');
    expect(sentenceCountdown(t, t.add(dhms(1))), '1 day left');
    expect(sentenceCountdown(t, t.add(dhms(1, 1))), '1 day, 1 hour left');
    expect(sentenceCountdown(t, t.add(dhms(0, 3, 5))), '3 hours, 5 minutes left');
    expect(sentenceCountdown(t, t.add(dhms(0, 2))), '2 hours left');
    expect(sentenceCountdown(t, t.add(dhms(0, 0, 1))), '1 minute left');
    expect(sentenceCountdown(t, t.add(dhms(0, 0, 0, 20))), 'Less than a minute left');
    expect(sentenceCountdown(t, t), 'Due now');
  });
  test('untilNextChange', () {
    final base = DateTime(2026, 10, 18, 16, 37);
    bool near(Duration a, double secs) => (a.inMicroseconds / 1e6 - secs).abs() < 0.05;
    expect(near(untilNextChange(base.add(const Duration(milliseconds: 12500)), null), 47.5), isTrue);
    expect(near(untilNextChange(base, DateTime(2026, 10, 18, 17)), 0), isTrue);
    expect(untilNextChange(base, DateTime(2026, 10, 18, 17)) > Duration.zero, isTrue);
    expect(near(untilNextChange(base.add(const Duration(seconds: 10)), DateTime(2026, 10, 18, 17, 59, 59)), 49), isTrue);
    final due = DateTime(2026, 10, 18, 17, 59, 59);
    final start = base.add(const Duration(seconds: 10));
    final tick = start.add(untilNextChange(start, due));
    expect(shortCountdown(start, due, precision: CountdownPrecision.minutes),
        isNot(shortCountdown(tick, due, precision: CountdownPrecision.minutes)));
  });
}
```

- [ ] **Step 2: Run** `TZ=America/New_York flutter test test/core/countdown_test.dart` → FAIL.

- [ ] **Step 3: Implement** `lib/core/countdown.dart`

```dart
import 'models.dart';

class _Parts {
  _Parts(Duration d) : total = d.isNegative ? 0 : d.inSeconds;
  final int total;
  int get days => total ~/ 86400;
  int get hours => total % 86400 ~/ 3600;
  int get minutes => total % 3600 ~/ 60;
  int get seconds => total % 60;
}

/// "3d 4h" (hours), "3d" (days), "3d 4h 10m" (minutes); "4h 12m", "12m", "<1m", "Overdue".
String shortCountdown(DateTime now, DateTime due, {CountdownPrecision precision = CountdownPrecision.hours}) {
  final left = due.difference(now);
  if (left <= Duration.zero) return 'Overdue';
  final p = _Parts(left);
  final units = [(p.days, 'd'), (p.hours, 'h'), (p.minutes, 'm')];
  final first = units.indexWhere((u) => u.$1 > 0);
  if (first < 0) return '<1m';
  final end = (first + precision.unitCount).clamp(0, units.length);
  return units.sublist(first, end).map((u) => '${u.$1}${u.$2}').join(' ');
}

String clockCountdown(DateTime now, DateTime due) {
  final p = _Parts(due.difference(now));
  String two(int v) => v.toString().padLeft(2, '0');
  final hms = '${two(p.hours)}:${two(p.minutes)}:${two(p.seconds)}';
  return p.days > 0 ? '${p.days}d $hms' : hms;
}

String sentenceCountdown(DateTime now, DateTime due) {
  final left = due.difference(now);
  if (left <= Duration.zero) return 'Due now';
  final p = _Parts(left);
  final List<(int, String)> units;
  if (p.days > 0) {
    units = [(p.days, 'day'), (p.hours, 'hour')];
  } else if (p.hours > 0) {
    units = [(p.hours, 'hour'), (p.minutes, 'minute')];
  } else if (p.minutes > 0) {
    units = [(p.minutes, 'minute')];
  } else {
    return 'Less than a minute left';
  }
  final text = units.where((u) => u.$1 > 0).map((u) => '${u.$1} ${u.$2}${u.$1 == 1 ? '' : 's'}').join(', ');
  return '$text left';
}

/// Time until a minute-precision countdown to [nextDue] changes. Countdowns round down, so the change
/// lands just after a whole minute remains (+10 ms). No upcoming deadline → next wall-clock minute.
Duration untilNextChange(DateTime now, DateTime? nextDue) {
  const margin = Duration(milliseconds: 10);
  final remaining = nextDue?.difference(now) ?? Duration.zero;
  if (remaining > Duration.zero) {
    return Duration(microseconds: remaining.inMicroseconds % Duration.microsecondsPerMinute) + margin;
  }
  final intoMinute = now.microsecondsSinceEpoch % Duration.microsecondsPerMinute;
  return Duration(microseconds: Duration.microsecondsPerMinute - intoMinute) + margin;
}
```

- [ ] **Step 4: Run** → PASS. **Step 5: Commit** `feat(core): countdown text with precision and exact minute ticks`

---

### Task 4: Reminder planning (daily, priority, due-now)

**Files:** Create `lib/core/reminders.dart`; Test `test/core/reminders_test.dart`.

**Interfaces — Produces:**
```dart
enum ReminderKind { daily, priority, due }
class PlannedReminder { final String id; final String deadlineId; final String title; final String body; final DateTime fireAt; final ReminderKind kind; }
List<PlannedReminder> planReminders(Iterable<Deadline> deadlines, DateTime now, {int limit = 60, DateTime? until});
int stableNotificationId(String id);   // 31-bit FNV-1a, for plugins that need int ids
```

- [ ] **Step 1: Failing test**

```dart
import 'package:deadlines/core/models.dart';
import 'package:deadlines/core/reminders.dart';
import 'package:test/test.dart';

Deadline dl(String title, DateTime due, {Priority p = Priority.normal, bool reminders = true, int h = 9, int m = 0}) =>
    Deadline(id: title, title: title, dueAt: due, priority: p, reminderEnabled: reminders, reminderHour: h, reminderMinute: m,
        createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1));

void main() {
  test('daily at reminder time through the due day, plus due notice', () {
    final now = DateTime(2026, 10, 18, 8);
    final plan = planReminders([dl('Thesis', DateTime(2026, 10, 21, 17))], now);
    expect(plan.where((r) => r.kind == ReminderKind.daily).map((r) => r.fireAt),
        [DateTime(2026, 10, 18, 9), DateTime(2026, 10, 19, 9), DateTime(2026, 10, 20, 9), DateTime(2026, 10, 21, 9)]);
    expect(plan.last.kind, ReminderKind.due);
    expect(plan.first.body, '3 days, 8 hours left');
    expect(plan.first.title, '📅 Thesis');
    expect(plan.last.title, '⏰ Thesis');
    expect(plan.map((r) => r.id).toSet().length, plan.length);
  });
  test('reminder time already passed today starts tomorrow', () {
    final plan = planReminders([dl('A', DateTime(2026, 10, 20, 12))], DateTime(2026, 10, 18, 10));
    expect(plan.first.fireAt, DateTime(2026, 10, 19, 9));
  });
  test('nothing at or after the due moment', () {
    final d = dl('B', DateTime(2026, 10, 19, 8, 30));
    final plan = planReminders([d], DateTime(2026, 10, 18, 8));
    expect(plan.map((r) => r.fireAt), [DateTime(2026, 10, 18, 9), d.dueAt]);
  });
  test('reminders off → only due notice; overdue → nothing', () {
    final now = DateTime(2026, 10, 18, 8);
    final off = planReminders([dl('C', DateTime(2026, 10, 25), reminders: false, p: Priority.urgent)], now);
    expect(off.map((r) => r.kind), [ReminderKind.due]);
    expect(planReminders([dl('D', DateTime(2026, 10, 17))], now), isEmpty);
  });
  test('DST keeps wall-clock time (America/New_York)', () {
    final plan = planReminders([dl('E', DateTime(2026, 11, 3, 12), h: 9, m: 30)], DateTime(2026, 10, 30, 8));
    final daily = plan.where((r) => r.kind == ReminderKind.daily).toList();
    expect(daily.length, 5);
    expect(daily.every((r) => r.fireAt.hour == 9 && r.fireAt.minute == 30), isTrue);
  });
  test('priority extras', () {
    final now = DateTime(2026, 10, 18, 8);
    final due = DateTime(2026, 10, 25, 17);
    List<DateTime> extras(Priority p) =>
        planReminders([dl('P', due, p: p)], now).where((r) => r.kind == ReminderKind.priority).map((r) => r.fireAt).toList();
    expect(extras(Priority.normal), isEmpty);
    expect(extras(Priority.high), [DateTime(2026, 10, 24, 17)]);
    expect(extras(Priority.urgent), [DateTime(2026, 10, 24, 17), DateTime(2026, 10, 25, 14), DateTime(2026, 10, 25, 16)]);
    // already-passed extras are skipped
    final soon = planReminders([dl('S', DateTime(2026, 10, 18, 10), p: Priority.urgent)], now)
        .where((r) => r.kind == ReminderKind.priority).map((r) => r.fireAt);
    expect(soon, [DateTime(2026, 10, 18, 9)]);
  });
  test('limit keeps the earliest across deadlines; until bounds the window', () {
    final now = DateTime(2026, 10, 18, 8);
    final far = List.generate(5, (i) => dl('Far$i', DateTime(2027, 3, 1), h: 9 + i));
    final soon = dl('Soon', DateTime(2026, 10, 18, 9, 30), reminders: false);
    final capped = planReminders([...far, soon], now, limit: 60);
    final all = planReminders([...far, soon], now, limit: 100000);
    expect(capped.length, 60);
    expect(capped.map((r) => r.fireAt), all.take(60).map((r) => r.fireAt));
    expect(capped.any((r) => r.deadlineId == 'Soon' && r.kind == ReminderKind.due), isTrue);
    final window = planReminders([...far, soon], now, limit: 100000, until: now.add(const Duration(hours: 24)));
    expect(window.every((r) => !r.fireAt.isAfter(now.add(const Duration(hours: 24)))), isTrue);
  });
  test('stable int ids', () {
    expect(stableNotificationId('abc'), stableNotificationId('abc'));
    expect(stableNotificationId('abc'), isNot(stableNotificationId('abd')));
    expect(stableNotificationId('x') >= 0 && stableNotificationId('x') < 0x80000000, isTrue);
  });
}
```

- [ ] **Step 2: Run** `TZ=America/New_York flutter test test/core/reminders_test.dart` → FAIL.

- [ ] **Step 3: Implement** `lib/core/reminders.dart`

```dart
import 'countdown.dart';
import 'models.dart';

enum ReminderKind { daily, priority, due }

class PlannedReminder {
  const PlannedReminder({required this.id, required this.deadlineId, required this.title, required this.body,
      required this.fireAt, required this.kind});
  final String id;
  final String deadlineId;
  final String title;
  final String body;
  final DateTime fireAt;
  final ReminderKind kind;
}

const _priorityOffsets = {
  Priority.high: [Duration(hours: 24)],
  Priority.urgent: [Duration(hours: 24), Duration(hours: 3), Duration(hours: 1)],
};

/// Every notification that should be pending now: daily reminders at each deadline's local reminder time
/// (strictly after [now], strictly before due), priority extras, and a "due now" notice. Earliest [limit] kept.
List<PlannedReminder> planReminders(Iterable<Deadline> deadlines, DateTime now, {int limit = 60, DateTime? until}) {
  final out = <PlannedReminder>[];
  bool inWindow(DateTime t) => t.isAfter(now) && (until == null || !t.isAfter(until));

  for (final d in deadlines) {
    if (d.deletedAt != null || d.isOverdue(now)) continue;
    final due = d.dueAt.toLocal();
    if (d.reminderEnabled) {
      var day = DateTime(now.year, now.month, now.day);
      var count = 0;
      while (count < limit && day.isBefore(due)) {
        // Wall-clock constructor: DST changes keep the same local time.
        final fire = DateTime(day.year, day.month, day.day, d.reminderHour, d.reminderMinute);
        if (fire.isAfter(now) && fire.isBefore(due) && inWindow(fire)) {
          out.add(_reminder(d, fire, ReminderKind.daily, '📅 ${d.title}', sentenceCountdown(fire, due)));
          count++;
        }
        day = DateTime(day.year, day.month, day.day + 1);
      }
      for (final offset in _priorityOffsets[d.priority] ?? const <Duration>[]) {
        final fire = due.subtract(offset);
        if (inWindow(fire)) {
          out.add(_reminder(d, fire, ReminderKind.priority, '❗ ${d.title}', sentenceCountdown(fire, due)));
        }
      }
    }
    if (inWindow(due)) {
      out.add(_reminder(d, due, ReminderKind.due, '⏰ ${d.title}', 'This deadline is due now.'));
    }
  }
  out.sort((a, b) => a.fireAt.compareTo(b.fireAt));
  return out.take(limit).toList();
}

PlannedReminder _reminder(Deadline d, DateTime fire, ReminderKind kind, String title, String body) => PlannedReminder(
    id: '${d.id}-${kind.name}-${fire.millisecondsSinceEpoch}', deadlineId: d.id, title: title, body: body,
    fireAt: fire, kind: kind);

/// 31-bit FNV-1a hash, stable across runs (Dart's String.hashCode is not).
int stableNotificationId(String id) {
  var hash = 0x811c9dc5;
  for (final unit in id.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash & 0x7FFFFFFF;
}
```

- [ ] **Step 4: Run** → PASS. **Step 5: Commit** `feat(core): reminder planner with priority extras`

---

### Task 5: Quick add — date grammar

**Files:** Create `lib/core/quick_add/date_grammar.dart`; Test `test/core/date_grammar_test.dart`.

**Interfaces — Produces:**
```dart
class DateMatch { final int start, end; final DateTime value; final bool hasTime; }
DateMatch? findDate(String text, DateTime now);   // earliest match in text; null if none
```

Supported (the spec's list): month-name dates (`Oct 24`, `24 Oct`, `October 24th`, optional year, optional weekday prefix), numeric `24/10` and `24/10/2026` (day first), ISO `2027-02-10[T06:59:59[+07:00|Z]]`, JavaScript `Wed Feb 10 2027 06:59:59 GMT+0700`, relative `today`, `tonight` (20:00), `tomorrow`, weekday names (with `this`/`next`), `in N day(s)/week(s)`, `next week`; Thai abbreviations `ม.ค.…ธ.ค.` and full Thai month names; Buddhist-era years 2400–2999 (−543). Times: `5pm`, `5:30pm`, `17:00`, `17:00:59`, `noon`, `midnight`, optional `at`, before or after the date. Time without a date → today at that time. A month/day without a year that has already passed this year → next year.

- [ ] **Step 1: Failing test** `test/core/date_grammar_test.dart`

```dart
import 'package:deadlines/core/quick_add/date_grammar.dart';
import 'package:test/test.dart';

void main() {
  final now = DateTime(2026, 10, 18, 17, 0); // Sunday

  void expectDate(String text, DateTime value, {bool? hasTime, String? matched}) {
    final m = findDate(text, now);
    expect(m, isNotNull, reason: text);
    expect(m!.value, value, reason: text);
    if (hasTime != null) expect(m.hasTime, hasTime, reason: text);
    if (matched != null) expect(text.substring(m.start, m.end), matched, reason: text);
  }

  test('month names', () {
    expectDate('Thesis Oct 24 5pm', DateTime(2026, 10, 24, 17), hasTime: true, matched: 'Oct 24 5pm');
    expectDate('Launch 24 Oct 2030', DateTime(2030, 10, 24), hasTime: false);
    expectDate('Party October 24th at 18:30', DateTime(2026, 10, 24, 18, 30));
    expectDate('Fly Wed, Feb 10 2027 7am', DateTime(2027, 2, 10, 7));
  });
  test('year rolls forward when no year and date passed', () {
    expectDate('Renew Jan 5', DateTime(2027, 1, 5), hasTime: false);
  });
  test('numeric day/month', () {
    expectDate('Exam 24/10 14:00', DateTime(2026, 10, 24, 14));
    expectDate('Exam 24/10/2026', DateTime(2026, 10, 24));
  });
  test('Buddhist-era years and Thai months', () {
    expectDate('Exam 24/10/2573 14:00', DateTime(2030, 10, 24, 14));
    expectDate('Final 25 ธ.ค.', DateTime(2026, 12, 25));
    expectDate('Final 25 ธันวาคม 2569', DateTime(2026, 12, 25));
  });
  test('ISO and JavaScript formats convert offsets to local', () {
    final js = DateTime.utc(2027, 2, 9, 23, 59, 59).toLocal(); // 06:59:59 at +07:00
    expectDate('Thesis 2027-02-10T06:59:59+07:00', js, hasTime: true);
    expectDate('Thesis Wed Feb 10 2027 06:59:59 GMT+0700 (Indochina Time)', js,
        matched: 'Wed Feb 10 2027 06:59:59 GMT+0700 (Indochina Time)');
    expectDate('Kickoff 2026-11-02', DateTime(2026, 11, 2), hasTime: false);
  });
  test('relative words', () {
    expectDate('Tax tomorrow 9am', DateTime(2026, 10, 19, 9));
    expectDate('Dentist next friday', DateTime(2026, 10, 23), hasTime: false);
    expectDate('Dentist friday', DateTime(2026, 10, 23));
    expectDate('Report in 3 days', DateTime(2026, 10, 21), hasTime: false);
    expectDate('Report in 2 weeks', DateTime(2026, 11, 1));
    expectDate('Meeting tonight', DateTime(2026, 10, 18, 20), hasTime: true);
    expectDate('Call today 6pm', DateTime(2026, 10, 18, 18));
    expectDate('Call 6pm', DateTime(2026, 10, 18, 18), hasTime: true);
  });
  test('24h clock: 7:30 without am/pm is morning', () {
    expectDate('Flight Nov 5 at 7:30', DateTime(2026, 11, 5, 7, 30));
    expectDate('Flight Nov 5 7:30pm', DateTime(2026, 11, 5, 19, 30));
    expectDate('Lunch Nov 5 noon', DateTime(2026, 11, 5, 12));
    expectDate('Launch Nov 5 12am', DateTime(2026, 11, 5, 0));
  });
  test('no date', () {
    expect(findDate('Buy groceries', now), isNull);
    expect(findDate('Room 24', now), isNull);
  });
}
```

- [ ] **Step 2: Run** `TZ=America/New_York flutter test test/core/date_grammar_test.dart` → FAIL.

- [ ] **Step 3: Implement** `lib/core/quick_add/date_grammar.dart`

```dart
class DateMatch {
  const DateMatch(this.start, this.end, this.value, {required this.hasTime});
  final int start, end;
  final DateTime value;
  final bool hasTime;
}

const _months = {
  'jan': 1, 'january': 1, 'feb': 2, 'february': 2, 'mar': 3, 'march': 3, 'apr': 4, 'april': 4, 'may': 5,
  'jun': 6, 'june': 6, 'jul': 7, 'july': 7, 'aug': 8, 'august': 8, 'sep': 9, 'sept': 9, 'september': 9,
  'oct': 10, 'october': 10, 'nov': 11, 'november': 11, 'dec': 12, 'december': 12,
  'ม.ค.': 1, 'มกราคม': 1, 'ก.พ.': 2, 'กุมภาพันธ์': 2, 'มี.ค.': 3, 'มีนาคม': 3, 'เม.ย.': 4, 'เมษายน': 4,
  'พ.ค.': 5, 'พฤษภาคม': 5, 'มิ.ย.': 6, 'มิถุนายน': 6, 'ก.ค.': 7, 'กรกฎาคม': 7, 'ส.ค.': 8, 'สิงหาคม': 8,
  'ก.ย.': 9, 'กันยายน': 9, 'ต.ค.': 10, 'ตุลาคม': 10, 'พ.ย.': 11, 'พฤศจิกายน': 11, 'ธ.ค.': 12, 'ธันวาคม': 12,
};
const _weekdays = {
  'mon': 1, 'monday': 1, 'tue': 2, 'tues': 2, 'tuesday': 2, 'wed': 3, 'wednesday': 3, 'thu': 4, 'thur': 4,
  'thurs': 4, 'thursday': 4, 'fri': 5, 'friday': 5, 'sat': 6, 'saturday': 6, 'sun': 7, 'sunday': 7,
};

String _alt(Iterable<String> words) =>
    (words.toList()..sort((a, b) => b.length.compareTo(a.length))).map(RegExp.escape).join('|');

final _monthAlt = _alt(_months.keys);
final _weekdayAlt = _alt(_weekdays.keys);
const _year = r'(\d{4})';
const _time = r'(?:at\s+)?(?:(\d{1,2}):(\d{2})(?::(\d{2}))?\s*(am|pm|a\.m\.|p\.m\.)?|(\d{1,2})\s*(am|pm|a\.m\.|p\.m\.)|(noon|midnight))';

final _js = RegExp('(?:$_weekdayAlt)\\s+($_monthAlt)\\s+(\\d{1,2})\\s+$_year\\s+(\\d{2}):(\\d{2}):(\\d{2})\\s+GMT([+-])(\\d{2})(\\d{2})(?:\\s*\\([^()]*\\))?',
    caseSensitive: false);
final _iso = RegExp(r'(\d{4})-(\d{2})-(\d{2})(?:[T ](\d{2}):(\d{2})(?::(\d{2}))?(Z|[+-]\d{2}:?\d{2})?)?');
final _monthFirst = RegExp('(?:(?:$_weekdayAlt),?\\s+)?($_monthAlt)\\.?\\s+(\\d{1,2})(?:st|nd|rd|th)?(?:,?\\s+$_year)?(?![\\d:])',
    caseSensitive: false);
final _dayFirst = RegExp('(?<![\\d/])(\\d{1,2})(?:st|nd|rd|th)?\\s+($_monthAlt)\\.?(?:\\s+$_year)?(?![\\d:])', caseSensitive: false);
final _numeric = RegExp(r'(?<![\d/])(\d{1,2})/(\d{1,2})(?:/(\d{2,4}))?(?![\d/])');
final _relative = RegExp('\\b(today|tonight|tomorrow|next week)\\b|\\b(?:(this|next)\\s+)?($_weekdayAlt)\\b|\\bin\\s+(\\d+)\\s+(days?|weeks?)\\b',
    caseSensitive: false);
final _timeRe = RegExp('(?<![\\w:/])$_time(?![\\w:])', caseSensitive: false);

int _gregorian(int year) => year >= 2400 ? year - 543 : (year < 100 ? 2000 + year : year);

/// Finds the earliest date phrase in [text]; an adjacent time (before or after, optional "at") is included.
DateMatch? findDate(String text, DateTime now) {
  final candidates = <DateMatch>[];
  final today = DateTime(now.year, now.month, now.day);

  for (final m in _js.allMatches(text)) {
    final month = _months[m[1]!.toLowerCase()]!;
    final sign = m[7] == '-' ? -1 : 1;
    final offset = Duration(hours: int.parse(m[8]!), minutes: int.parse(m[9]!)) * sign;
    final utc = DateTime.utc(_gregorian(int.parse(m[3]!)), month, int.parse(m[2]!), int.parse(m[4]!), int.parse(m[5]!),
            int.parse(m[6]!))
        .subtract(offset);
    candidates.add(DateMatch(m.start, m.end, utc.toLocal(), hasTime: true));
  }
  for (final m in _iso.allMatches(text)) {
    final y = _gregorian(int.parse(m[1]!)), mo = int.parse(m[2]!), d = int.parse(m[3]!);
    if (m[4] == null) {
      candidates.add(DateMatch(m.start, m.end, DateTime(y, mo, d), hasTime: false));
    } else {
      final h = int.parse(m[4]!), mi = int.parse(m[5]!), s = int.parse(m[6] ?? '0');
      final zone = m[7];
      DateTime value;
      if (zone == null) {
        value = DateTime(y, mo, d, h, mi, s);
      } else if (zone == 'Z') {
        value = DateTime.utc(y, mo, d, h, mi, s).toLocal();
      } else {
        final digits = zone.replaceAll(':', '');
        final offset = Duration(hours: int.parse(digits.substring(1, 3)), minutes: int.parse(digits.substring(3, 5))) *
            (digits.startsWith('-') ? -1 : 1);
        value = DateTime.utc(y, mo, d, h, mi, s).subtract(offset).toLocal();
      }
      candidates.add(DateMatch(m.start, m.end, value, hasTime: true));
    }
  }
  DateTime rollForward(int month, int day, String? year) {
    if (year != null) return DateTime(_gregorian(int.parse(year)), month, day);
    final thisYear = DateTime(now.year, month, day);
    return thisYear.isBefore(today) ? DateTime(now.year + 1, month, day) : thisYear;
  }
  for (final m in _monthFirst.allMatches(text)) {
    candidates.add(DateMatch(m.start, m.end, rollForward(_months[m[1]!.toLowerCase()]!, int.parse(m[2]!), m[3]), hasTime: false));
  }
  for (final m in _dayFirst.allMatches(text)) {
    candidates.add(DateMatch(m.start, m.end, rollForward(_months[m[2]!.toLowerCase()]!, int.parse(m[1]!), m[3]), hasTime: false));
  }
  for (final m in _numeric.allMatches(text)) {
    final day = int.parse(m[1]!), month = int.parse(m[2]!);
    if (month < 1 || month > 12 || day < 1 || day > 31) continue;
    candidates.add(DateMatch(m.start, m.end, rollForward(month, day, m[3]), hasTime: false));
  }
  for (final m in _relative.allMatches(text)) {
    final word = m[1]?.toLowerCase();
    if (word == 'today') {
      candidates.add(DateMatch(m.start, m.end, today, hasTime: false));
    } else if (word == 'tonight') {
      candidates.add(DateMatch(m.start, m.end, today.add(const Duration(hours: 20)), hasTime: true));
    } else if (word == 'tomorrow') {
      candidates.add(DateMatch(m.start, m.end, DateTime(today.year, today.month, today.day + 1), hasTime: false));
    } else if (word == 'next week') {
      candidates.add(DateMatch(m.start, m.end, DateTime(today.year, today.month, today.day + 7), hasTime: false));
    } else if (m[3] != null) {
      final target = _weekdays[m[3]!.toLowerCase()]!;
      var ahead = (target - today.weekday + 7) % 7;
      if (ahead == 0 && m[2]?.toLowerCase() == 'next') ahead = 7;
      candidates.add(DateMatch(m.start, m.end, DateTime(today.year, today.month, today.day + ahead), hasTime: false));
    } else if (m[4] != null) {
      final n = int.parse(m[4]!) * (m[5]!.toLowerCase().startsWith('week') ? 7 : 1);
      candidates.add(DateMatch(m.start, m.end, DateTime(today.year, today.month, today.day + n), hasTime: false));
    }
  }

  // Earliest start wins; at equal starts the longest wins (so "Wed Feb 10 2027 …" beats "Wed").
  candidates.sort((a, b) => a.start != b.start ? a.start.compareTo(b.start) : b.end.compareTo(a.end));
  final times = _timeRe.allMatches(text).toList();

  if (candidates.isEmpty) {
    if (times.isEmpty) return null;
    final t = times.first;
    final (h, mi, s) = _clock(t);
    return DateMatch(t.start, t.end, DateTime(now.year, now.month, now.day, h, mi, s), hasTime: true);
  }
  var best = candidates.first;
  if (best.hasTime) return best;

  // Attach a time directly after (or before) the date, separated only by spaces/commas.
  for (final t in times) {
    final gapAfter = t.start >= best.end ? text.substring(best.end, t.start) : null;
    final gapBefore = t.end <= best.start ? text.substring(t.end, best.start) : null;
    final adjacent = (gapAfter != null && RegExp(r'^[\s,]*$').hasMatch(gapAfter)) ||
        (gapBefore != null && RegExp(r'^[\s,]*(on\s+)?$').hasMatch(gapBefore));
    if (adjacent) {
      final (h, mi, s) = _clock(t);
      final v = best.value;
      return DateMatch(t.start < best.start ? t.start : best.start, t.end > best.end ? t.end : best.end,
          DateTime(v.year, v.month, v.day, h, mi, s), hasTime: true);
    }
  }
  return best;
}

(int, int, int) _clock(RegExpMatch t) {
  final word = t[7]?.toLowerCase();
  if (word == 'noon') return (12, 0, 0);
  if (word == 'midnight') return (0, 0, 0);
  var h = int.parse(t[1] ?? t[5]!);
  final mi = int.parse(t[2] ?? '0'), s = int.parse(t[3] ?? '0');
  final ampm = (t[4] ?? t[6])?.toLowerCase().replaceAll('.', '');
  if (ampm == 'pm' && h < 12) h += 12;
  if (ampm == 'am' && h == 12) h = 0;
  return (h, mi, s);
}
```

- [ ] **Step 4: Run** → PASS. Fix any regex the tests expose (they are the spec); don't loosen tests.
- [ ] **Step 5: Commit** `feat(core): quick-add date grammar (English, Thai, ISO, JS, BE years)`

---

### Task 6: Quick add — parser

**Files:** Create `lib/core/quick_add/quick_add_parser.dart`; Test `test/core/quick_add_parser_test.dart`.

**Interfaces — Consumes:** `findDate`. **Produces:**
```dart
enum QuickAddError { empty, noDate, noTitle, inPast, unknownGroup }
class QuickAddResult { final String title; final DateTime dueAt; final bool hasExplicitTime; final Priority? priority; final String? groupName; }
sealed class QuickAddOutcome; class QuickAddOk extends QuickAddOutcome { final QuickAddResult result; }
class QuickAddFailed extends QuickAddOutcome { final QuickAddError error; final String? detail; }
QuickAddOutcome parseQuickAdd(String text, DateTime now, {Set<String> groupNames = const {}});
```

- [ ] **Step 1: Failing test**

```dart
import 'package:deadlines/core/models.dart';
import 'package:deadlines/core/quick_add/quick_add_parser.dart';
import 'package:test/test.dart';

void main() {
  final now = DateTime(2026, 10, 18, 17);
  QuickAddResult ok(String text, {Set<String> groups = const {}}) {
    final r = parseQuickAdd(text, now, groupNames: groups);
    if (r is! QuickAddOk) fail('$text → $r');
    return r.result;
  }
  QuickAddError err(String text, {Set<String> groups = const {}}) => (parseQuickAdd(text, now, groupNames: groups) as QuickAddFailed).error;

  test('title and date', () {
    final r = ok('Thesis submission Oct 24 2030 5pm');
    expect(r.title, 'Thesis submission');
    expect(r.dueAt, DateTime(2030, 10, 24, 17));
    expect(r.hasExplicitTime, isTrue);
  });
  test('no time → 23:59', () {
    final r = ok('Launch 24 Oct 2030');
    expect(r.dueAt, DateTime(2030, 10, 24, 23, 59));
    expect(r.hasExplicitTime, isFalse);
  });
  test('connector words and punctuation', () {
    expect(ok('Thesis on 24 Oct 2030 at 18:30').title, 'Thesis');
    expect(ok('Report due by 30 Oct 2030').title, 'Report');
    expect(ok('Pay before Dec 1 2030 10am').title, 'Pay');
    expect(ok('Essay by Oct 25 2030 5pm').title, 'Essay');
    expect(ok('Submit Oct 24 2030 thesis').title, 'Submit thesis');
    expect(ok('Oct 24 2030 9am: call mom').title, 'call mom');
    expect(ok('Dr. Smith, follow-up - Oct 24 2030 5pm').title, 'Dr. Smith, follow-up');
    expect(ok('Thesis (draft 2) Oct 24 2030 5pm').title, 'Thesis (draft 2)');
  });
  test('JavaScript format with zone name', () {
    final r = ok('Thesis Sun Feb 10 2030 06:59:59 GMT+0700 (Indochina Time)');
    expect(r.title, 'Thesis');
    expect(r.dueAt, DateTime.utc(2030, 2, 9, 23, 59, 59).toLocal());
    expect(ok('Sun Feb 10 2030 06:59:59 GMT+0700 (Indochina Time) Thesis').title, 'Thesis');
  });
  test('priority markers and #group', () {
    final r = ok('Lab report Oct 24 2030 5pm !! #physics', groups: {'Physics', 'Work'});
    expect(r.title, 'Lab report');
    expect(r.priority, Priority.urgent);
    expect(r.groupName, 'Physics');
    expect(ok('Essay ! Oct 24 2030').priority, Priority.high);
    expect(ok('Essay Oct 24 2030').priority, isNull);
    expect(err('Essay Oct 24 2030 #chem', groups: {'Physics'}), QuickAddError.unknownGroup);
  });
  test('errors', () {
    expect(err('   '), QuickAddError.empty);
    expect(err('Buy groceries'), QuickAddError.noDate);
    expect(err('Oct 24 2030 5pm'), QuickAddError.noTitle);
    expect(err('Sun Feb 10 2030 06:59:59 GMT+0700 (Indochina Time)'), QuickAddError.noTitle);
    expect(err('Old thing Jan 5 2020'), QuickAddError.inPast);
    expect(err('Call 3pm'), QuickAddError.inPast); // today 15:00 already passed at 17:00
  });
}
```

- [ ] **Step 2: Run** → FAIL.

- [ ] **Step 3: Implement**

```dart
import '../models.dart';
import 'date_grammar.dart';

enum QuickAddError { empty, noDate, noTitle, inPast, unknownGroup }

class QuickAddResult {
  const QuickAddResult({required this.title, required this.dueAt, required this.hasExplicitTime, this.priority, this.groupName});
  final String title;
  final DateTime dueAt;
  final bool hasExplicitTime;
  final Priority? priority;
  final String? groupName;
}

sealed class QuickAddOutcome { const QuickAddOutcome(); }
class QuickAddOk extends QuickAddOutcome { const QuickAddOk(this.result); final QuickAddResult result; }
class QuickAddFailed extends QuickAddOutcome {
  const QuickAddFailed(this.error, [this.detail]);
  final QuickAddError error;
  final String? detail;
  @override
  String toString() => 'QuickAddFailed($error, $detail)';
}

const _connectors = {'on', 'by', 'at', 'due', 'before', 'until', 'till', 'for', 'in'};
final _separators = RegExp(r'^[-–—:;,.]+|[-–—:;,.]+$');
final _priorityToken = RegExp(r'(?<!\S)(!{1,2})(?!\S)');
final _groupToken = RegExp(r'(?<!\S)#(\S+)');

QuickAddOutcome parseQuickAdd(String text, DateTime now, {Set<String> groupNames = const {}}) {
  var input = text.trim();
  if (input.isEmpty) return const QuickAddFailed(QuickAddError.empty);

  Priority? priority;
  final p = _priorityToken.firstMatch(input);
  if (p != null) {
    priority = p[1]!.length == 2 ? Priority.urgent : Priority.high;
    input = input.replaceRange(p.start, p.end, ' ');
  }
  String? groupName;
  final g = _groupToken.firstMatch(input);
  if (g != null) {
    final wanted = g[1]!.toLowerCase();
    groupName = groupNames.where((n) => n.toLowerCase() == wanted).firstOrNull;
    if (groupName == null) return QuickAddFailed(QuickAddError.unknownGroup, g[1]);
    input = input.replaceRange(g.start, g.end, ' ');
  }

  final match = findDate(input, now);
  if (match == null) return const QuickAddFailed(QuickAddError.noDate);
  final due = match.hasTime
      ? match.value
      : DateTime(match.value.year, match.value.month, match.value.day, 23, 59);

  final title = _cleanTitle(input.replaceRange(match.start, match.end, ' '));
  if (title.isEmpty) return const QuickAddFailed(QuickAddError.noTitle);
  if (!due.isAfter(now)) return const QuickAddFailed(QuickAddError.inPast);
  return QuickAddOk(QuickAddResult(title: title, dueAt: due, hasExplicitTime: match.hasTime, priority: priority, groupName: groupName));
}

/// Drops standalone separators and connector words at the ends; inner punctuation stays ("Dr. Smith, follow-up").
String _cleanTitle(String raw) {
  final words = raw.split(RegExp(r'\s+')).where((w) => w.replaceAll(_separators, '').isNotEmpty).toList();
  bool isConnector(String w) => _connectors.contains(w.toLowerCase().replaceAll(_separators, ''));
  while (words.isNotEmpty && isConnector(words.last)) {
    words.removeLast();
  }
  while (words.isNotEmpty && isConnector(words.first)) {
    words.removeAt(0);
  }
  return words.join(' ').replaceAll(_separators, '').trim();
}
```

- [ ] **Step 4: Run** → PASS. **Step 5: Commit** `feat(core): quick-add parser with priority and group markers`

---

### Task 7: Mac app import + year labels

**Files:** Create `lib/core/mac_import.dart`, `lib/core/year_format.dart`; Tests `test/core/mac_import_test.dart`, `test/core/year_format_test.dart`.

**Interfaces — Produces:**
```dart
List<Deadline> parseMacDeadlines(String json, DateTime importedAt);   // throws FormatException on bad JSON
String yearLabel(int gregorianYear, {required bool buddhist});        // "2026" | "2569 BE"
bool localeUsesBuddhistCalendar(String localeName);                   // "en_TH@calendar=buddhist" → true
```

- [ ] **Step 1: Failing tests**

```dart
// test/core/mac_import_test.dart
import 'package:deadlines/core/mac_import.dart';
import 'package:test/test.dart';

const sample = '''[{"color":"purple","createdAt":813110400.5,"dueDate":815234400,"id":"79E58A31-1B32-4203-A3FC-55F05D35421C",
"notes":"chapter 3","reminderEnabled":true,"reminderHour":8,"reminderMinute":30,"title":"Final report"}]''';

void main() {
  test('reads the SwiftUI app format (seconds since 2001)', () {
    final list = parseMacDeadlines(sample, DateTime.utc(2026, 10, 18));
    expect(list, hasLength(1));
    final d = list.single;
    expect(d.id, '79E58A31-1B32-4203-A3FC-55F05D35421C');
    expect(d.title, 'Final report');
    expect(d.dueAt, DateTime.utc(2001).add(const Duration(seconds: 815234400)));
    expect(d.createdAt, DateTime.utc(2001).add(const Duration(microseconds: 813110400500000)));
    expect((d.reminderHour, d.reminderMinute, d.reminderEnabled, d.notes), (8, 30, true, 'chapter 3'));
    expect(d.groupId, isNull);
    expect(d.updatedAt, DateTime.utc(2026, 10, 18));
  });
  test('bad JSON throws FormatException', () {
    expect(() => parseMacDeadlines('not json', DateTime.utc(2026)), throwsFormatException);
    expect(() => parseMacDeadlines('[{"title": 3}]', DateTime.utc(2026)), throwsFormatException);
  });
}
```

```dart
// test/core/year_format_test.dart
import 'package:deadlines/core/year_format.dart';
import 'package:test/test.dart';

void main() {
  test('labels', () {
    expect(yearLabel(2026, buddhist: false), '2026');
    expect(yearLabel(2026, buddhist: true), '2569 BE');
  });
  test('locale detection', () {
    expect(localeUsesBuddhistCalendar('en_TH@calendar=buddhist'), isTrue);
    expect(localeUsesBuddhistCalendar('th_TH'), isFalse);
    expect(localeUsesBuddhistCalendar('en_US'), isFalse);
  });
}
```

- [ ] **Step 2: Run** → FAIL.
- [ ] **Step 3: Implement**

```dart
// lib/core/mac_import.dart
import 'dart:convert';
import 'models.dart';

final _reference = DateTime.utc(2001);

DateTime _appleDate(Object? v) {
  if (v is! num) throw const FormatException('date is not a number');
  return _reference.add(Duration(microseconds: (v * 1e6).round()));
}

/// The SwiftUI app's deadlines.json (Codable, default date strategy). Colors are dropped: groups own colors now.
List<Deadline> parseMacDeadlines(String json, DateTime importedAt) {
  final Object? decoded;
  try {
    decoded = jsonDecode(json);
  } on FormatException {
    rethrow;
  }
  if (decoded is! List) throw const FormatException('expected a list');
  return decoded.map((raw) {
    if (raw is! Map || raw['id'] is! String || raw['title'] is! String) throw const FormatException('bad deadline');
    return Deadline(
      id: raw['id'] as String, title: raw['title'] as String, dueAt: _appleDate(raw['dueDate']),
      notes: raw['notes'] as String? ?? '', reminderEnabled: raw['reminderEnabled'] as bool? ?? true,
      reminderHour: raw['reminderHour'] as int? ?? 9, reminderMinute: raw['reminderMinute'] as int? ?? 0,
      createdAt: _appleDate(raw['createdAt']), updatedAt: importedAt);
  }).toList();
}
```

```dart
// lib/core/year_format.dart
String yearLabel(int gregorianYear, {required bool buddhist}) => buddhist ? '${gregorianYear + 543} BE' : '$gregorianYear';

bool localeUsesBuddhistCalendar(String localeName) => localeName.toLowerCase().contains('calendar=buddhist');
```

- [ ] **Step 4: Run** → PASS. **Step 5: Commit** `feat(core): Mac app import and Buddhist-era year labels`

---

### Task 8: GitHub Actions CI (tests on every push)

**Files:** Create `.github/workflows/ci.yml`.

- [ ] **Step 1: Write workflow**

```yaml
name: ci
on: [push, pull_request]
env:
  TZ: America/New_York
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with: { channel: stable, cache: true }
      - run: flutter pub get
      - run: dart run build_runner build --delete-conflicting-outputs
      - run: flutter analyze
      - run: flutter test
  build:
    needs: test
    strategy:
      matrix:
        include:
          - { os: ubuntu-latest, target: linux, artifact: build/linux/x64/release/bundle }
          - { os: windows-latest, target: windows, artifact: build/windows/x64/runner/Release }
          - { os: macos-latest, target: macos, artifact: build/macos/Build/Products/Release }
          - { os: ubuntu-latest, target: apk, artifact: build/app/outputs/flutter-apk/app-release.apk }
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with: { channel: stable, cache: true }
      - if: matrix.target == 'linux'
        run: sudo apt-get update && sudo apt-get install -y ninja-build libgtk-3-dev libayatana-appindicator3-dev libkeybinder-3.0-dev
      - if: matrix.target == 'apk'
        uses: actions/setup-java@v4
        with: { distribution: temurin, java-version: '17' }
      - run: flutter pub get
      - run: dart run build_runner build --delete-conflicting-outputs
      - run: flutter build ${{ matrix.target }} --release
      - uses: actions/upload-artifact@v4
        with: { name: deadlines-${{ matrix.target }}, path: ${{ matrix.artifact }} }
```

- [ ] **Step 2: Repo** (needs the user): `gh auth login`, then `gh repo create deadline-countdown-app --private --source . --push`.
- [ ] **Step 3: Verify**: `gh run watch` → test job green. (Build jobs go green after Tasks 9–14.)
- [ ] **Step 4: Commit** `ci: tests and per-platform builds`

---

### Task 9: Database and repository

**Files:** Create `lib/data/database.dart`, `lib/data/repository.dart`; Test `test/data/repository_test.dart`.

**Interfaces — Produces:**
```dart
class AppDatabase extends _$AppDatabase { AppDatabase(QueryExecutor e); static Future<OpenResult> openDefault(); }
class OpenResult { final AppDatabase db; final String? recoveredFrom; }   // recoveredFrom = moved-aside path
class DeadlineRepository {
  DeadlineRepository(AppDatabase db, {DateTime Function()? clock});
  Stream<List<Deadline>> watchDeadlines(); Stream<List<Group>> watchGroups();
  Future<void> saveDeadline(Deadline d); Future<void> deleteDeadline(String id);
  Future<Group> createGroup(String name, DeadlineColor color); Future<void> saveGroup(Group g);
  Future<int> deleteGroup(String id);                 // returns how many deadlines moved to No group
  Future<int> importDeadlines(List<Deadline> list);   // skips ids that already exist
}
```

- [ ] **Step 1: Failing test** (in-memory DB: `NativeDatabase.memory()`)

```dart
import 'dart:io';
import 'package:deadlines/core/models.dart';
import 'package:deadlines/data/database.dart';
import 'package:deadlines/data/repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late DeadlineRepository repo;
  var t = DateTime.utc(2026, 10, 18, 12);
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = DeadlineRepository(db, clock: () => t);
  });
  tearDown(() => db.close());

  Deadline dl(String id, {String? group}) => Deadline(id: id, title: id, dueAt: DateTime.utc(2026, 12, 1), groupId: group,
      createdAt: DateTime.utc(2026, 10, 1), updatedAt: DateTime.utc(2026, 10, 1));

  test('save, update stamps updatedAt, soft delete hides', () async {
    await repo.saveDeadline(dl('a'));
    t = t.add(const Duration(minutes: 5));
    await repo.saveDeadline(dl('a').copyWith(title: 'A2'));
    var list = await repo.watchDeadlines().first;
    expect(list.single.title, 'A2');
    expect(list.single.updatedAt, t);
    await repo.deleteDeadline('a');
    list = await repo.watchDeadlines().first;
    expect(list, isEmpty);
    final raw = await db.select(db.deadlines).get();
    expect(raw.single.deletedAt, isNotNull); // kept for sync
  });

  test('deleting a group keeps its deadlines', () async {
    final g = await repo.createGroup('Physics', DeadlineColor.teal);
    await repo.saveDeadline(dl('x', group: g.id));
    await repo.saveDeadline(dl('y', group: g.id));
    expect(await repo.deleteGroup(g.id), 2);
    final list = await repo.watchDeadlines().first;
    expect(list.map((d) => d.groupId), [null, null]);
    expect(await repo.watchGroups().first, isEmpty);
  });

  test('import skips existing ids', () async {
    await repo.saveDeadline(dl('a'));
    expect(await repo.importDeadlines([dl('a'), dl('b')]), 1);
  });

  test('corrupt file is moved aside', () async {
    final dir = await Directory.systemTemp.createTemp('dl');
    final file = File('${dir.path}/deadlines.db')..writeAsStringSync('not a database');
    final result = await AppDatabase.openAt(file);
    expect(result.recoveredFrom, isNotNull);
    expect(File(result.recoveredFrom!).existsSync(), isTrue);
    expect(await DeadlineRepository(result.db).watchDeadlines().first, isEmpty);
    await result.db.close();
  });
}
```

- [ ] **Step 2: Run** `flutter test test/data/repository_test.dart` → FAIL.

- [ ] **Step 3: Implement** `lib/data/database.dart`

```dart
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'database.g.dart';

class Groups extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 40)();
  TextColumn get color => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  @override
  Set<Column> get primaryKey => {id};
}

class Deadlines extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  DateTimeColumn get dueAt => dateTime()();
  TextColumn get groupId => text().nullable()();
  TextColumn get priority => text().withDefault(const Constant('normal'))();
  TextColumn get notes => text().withDefault(const Constant(''))();
  BoolColumn get reminderEnabled => boolean().withDefault(const Constant(true))();
  IntColumn get reminderHour => integer().withDefault(const Constant(9))();
  IntColumn get reminderMinute => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  @override
  Set<Column> get primaryKey => {id};
}

class OpenResult {
  OpenResult(this.db, this.recoveredFrom);
  final AppDatabase db;
  final String? recoveredFrom;
}

@DriftDatabase(tables: [Groups, Deadlines])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;

  @override
  DriftDatabaseOptions get options => const DriftDatabaseOptions(storeDateTimeValuesAsText: true);

  static Future<OpenResult> openDefault() async {
    final dir = await getApplicationSupportDirectory();
    return openAt(File(p.join(dir.path, 'deadlines.db')));
  }

  /// Opens [file]; if it isn't a usable database, moves it aside and starts empty.
  static Future<OpenResult> openAt(File file) async {
    await file.parent.create(recursive: true);
    final db = AppDatabase(NativeDatabase(file));
    try {
      await db.customSelect('SELECT count(*) FROM deadlines').get();
      return OpenResult(db, null);
    } catch (_) {
      await db.close();
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final aside = p.join(file.parent.path, 'deadlines.corrupt-$stamp.db');
      await file.rename(aside);
      return OpenResult(AppDatabase(NativeDatabase(file)), aside);
    }
  }
}
```

Generate: `dart run build_runner build --delete-conflicting-outputs`.

`lib/data/repository.dart`

```dart
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../core/models.dart';
import 'database.dart' as db;

class DeadlineRepository {
  DeadlineRepository(this._db, {DateTime Function()? clock}) : _clock = clock ?? (() => DateTime.now().toUtc());
  final db.AppDatabase _db;
  final DateTime Function() _clock;

  Stream<List<Deadline>> watchDeadlines() => (_db.select(_db.deadlines)..where((t) => t.deletedAt.isNull()))
      .watch()
      .map((rows) => rows.map(_toDeadline).toList());

  Stream<List<Group>> watchGroups() => (_db.select(_db.groups)
        ..where((t) => t.deletedAt.isNull())
        ..orderBy([(t) => OrderingTerm.asc(t.sortOrder), (t) => OrderingTerm.asc(t.name)]))
      .watch()
      .map((rows) => rows.map(_toGroup).toList());

  Future<void> saveDeadline(Deadline d) => _db.into(_db.deadlines).insertOnConflictUpdate(db.DeadlinesCompanion.insert(
      id: d.id, title: d.title, dueAt: d.dueAt.toUtc(), groupId: Value(d.groupId), priority: Value(d.priority.name),
      notes: Value(d.notes), reminderEnabled: Value(d.reminderEnabled), reminderHour: Value(d.reminderHour),
      reminderMinute: Value(d.reminderMinute), createdAt: d.createdAt.toUtc(), updatedAt: _clock(),
      deletedAt: Value(d.deletedAt)));

  Future<void> deleteDeadline(String id) => (_db.update(_db.deadlines)..where((t) => t.id.equals(id)))
      .write(db.DeadlinesCompanion(deletedAt: Value(_clock()), updatedAt: Value(_clock())));

  Future<Group> createGroup(String name, DeadlineColor color) async {
    final now = _clock();
    final g = Group(id: const Uuid().v4(), name: name.trim(), color: color, createdAt: now, updatedAt: now);
    await saveGroup(g);
    return g;
  }

  Future<void> saveGroup(Group g) => _db.into(_db.groups).insertOnConflictUpdate(db.GroupsCompanion.insert(
      id: g.id, name: g.name, color: g.color.name, sortOrder: Value(g.sortOrder), createdAt: g.createdAt,
      updatedAt: _clock(), deletedAt: Value(g.deletedAt)));

  /// Soft-deletes the group; its deadlines move to "No group". Returns how many moved.
  Future<int> deleteGroup(String id) => _db.transaction(() async {
        final moved = await (_db.update(_db.deadlines)..where((t) => t.groupId.equals(id)))
            .write(db.DeadlinesCompanion(groupId: const Value(null), updatedAt: Value(_clock())));
        await (_db.update(_db.groups)..where((t) => t.id.equals(id)))
            .write(db.GroupsCompanion(deletedAt: Value(_clock()), updatedAt: Value(_clock())));
        return moved;
      });

  Future<int> importDeadlines(List<Deadline> list) => _db.transaction(() async {
        var added = 0;
        for (final d in list) {
          final exists = await (_db.select(_db.deadlines)..where((t) => t.id.equals(d.id))).getSingleOrNull();
          if (exists == null) {
            await saveDeadline(d);
            added++;
          }
        }
        return added;
      });

  Deadline _toDeadline(db.Deadline r) => Deadline(
      id: r.id, title: r.title, dueAt: r.dueAt.toLocal(), groupId: r.groupId,
      priority: Priority.values.byName(r.priority), notes: r.notes, reminderEnabled: r.reminderEnabled,
      reminderHour: r.reminderHour, reminderMinute: r.reminderMinute, createdAt: r.createdAt, updatedAt: r.updatedAt,
      deletedAt: r.deletedAt);

  Group _toGroup(db.Group r) => Group(id: r.id, name: r.name, color: DeadlineColor.values.byName(r.color),
      sortOrder: r.sortOrder, createdAt: r.createdAt, updatedAt: r.updatedAt, deletedAt: r.deletedAt);
}
```

- [ ] **Step 4: Run** → PASS. **Step 5: Commit** `feat(data): Drift database, soft delete, group delete, corruption recovery`

---

### Task 10: State — settings, clock, providers

**Files:** Create `lib/state/settings.dart`, `lib/state/clock.dart`, `lib/state/providers.dart`; Test `test/state/clock_test.dart`.

**Interfaces — Produces:**
```dart
class AppSettings { CountdownPrecision precision; bool showTrayCountdown; bool buddhistYears; bool launchAtLogin; String? groupFilter; bool macImportDone; }
final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(...);   // SharedPreferences-backed
final repositoryProvider = Provider<DeadlineRepository>(...);                     // overridden in main()
final deadlinesProvider = StreamProvider<List<Deadline>>(...);
final groupsProvider = StreamProvider<List<Group>>(...);
final nowProvider = NotifierProvider<ClockNotifier, DateTime>(...);               // minute-exact ticks
final nearestProvider = Provider<Deadline?>(...);
```

- [ ] **Step 1: Failing test** — clock re-arms using `untilNextChange` (fake timer factory):

```dart
import 'package:deadlines/state/clock.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('schedules next tick for the nearest deadline boundary', () {
    final delays = <Duration>[];
    var now = DateTime(2026, 10, 18, 16, 37, 10);
    final ticker = MinuteTicker(now: () => now, schedule: (d, cb) => delays.add(d), nextDue: () => DateTime(2026, 10, 18, 17, 59, 59));
    ticker.start((_) {});
    expect(delays.single.inMilliseconds, closeTo(49010, 20));
  });
}
```

- [ ] **Step 2: Run** → FAIL. **Step 3: Implement** `lib/state/clock.dart`

```dart
import 'dart:async';
import '../core/countdown.dart';

typedef Scheduler = void Function(Duration delay, void Function() callback);

/// Calls back exactly when the nearest countdown's minute changes, re-arming after every tick.
class MinuteTicker {
  MinuteTicker({DateTime Function()? now, Scheduler? schedule, required this.nextDue})
      : _now = now ?? DateTime.now, _schedule = schedule ?? _timer;
  final DateTime Function() _now;
  final Scheduler _schedule;
  final DateTime? Function() nextDue;
  Timer? _active;
  void Function(DateTime)? _onTick;

  static Timer? _lastTimer;
  static void _timer(Duration d, void Function() cb) => _lastTimer = Timer(d, cb);

  void start(void Function(DateTime now) onTick) {
    _onTick = onTick;
    _arm();
  }

  /// Re-plan now (after edits or waking from sleep).
  void poke() {
    _active?.cancel();
    _onTick?.call(_now());
    _arm();
  }

  void _arm() {
    final now = _now();
    _schedule(untilNextChange(now, nextDue()), () {
      _onTick?.call(_now());
      _arm();
    });
    _active = _lastTimer;
  }

  void stop() => _active?.cancel();
}
```

`lib/state/providers.dart` wires: `repositoryProvider` (throws unless overridden), `deadlinesProvider = StreamProvider((ref) => ref.watch(repositoryProvider).watchDeadlines())`, groups likewise; `ClockNotifier` builds a `MinuteTicker` whose `nextDue` reads `nearest(ref.read(deadlinesProvider).valueOrNull ?? [], DateTime.now())?.dueAt`, and calls `poke()` when `deadlinesProvider` changes. `settings.dart` persists each field under keys `precision`, `showTrayCountdown`, `buddhistYears`, `launchAtLogin`, `groupFilter`, `macImportDone`; `buddhistYears` default = `localeUsesBuddhistCalendar(Platform.localeName)`; `launchAtLogin` default = `Platform.isWindows || Platform.isLinux`.

- [ ] **Step 4: Run** → PASS. **Step 5: Commit** `feat(state): settings, minute-exact clock, providers`

---

### Task 11: Notifications adapter

**Files:** Create `lib/platform/notifications.dart`, `lib/platform/in_app_reminders.dart`; Test `test/platform/notifications_test.dart`.

**Interfaces — Produces:**
```dart
enum NotificationPermission { granted, denied, unknown }
abstract class NotificationPort {
  Future<NotificationPermission> requestPermission();
  Future<NotificationPermission> status();
  Future<void> cancelAll();
  Future<void> schedule(PlannedReminder r);     // OS-scheduled (macOS, Android)
  Future<void> show(String title, String body);  // immediate (test + in-app delivery)
  Future<void> openSystemSettings();
}
class ReminderService { ReminderService(NotificationPort port, {required bool osScheduling, required int cap}); Future<int> replan(List<Deadline> all, DateTime now); }
```

- [ ] **Step 1: Failing test** — `ReminderService.replan` cancels first, respects the cap, and in in-app mode schedules nothing with the OS:

```dart
import 'package:deadlines/core/models.dart';
import 'package:deadlines/core/reminders.dart';
import 'package:deadlines/platform/notifications.dart';
import 'package:flutter_test/flutter_test.dart';

class FakePort implements NotificationPort {
  final log = <String>[];
  @override Future<void> cancelAll() async => log.add('cancelAll');
  @override Future<void> schedule(PlannedReminder r) async => log.add('schedule ${r.id}');
  @override Future<void> show(String t, String b) async => log.add('show $t');
  @override Future<NotificationPermission> requestPermission() async => NotificationPermission.granted;
  @override Future<NotificationPermission> status() async => NotificationPermission.granted;
  @override Future<void> openSystemSettings() async {}
}

void main() {
  final now = DateTime(2026, 10, 18, 8);
  final d = Deadline(id: 'a', title: 'A', dueAt: DateTime(2027, 3, 1), createdAt: now, updatedAt: now);

  test('reschedule cancels first and respects the cap', () async {
    final port = FakePort();
    final n = await ReminderService(port, osScheduling: true, cap: 60).replan([d], now);
    expect(port.log.first, 'cancelAll');
    expect(n, 60);
    expect(port.log.where((l) => l.startsWith('schedule')).length, 60);
  });
  test('in-app mode plans a 24h window and schedules nothing with the OS', () async {
    final port = FakePort();
    final service = ReminderService(port, osScheduling: false, cap: 1000);
    final n = await service.replan([d], now);
    expect(n, 1); // only today's 09:00
    expect(port.log.where((l) => l.startsWith('schedule')), isEmpty);
    service.dispose();
  });
}
```

- [ ] **Step 2: Run** → FAIL. **Step 3: Implement**
  - `ReminderService.replan`: `await port.cancelAll()`; plan = `planReminders(all, now, limit: cap, until: osScheduling ? null : now.add(24h))`; OS mode → `schedule` each; in-app mode → keep a `Timer` per reminder that calls `port.show(r.title, r.body)` (cancel old timers first); return plan length.
  - `FlutterNotificationPort` implements the interface with `FlutterLocalNotificationsPlugin`:
    - init with `DarwinInitializationSettings`, `AndroidInitializationSettings('@mipmap/ic_launcher')`, `LinuxInitializationSettings(defaultActionName: 'Open')`, `WindowsInitializationSettings(appName: 'Deadline Countdown', appUserModelId: 'com.wayupuk.deadlines', guid: <fixed uuid>)`.
    - `schedule`: `zonedSchedule(stableNotificationId(r.id), r.title, r.body, tz.TZDateTime.from(r.fireAt, tz.local), details, androidScheduleMode: exactAllowed ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle, payload: r.deadlineId)`.
    - timezone: `tz.initializeTimeZones(); tz.setLocalLocation(tz.getLocation(await FlutterTimezone.getLocalTimezone()))` in `main()`.
    - Android manifest: `POST_NOTIFICATIONS`, `SCHEDULE_EXACT_ALARM`, `RECEIVE_BOOT_COMPLETED` + the plugin's receivers (per the plugin README for the resolved version).
    - Adapt exact signatures to the resolved plugin version; `flutter analyze` must be clean.
- [ ] **Step 4: Run** → PASS. **Step 5: Commit** `feat(platform): notification adapter, OS and in-app reminder delivery`

---

### Task 12: Shared widgets — quick add, card, editor, group manager, banners

**Files:** Create `lib/ui/widgets/*.dart`; Tests `test/ui/quick_add_field_test.dart`, `test/ui/deadline_editor_test.dart`.

**Interfaces — Consumes:** `parseQuickAdd`, `shortCountdown`, `clockCountdown`, providers. **Produces:** `QuickAddField({bool autofocus})`, `CountdownCard(Deadline, {VoidCallback? onTap})`, `showDeadlineEditor(BuildContext, {Deadline? existing, String? title, DateTime? due})`, `GroupManager()`, `NotificationsOffBanner()`.

Behavior (from spec): quick add preview line `Title · Sat, 24 Oct at 17:00 (end of day) · in 5d 23h` with priority badge and group chip when present; error messages: empty → none, noDate → `Add a date, e.g. "tomorrow 5pm" or "Oct 24"`, noTitle → `Add a name before or after the date`, inPast → `That time has already passed`, unknownGroup → `No group named "#x"`; Enter saves (new id `Uuid().v4()`, `createdAt = updatedAt = now`), Esc clears, "Details…" opens the editor prefilled. Card: group color stripe, title, due, priority badge (High/Urgent only), live `shortCountdown` (per settings precision) + `clockCountdown` ticking each second, progress bar. Editor: title (required), calendar date picker + time field, group dropdown (incl. "No group" and "New group…"), priority segmented control, daily reminder toggle + time (default 09:00), notes; new deadlines must be in the future; due time saved with seconds = 0. **No `IntrinsicHeight`/unbounded text measuring in banners** (the Mac app's overflow bug): banner text uses `maxLines: 1, overflow: TextOverflow.ellipsis`.

- [ ] **Step 1: Failing widget tests**

```dart
// test/ui/quick_add_field_test.dart
// Pump QuickAddField inside ProviderScope with a fake repository (in-memory AppDatabase).
// 1) enterText('Thesis Oct 24 2030 5pm !!') → finds text 'Thesis', 'Urgent', and 'in ' preview.
// 2) enterText('Buy groceries') → finds 'Add a date, e.g. "tomorrow 5pm" or "Oct 24"'.
// 3) enter 'Thesis Oct 24 2030 5pm' + testTextInput.receiveAction(TextInputAction.done) → repository has 1 deadline titled 'Thesis', field is empty.
// test/ui/deadline_editor_test.dart
// 4) Save disabled with empty title; enabled after typing; a past date shows 'Pick a time in the future.'
```
(Write these as real `testWidgets` cases following the comments; each `expect` uses `find.text` / `find.textContaining`.)

- [ ] **Step 2: Run** `flutter test test/ui` → FAIL. **Step 3: Implement** the widgets. **Step 4: Run** → PASS.
- [ ] **Step 5: Commit** `feat(ui): quick add, countdown card, editor, groups, banners`

---

### Task 13: Desktop UI — main window, month grid, detail, tray popup, shell

**Files:** Create `lib/ui/desktop/*.dart`, `lib/platform/desktop_shell.dart`; Modify `lib/app.dart`, `lib/main.dart`, `macos/Runner/*.entitlements` (no sandbox changes needed for local files), `macos/Runner/Info.plist` (`LSUIElement` stays false).

Behavior:
- Main window (min 860×560): sidebar (Upcoming / Past, group filter list with colors and counts, "Manage groups…"), month grid (6×7, today red circle, chips with group color + time when wide enough, ‹ Today ›, BE year label per setting), detail pane (big ring with days left + `HH:MM:SS`, priority, group, reminder, notes, Edit / Delete with confirmation). Quick add field above the grid.
- Tray (`tray_manager`): icon `assets/tray/hourglass` (template PNG on macOS, ICO on Windows, PNG on Linux); macOS title = nearest `shortCountdown` (setting toggle); Windows/Linux tooltip = same text. Left click → toggle popup window (`window_manager`, 360×560, frameless, positioned under the tray icon via `trayManager.getBounds()`, hides on blur). Popup = header, quick add (autofocus), group chips, `CountdownCard` list sorted by `upcoming()`, footer: Open Calendar / Settings / Quit.
- Single-window approach: the app has one Flutter window; "popup mode" and "calendar mode" switch size/position/frame of that window (multi-window plugins are not used).
- Hotkey ⌃⌥D via `hotkey_manager` (`HotKeyScope.system`) toggles popup mode; failure → setting shows "used by another app".
- Launch at login via `launch_at_startup` (desktop only).
- Closing the calendar window hides it (app keeps running in the tray); Quit exits.
- Tray unavailable (e.g. GNOME without AppIndicator → `trayManager.setIcon` throws): run as a normal window, never hide on close, and Settings shows "Tray icon unavailable — install the AppIndicator extension".

- [ ] **Step 1: Widget test** `test/ui/month_grid_test.dart`: grid for October 2026 shows 42 cells starting Sun Sep 27, a deadline on Oct 24 renders its chip, `buddhistYears: true` shows `2569 BE`.
- [ ] **Step 2: Run** → FAIL. **Step 3: Implement.** **Step 4: Run** → PASS; `flutter run -d macos` (needs Xcode) and check: tray text, popup opens under icon, ⌃⌥D, quick add, calendar, edit/delete, settings.
- [ ] **Step 5: Commit** `feat(desktop): calendar window, tray popup, hotkey, launch at login`

---

### Task 14: Mobile UI (Android)

**Files:** Create `lib/ui/mobile/home_tabs.dart`; Modify `lib/app.dart` (choose `HomeTabs` when `Platform.isAndroid`).

Behavior: bottom navigation — **Upcoming** (quick add at top, group filter chips, `CountdownCard` list, FAB → editor), **Calendar** (month grid reused, tap day → bottom sheet list), **Settings**. Permission flow on first launch: notifications (Android 13+) then exact alarms (Android 12+, opens system page via the plugin's `requestExactAlarmsPermission`); banner if denied.

- [ ] **Step 1: Widget test** `test/ui/home_tabs_test.dart`: three tabs exist; Upcoming shows cards sorted by priority then due.
- [ ] **Step 2: Run** → FAIL. **Step 3: Implement.** **Step 4: Run** → PASS; `flutter emulators --launch pixel35 && flutter run -d emulator-5554`; add a deadline due in 2 minutes with reminders on → "due now" notification arrives.
- [ ] **Step 5: Commit** `feat(android): tabbed mobile layout and permission flow`

---

### Task 15: Settings page, Mac import, bootstrap

**Files:** Create `lib/ui/settings_page.dart`; Modify `lib/main.dart`.

Behavior: Settings — precision picker (Days `79d` / Days + hours `79d 1h` / Down to the minute `79d 1h 23m`), show countdown in tray (desktop), Buddhist-era years, launch at login (desktop; Windows/Linux note "Reminders only arrive while the app is running"), notification status + "Send test notification" + "Open system settings", hotkey status (desktop), "Manage groups…". `main()`: init timezone → open DB (show `recoveredFrom` notice if set) → on macOS, if `!macImportDone` and the Mac file exists, `parseMacDeadlines` → `importDeadlines` → set `macImportDone` and show "Imported N deadlines from the Mac app" (on `FormatException`: notice "Couldn't read the Mac app's deadlines", still set `macImportDone`) → create `ReminderService` (macOS: OS scheduling, cap 60; Android: OS, cap 200; Windows/Linux: in-app) → replan on every `deadlinesProvider` change, on resume, and at day change → desktop shell init → `runApp`.

- [ ] **Step 1: Test** `test/ui/settings_page_test.dart`: changing precision to minutes updates a sample card from `79d 1h` to `79d 1h 23m`.
- [ ] **Step 2–4:** fail → implement → pass. Manual: on this Mac, first launch imports the 3 deadlines from the SwiftUI app.
- [ ] **Step 5: Commit** `feat: settings, Mac import, app bootstrap`

---

### Task 16: Release check

- [ ] `TZ=America/New_York flutter test` — all green; `flutter analyze` — clean.
- [ ] `git push` → CI green; download the four artifacts (`gh run download`).
- [ ] macOS: run the built app; verify the checklist from Task 13 + import + a real notification.
- [ ] Android emulator: Task 14 checklist.
- [ ] Windows/Linux: record "built in CI, not run" unless the user has a machine/VM; if they do, verify tray, popup, reminder while running.
- [ ] README: install/run per platform, toolchain on `$DEVTOOLS`, known limits (Windows/Linux reminders need the app running; GNOME tray needs AppIndicator).
- [ ] Commit `docs: README and release checklist results`
