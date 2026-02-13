import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_async/fake_async.dart';
import 'package:levit_flutter_core/levit_flutter_core.dart';
import 'package:levit_flutter_core_example/main.dart' as main_pkg;

void main() {
  group('Task board behavior', () {
    test('TaskBoardController filters and counts tasks', () {
      final controller = main_pkg.TaskBoardController();
      controller.onInit();

      expect(controller.tasks.length, 3);
      expect(controller.completedCount.value, 1);

      controller.setFilter(main_pkg.TaskFilter.done);
      expect(controller.visibleTasks.value.length, 1);

      controller.setFilter(main_pkg.TaskFilter.active);
      expect(controller.visibleTasks.value.length, 2);

      controller.toggleTask(1);
      expect(controller.completedCount.value, 2);

      controller.clearCompleted();
      expect(controller.tasks.length, 2);

      controller.onClose();
    });

    test('TaskItem.copyWith preserves done by default', () {
      const item = main_pkg.TaskItem(id: 1, title: 'a', done: true);
      final updated = item.copyWith(title: 'b');
      expect(updated.done, true);
      expect(updated.title, 'b');
    });

    test('markAll and saveBoard handle empty tasks', () {
      fakeAsync((async) {
        final controller = main_pkg.TaskBoardController();
        controller.onInit();

        controller.tasks.clear();

        controller.markAll(done: true);
        expect(controller.isBulkUpdating.value, false);

        controller.saveBoard();
        expect(controller.saveStatus.value, isA<LxWaiting<String>>());

        async.elapse(const Duration(milliseconds: 450));

        expect(controller.saveStatus.value, isA<LxError<String>>());
        controller.onClose();
      });
    });

    testWidgets('TaskBoardPage can add tasks and save',
        (WidgetTester tester) async {
      await tester.pumpWidget(const main_pkg.TaskBoardApp());

      expect(find.text('Document architecture decisions'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Add roadmap milestone');
      await tester.tap(find.byIcon(Icons.add_task));
      await tester.pump();
      expect(find.text('Add roadmap milestone'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.save));
      await tester.pump();
      expect(find.text('Saving...'), findsOneWidget);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));
      expect(find.textContaining('Saved'), findsOneWidget);
    });

    testWidgets('Filters, bulk actions, and error state are reachable',
        (WidgetTester tester) async {
      await tester.pumpWidget(const main_pkg.TaskBoardApp());

      final controller = tester
          .element(find.byType(main_pkg.TaskBoardPage))
          .levit
          .find<main_pkg.TaskBoardController>();

      // Choice chips
      await tester.tap(find.text('done'));
      await tester.pump();
      await tester.tap(find.text('active'));
      await tester.pump();

      // Toggle a task via checkbox
      await tester.tap(find.byKey(const ValueKey('task_1')));
      await tester.pump();

      // Bulk mark all done then all active (covers busy disabling too)
      await tester.tap(find.text('Mark all done'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Mark all active'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Clear completed
      await tester.tap(find.text('Clear completed'));
      await tester.pump();

      // Submit via keyboard to cover onSubmitted
      await tester.tap(find.byType(TextField).first);
      await tester.enterText(find.byType(TextField).first, 'Keyboard task');
      tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(find.text('Keyboard task'), findsOneWidget);

      // Empty tasks -> save error + empty filter UI
      controller.tasks.clear();
      controller.setFilter(main_pkg.TaskFilter.done);
      await tester.pump();
      expect(find.text('No tasks in this filter.'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.save));
      await tester.pump(const Duration(milliseconds: 450));
      expect(find.textContaining('Add at least one task'), findsOneWidget);
    });

    testWidgets('main function runs without errors',
        (WidgetTester tester) async {
      await tester.runAsync(() async {
        main_pkg.main();
      });
      await tester.pump();
      expect(find.byType(main_pkg.TaskBoardApp), findsOneWidget);
    });
  });
}
