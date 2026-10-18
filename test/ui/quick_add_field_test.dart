import 'package:deadlines/core/models.dart';
import 'package:deadlines/ui/widgets/quick_add_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fakes.dart';

void main() {
  testWidgets('preview shows title, priority and countdown', (tester) async {
    await pumpApp(tester, const QuickAddField(), repo: FakeRepository());
    await tester.enterText(find.byType(TextField), 'Thesis Oct 24 2030 5pm !!');
    await tester.pump();
    expect(find.text('Thesis'), findsOneWidget);
    expect(find.text('Urgent'), findsOneWidget);
    expect(find.textContaining('in '), findsOneWidget);
  });

  testWidgets('explains a missing date', (tester) async {
    await pumpApp(tester, const QuickAddField(), repo: FakeRepository());
    await tester.enterText(find.byType(TextField), 'Buy groceries');
    await tester.pump();
    expect(find.text('Add a date, e.g. "tomorrow 5pm" or "Oct 24"'), findsOneWidget);
  });

  testWidgets('Enter saves the deadline and clears the field', (tester) async {
    final repo = FakeRepository();
    await pumpApp(tester, const QuickAddField(), repo: repo);
    await tester.enterText(find.byType(TextField), 'Thesis Oct 24 2030 5pm !');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(repo.deadlines.single.title, 'Thesis');
    expect(repo.deadlines.single.dueAt, DateTime(2030, 10, 24, 17));
    expect(repo.deadlines.single.priority, Priority.high);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
  });

  testWidgets('#group puts it in an existing group', (tester) async {
    final repo = FakeRepository();
    final physics = await repo.createGroup('Physics', DeadlineColor.teal);
    await pumpApp(tester, const QuickAddField(), repo: repo);
    await tester.enterText(find.byType(TextField), 'Lab Oct 24 2030 #physics');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(repo.deadlines.single.groupId, physics.id);
  });
}
