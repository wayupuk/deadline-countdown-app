import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/countdown.dart';
import '../core/models.dart';
import '../core/sorting.dart';
import '../data/repository.dart';
import 'clock.dart';
import 'settings.dart';

export 'settings.dart';

/// Overridden in `main()` with the repository for the opened database.
final repositoryProvider = Provider<DeadlineRepository>((ref) => throw UnimplementedError('override in main'));

final deadlinesProvider = StreamProvider<List<Deadline>>((ref) => ref.watch(repositoryProvider).watchDeadlines());

final groupsProvider = StreamProvider<List<Group>>((ref) => ref.watch(repositoryProvider).watchGroups());

/// "Now", updated exactly when the nearest countdown's minute changes.
final nowProvider = NotifierProvider<ClockNotifier, DateTime>(ClockNotifier.new);

class ClockNotifier extends Notifier<DateTime> {
  MinuteTicker? _ticker;

  @override
  DateTime build() {
    final ticker = MinuteTicker(
        nextDue: () => nearest(ref.read(deadlinesProvider).value ?? const [], DateTime.now())?.dueAt);
    _ticker = ticker;
    ticker.start((now) => state = now);
    // Edits can change which deadline is nearest, so re-plan the next tick.
    ref.listen(deadlinesProvider, (_, _) => ticker.poke());
    ref.onDispose(ticker.stop);
    return DateTime.now();
  }

  /// Re-plan now (waking from sleep, day change).
  void refresh() => _ticker?.poke();
}

/// Menu bar title and tray tooltip. A record compares by value, so listeners fire when the text changes —
/// including every minute tick — not only when the deadline list changes.
final trayTextProvider = Provider<({String? title, String tooltip})>((ref) {
  final next = ref.watch(nearestProvider);
  final now = ref.watch(nowProvider);
  final precision = ref.watch(settingsProvider.select((s) => s.precision));
  if (next == null) return (title: null, tooltip: 'Deadline Countdown');
  final text = shortCountdown(now, next.dueAt, precision: precision);
  return (title: text, tooltip: '${next.title} — $text');
});

/// The soonest upcoming deadline — what the tray/menu bar countdown shows.
final nearestProvider =
    Provider<Deadline?>((ref) => nearest(ref.watch(deadlinesProvider).value ?? const [], ref.watch(nowProvider)));
