import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:levit_flutter_core/levit_flutter_core.dart';

import '../helpers.dart';

void main() {
  setUp(() {
    Levit.reset(force: true);
  });

  group('LScopedView orElse', () {
    testWidgets('renders builder when dependencyFactory registers controller',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LScopedView<TestController>.put(
            () => TestController()..count = 10,
            builder: (context, controller) =>
                Text('Count: ${controller.count}'),
            orElse: (context) => const Text('Fallback'),
          ),
        ),
      );

      expect(find.text('Count: 10'), findsOneWidget);
      expect(find.text('Fallback'), findsNothing);
    });

    testWidgets('renders orElse when no matching controller in scope',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LScopedView<TestController>(
            builder: (context, controller) => const Text('Found'),
            orElse: (context) => const Text('Not available'),
          ),
        ),
      );

      expect(find.text('Not available'), findsOneWidget);
      expect(find.text('Found'), findsNothing);
    });

    testWidgets('throws StateError when missing and no orElse', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LScopedView<TestController>(
            builder: (context, controller) => const Text('Found'),
          ),
        ),
      );

      expect(tester.takeException(), isA<StateError>());
    });

    testWidgets('disposes controller from scope on unmount', (tester) async {
      final showWidget = ValueNotifier(true);
      TestController? captured;

      await tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder<bool>(
            valueListenable: showWidget,
            builder: (context, show, __) => show
                ? LScopedView<TestController>.put(
                    () => TestController(),
                    builder: (context, controller) {
                      captured = controller;
                      return Text('Count: ${controller.count}');
                    },
                    orElse: (context) => const Text('Fallback'),
                  )
                : const Text('Hidden'),
          ),
        ),
      );

      expect(find.text('Count: 0'), findsOneWidget);
      expect(captured?.closeCalled, isFalse);

      showWidget.value = false;
      await tester.pump();

      expect(find.text('Hidden'), findsOneWidget);
      expect(captured?.closeCalled, isTrue);
    });
  });
}
