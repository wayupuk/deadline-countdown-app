import 'package:deadlines/ui/settings_page.dart';
import 'package:deadlines/ui/widgets/countdown_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fakes.dart';

void main() {
  testWidgets('precision setting changes live countdowns', (tester) async {
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final due = DateTime.now().add(const Duration(days: 79, hours: 1, minutes: 23, seconds: 30));
    final repo = FakeRepository();
    await pumpApp(
        tester,
        Column(children: [
          CountdownCard(deadline: sampleDeadline('Grant', due)),
          const Expanded(child: SettingsPage()),
        ]),
        repo: repo);
    Finder onCard(String text) => find.descendant(of: find.byType(CountdownCard), matching: find.text(text));
    expect(onCard('79d 1h'), findsOneWidget);
    await tester.tap(find.text('Down to the minute'));
    await tester.pump();
    expect(onCard('79d 1h 23m'), findsOneWidget);
  });

  testWidgets('Buddhist-era years switch is saved', (tester) async {
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await pumpApp(tester, const SettingsPage(), repo: FakeRepository(), prefs: {'buddhistYears': false});
    await tester.tap(find.text('Buddhist-era years (BE)'));
    await tester.pump();
    expect(tester.widget<SwitchListTile>(find.widgetWithText(SwitchListTile, 'Buddhist-era years (BE)')).value, isTrue);
  });
}
