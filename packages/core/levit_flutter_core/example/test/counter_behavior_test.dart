import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter_example/main.dart' as main_pkg;

void main() {
  group('Counter Behavior', () {
    test('CounterController increments value correctly', () {
      final controller = main_pkg.CounterController();
      expect(controller.count.value, 0);
      controller.increment();
      expect(controller.count.value, 1);
    });

    testWidgets('CounterPage updates UI when incremented',
        (WidgetTester tester) async {
      await tester.pumpWidget(const main_pkg.MyApp());

      // Verify initial state
      expect(find.text('0'), findsOneWidget);
      expect(find.text('1'), findsNothing);

      // Tap increment
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pump();

      // Verify updated state
      expect(find.text('0'), findsNothing);
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('main function runs without errors',
        (WidgetTester tester) async {
      // This covers the main() entry point for 100% coverage
      // We use runAsync because main() might have some async initialization (though not here)
      // and we just want to ensure it completes without crashing.
      await tester.runAsync(() async {
        main_pkg.main();
      });
      await tester.pump();
      expect(find.byType(main_pkg.MyApp), findsOneWidget);
    });
  });
}
