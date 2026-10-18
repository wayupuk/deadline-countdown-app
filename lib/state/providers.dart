import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models.dart';
import '../core/sorting.dart';
import '../data/repository.dart';
import 'clock.dart';

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

/// The soonest upcoming deadline — what the tray/menu bar countdown shows.
final nearestProvider =
    Provider<Deadline?>((ref) => nearest(ref.watch(deadlinesProvider).value ?? const [], ref.watch(nowProvider)));
