import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:levit_flutter_core/levit_flutter_core.dart';

import '../helpers.dart';

void main() {
  setUp(() {
    Levit.reset(force: true);
  });

  group('LView Shorthands', () {
    testWidgets('LView.controller finds controller', (tester) async {
      Levit.put(() => TestController()..count = 42);

      await tester.pumpWidget(
        MaterialApp(
          home: LView<TestController>(
            builder: (context, controller) =>
                Text('Count: ${controller.count}'),
          ),
        ),
      );

      expect(find.text('Count: 42'), findsOneWidget);
    });

    testWidgets('LView.asyncController finds async controller', (tester) async {
      Levit.lazyPutAsync<TestController>(() async {
        await Future.delayed(const Duration(milliseconds: 10));
        return TestController()..count = 42;
      });

      await tester.pumpWidget(
        MaterialApp(
          home: LAsyncView<TestController>(
            builder: (context, controller) =>
                Text('Count: ${controller.count}'),
            loading: (_) => const Text('Loading...'),
          ),
        ),
      );

      expect(find.text('Loading...'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 20));
      expect(find.text('Count: 42'), findsOneWidget);
    });
  });

  group('LScopedView Shorthands', () {
    testWidgets('LScopedView.controller manages local scope and registration',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LScopedView<TestController>(
            dependencyFactory: (s) =>
                s.put(() => TestController()..count = 123),
            builder: (context, controller) =>
                Text('Scoped: ${controller.count}'),
          ),
        ),
      );

      expect(find.text('Scoped: 123'), findsOneWidget);
      // Verify not in root
      expect(() => Levit.find<TestController>(), throwsA(isA<Exception>()));
    });

    testWidgets('LAsyncScope + LView manages async scope registration',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LAsyncScope(
            dependencyFactory: (s) async {
              await Future.delayed(const Duration(milliseconds: 10));
              s.put(() => TestController()..count = 789);
            },
            loading: (_) => const Text('Loading...'),
            child: LView<TestController>(
              builder: (context, controller) =>
                  Text('AsyncScoped: ${controller.count}'),
            ),
          ),
        ),
      );

      expect(find.text('Loading...'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 20));
      expect(find.text('AsyncScoped: 789'), findsOneWidget);
    });
  });
}
