import 'package:deadlines/core/models.dart';
import 'package:deadlines/ui/widgets/group_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fakes.dart';

void main() {
  testWidgets('add a group, then delete it after confirming', (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final repo = FakeRepository();
    await repo.saveDeadline(sampleDeadline('Lab', DateTime(2030, 1, 1)));
    await pumpApp(
        tester,
        Builder(
            builder: (context) =>
                TextButton(onPressed: () => showGroupManager(context), child: const Text('groups'))),
        repo: repo);
    await tester.tap(find.text('groups'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'New group'), 'Physics');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(repo.groups.single.name, 'Physics');
    expect(find.text('Physics'), findsOneWidget);

    await repo.saveDeadline(repo.deadlines.single.copyWith(groupId: repo.groups.single.id));
    await tester.pump();
    await tester.tap(find.byTooltip('Delete group'));
    await tester.pumpAndSettle();
    expect(find.textContaining('1 deadline will move to No group'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(repo.groups, isEmpty);
    expect(repo.deadlines.single.groupId, isNull);
    expect(repo.deadlines.single.priority, Priority.normal);
  });
}
