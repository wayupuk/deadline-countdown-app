import 'package:deadlines/state/selection.dart';
import 'package:deadlines/ui/desktop/month_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fakes.dart';

void main() {
  Future<FakeRepository> pumpGrid(WidgetTester tester, {Map<String, Object> prefs = const {}}) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final repo = FakeRepository();
    await repo.saveDeadline(sampleDeadline('Thesis', DateTime(2026, 10, 24, 17)));
    await pumpApp(tester, MonthGrid(month: DateTime(2026, 10)), repo: repo, prefs: prefs);
    await tester.pump();
    return repo;
  }

  testWidgets('42 days starting on the Sunday before the 1st', (tester) async {
    await pumpGrid(tester);
    expect(find.byType(DayCell), findsNWidgets(42));
    expect(tester.widget<DayCell>(find.byType(DayCell).first).day, DateTime(2026, 9, 27));
    expect(tester.widget<DayCell>(find.byType(DayCell).last).day, DateTime(2026, 11, 7));
  });

  testWidgets('deadline chip on its day; Buddhist year in the header', (tester) async {
    await pumpGrid(tester, prefs: {'buddhistYears': true});
    expect(find.text('Thesis'), findsOneWidget);
    expect(find.text('2569 BE'), findsOneWidget);
    expect(find.text('October'), findsOneWidget);
  });

  testWidgets('tapping a chip selects that deadline', (tester) async {
    await pumpGrid(tester);
    await tester.tap(find.text('Thesis'));
    await tester.pump();
    final container = ProviderScope.containerOf(tester.element(find.byType(MonthGrid)));
    expect(container.read(calendarSelectionProvider).deadlineId, 'Thesis');
    expect(container.read(calendarSelectionProvider).day, DateTime(2026, 10, 24));
  });
}
