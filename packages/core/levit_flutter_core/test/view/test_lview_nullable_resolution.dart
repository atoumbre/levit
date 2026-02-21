import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:levit_flutter_core/levit_flutter_core.dart';

import '../helpers.dart';

void main() {
  setUp(() {
    Levit.reset(force: true);
  });

  group('LView orElse', () {
    testWidgets('renders builder when controller is registered',
        (tester) async {
      Levit.put(() => TestController()..count = 7);

      await tester.pumpWidget(
        MaterialApp(
          home: LView<TestController>(
            builder: (context, controller) =>
                Text('Count: ${controller.count}'),
            orElse: (context) => const Text('Fallback'),
            autoWatch: false,
          ),
        ),
      );

      expect(find.text('Count: 7'), findsOneWidget);
      expect(find.text('Fallback'), findsNothing);
    });

    testWidgets('renders orElse when controller is not registered',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LView<TestController>(
            builder: (context, controller) => const Text('Found'),
            orElse: (context) => const Text('Not available'),
            autoWatch: false,
          ),
        ),
      );

      expect(find.text('Not available'), findsOneWidget);
      expect(find.text('Found'), findsNothing);
    });

    testWidgets('throws StateError when controller missing and no orElse',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LView<TestController>(
            builder: (context, controller) => const Text('Found'),
            autoWatch: false,
          ),
        ),
      );

      expect(tester.takeException(), isA<StateError>());
    });

    testWidgets('reactive updates work with autoWatch and orElse',
        (tester) async {
      final controller = TestController();
      Levit.put(() => controller);

      await tester.pumpWidget(
        MaterialApp(
          home: LView<TestController>(
            builder: (context, c) => Text('Reactive: ${c.reactiveCount.value}'),
            orElse: (context) => const Text('Fallback'),
          ),
        ),
      );

      expect(find.text('Reactive: 0'), findsOneWidget);

      controller.reactiveCount.value = 99;
      await tester.pump();

      expect(find.text('Reactive: 99'), findsOneWidget);
    });

    testWidgets('renders builder with tagged controller', (tester) async {
      Levit.put(() => TestController()..count = 55, tag: 'special');

      await tester.pumpWidget(
        MaterialApp(
          home: LView<TestController>(
            resolver: (context) =>
                context.levit.findOrNull<TestController>(tag: 'special'),
            builder: (context, controller) =>
                Text('Tagged: ${controller.count}'),
            orElse: (context) => const Text('Not found'),
            autoWatch: false,
          ),
        ),
      );

      expect(find.text('Tagged: 55'), findsOneWidget);
    });

    testWidgets('renders orElse with wrong tag', (tester) async {
      Levit.put(() => TestController()..count = 55, tag: 'special');

      await tester.pumpWidget(
        MaterialApp(
          home: LView<TestController>(
            resolver: (context) =>
                context.levit.findOrNull<TestController>(tag: 'wrong'),
            builder: (context, controller) => const Text('Found'),
            orElse: (context) => const Text('Wrong tag'),
            autoWatch: false,
          ),
        ),
      );

      expect(find.text('Wrong tag'), findsOneWidget);
    });
  });
}
