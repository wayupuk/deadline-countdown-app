import 'package:deadlines/state/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fakes.dart';

/// Clock the test moves by hand.
class _ManualClock extends ClockNotifier {
  _ManualClock(this._start);
  final DateTime _start;
  @override
  DateTime build() => _start;
  void set(DateTime t) => state = t;
}

void main() {
  test('tray text follows the clock, not just deadline edits', () async {
    SharedPreferences.setMockInitialValues({'precision': 'minutes'});
    final prefs = await SharedPreferences.getInstance();
    final start = DateTime.now();
    final repo = FakeRepository();
    await repo.saveDeadline(sampleDeadline('Thesis', start.add(const Duration(days: 3, hours: 4, minutes: 10, seconds: 30))));
    final container = ProviderContainer(overrides: [
      repositoryProvider.overrideWithValue(repo),
      sharedPreferencesProvider.overrideWithValue(prefs),
      nowProvider.overrideWith(() => _ManualClock(start)),
    ]);
    addTearDown(container.dispose);
    final seen = <String?>[];
    container.listen(trayTextProvider, (_, next) => seen.add(next.title), fireImmediately: true);
    await container.read(deadlinesProvider.future);
    await Future<void>.delayed(Duration.zero);
    (container.read(nowProvider.notifier) as _ManualClock).set(start.add(const Duration(minutes: 1)));
    await Future<void>.delayed(Duration.zero);
    expect(seen.last, '3d 4h 9m');
    expect(seen, contains('3d 4h 10m'));
    expect(container.read(trayTextProvider).tooltip, 'Thesis — 3d 4h 9m');
  });
}
