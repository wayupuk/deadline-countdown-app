import 'package:deadlines/ui/widgets/deadline_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fakes.dart';

void main() {
  Future<void> open(WidgetTester tester, FakeRepository repo, {String? title, DateTime? due}) async {
    tester.view.physicalSize = const Size(1400, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await pumpApp(
        tester,
        Builder(
            builder: (context) => TextButton(
                onPressed: () => showDeadlineEditor(context, title: title, due: due), child: const Text('open'))),
        repo: repo);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  FilledButton saveButton(WidgetTester tester) =>
      tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Add Deadline'));

  testWidgets('save needs a title', (tester) async {
    final repo = FakeRepository();
    await open(tester, repo);
    expect(saveButton(tester).onPressed, isNull);
    await tester.enterText(find.widgetWithText(TextField, 'Title'), 'Thesis');
    await tester.pump();
    expect(saveButton(tester).onPressed, isNotNull);
    await tester.tap(find.text('Add Deadline'));
    await tester.pumpAndSettle();
    expect(repo.deadlines.single.title, 'Thesis');
    expect(repo.deadlines.single.dueAt.second, 0);
  });

  testWidgets('a past time is rejected', (tester) async {
    await open(tester, FakeRepository(), title: 'Old', due: DateTime(2020, 1, 1, 9));
    expect(find.text('Pick a time in the future.'), findsOneWidget);
    expect(saveButton(tester).onPressed, isNull);
  });
}
