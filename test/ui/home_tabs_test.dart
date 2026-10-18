import 'package:deadlines/core/models.dart';
import 'package:deadlines/state/services.dart';
import 'package:deadlines/ui/mobile/home_tabs.dart';
import 'package:deadlines/ui/widgets/countdown_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fakes.dart';

void main() {
  Future<FakeRepository> pumpPhone(WidgetTester tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final repo = FakeRepository();
    final now = DateTime.now();
    await repo.saveDeadline(sampleDeadline('Soon', now.add(const Duration(days: 1))));
    await repo.saveDeadline(sampleDeadline('Later urgent', now.add(const Duration(days: 5)), priority: Priority.urgent));
    await pumpApp(tester, const HomeTabs(), repo: repo);
    await tester.pump();
    return repo;
  }

  testWidgets('three tabs; Upcoming sorted by priority then due date', (tester) async {
    await pumpPhone(tester);
    for (final tab in ['Upcoming', 'Calendar', 'Settings']) {
      expect(find.descendant(of: find.byType(NavigationBar), matching: find.text(tab)), findsOneWidget);
    }
    final titles = tester.widgetList<CountdownCard>(find.byType(CountdownCard)).map((c) => c.deadline.title);
    expect(titles, ['Later urgent', 'Soon']);
  });

  testWidgets('Calendar and Settings tabs open', (tester) async {
    await pumpPhone(tester);
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Calendar')));
    await tester.pumpAndSettle();
    expect(find.text('Today'), findsOneWidget);
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Settings')));
    await tester.pumpAndSettle();
    expect(find.text('Down to the minute'), findsOneWidget);
  });

  testWidgets('tapping a card opens its detail page', (tester) async {
    await pumpPhone(tester);
    await tester.tap(find.text('Soon'));
    await tester.pumpAndSettle();
    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
  });

  testWidgets('warns when reminders cannot be exact, with an Allow button', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await pumpApp(tester, const HomeTabs(), repo: FakeRepository(), overrides: [
      exactAlarmsProvider.overrideWith(_NoExactAlarms.new),
    ]);
    expect(find.text('Reminders may arrive late'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Allow'), findsOneWidget);
  });
}

class _NoExactAlarms extends ExactAlarmsNotifier {
  @override
  bool build() => false;
}
