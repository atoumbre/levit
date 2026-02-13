import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter_core/levit_flutter_core.dart';

import 'helpers.dart';

void main() {
  setUp(() {
    Levit.reset(force: true);
  });

  group('LView Coverage', () {
    testWidgets('LView.put registers and resolves', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LView<TestController>.put(
            () => TestController()..count = 42,
            builder: (context, controller) =>
                Text('Count: ${controller.count}'),
          ),
        ),
      );
      expect(find.text('Count: 42'), findsOneWidget);
    });

    testWidgets('LView constructor resolves existing', (tester) async {
      Levit.put(() => TestController()..count = 100);
      await tester.pumpWidget(
        MaterialApp(
          home: LView<TestController>(
            builder: (context, controller) =>
                Text('Count: ${controller.count}'),
          ),
        ),
      );
      expect(find.text('Count: 100'), findsOneWidget);
    });
  });

  group('LAsyncView Coverage', () {
    testWidgets('LAsyncView.put registers and resolves async', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LAsyncView<TestController>.put(
            () async {
              await Future.delayed(const Duration(milliseconds: 10));
              return TestController()..count = 42;
            },
            loading: (_) => const Text('Loading...'),
            builder: (context, controller) =>
                Text('Count: ${controller.count}'),
          ),
        ),
      );
      expect(find.text('Loading...'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('Count: 42'), findsOneWidget);
    });

    testWidgets('LAsyncView constructor resolves existing async',
        (tester) async {
      Levit.lazyPutAsync(() async {
        await Future.delayed(const Duration(milliseconds: 10));
        return TestController()..count = 100;
      });

      await tester.pumpWidget(
        MaterialApp(
          home: LAsyncView<TestController>(
            loading: (_) => const Text('Loading...'),
            builder: (context, controller) =>
                Text('Count: ${controller.count}'),
          ),
        ),
      );
      expect(find.text('Loading...'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('Count: 100'), findsOneWidget);
    });
  });

  group('LScopedView Coverage', () {
    testWidgets('LScopedView.put works with tags and isolation',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LScopedView<TestController>.put(
            () => TestController()..count = 42,
            tag: 'scoped',
            builder: (context, controller) =>
                Text('Count: ${controller.count}'),
          ),
        ),
      );
      expect(find.text('Count: 42'), findsOneWidget);
      // Verify global find fails
      expect(() => Levit.find<TestController>(tag: 'scoped'), throwsException);
    });
  });

  group('LScopedAsyncView Coverage', () {
    testWidgets('LScopedAsyncView.store resolves LevitAsyncState',
        (tester) async {
      final state = LevitAsyncStore<TestController>((_) async {
        await Future.delayed(const Duration(milliseconds: 10));
        return TestController()..count = 99;
      });

      await tester.pumpWidget(
        MaterialApp(
          home: LScopedAsyncView<TestController>.store(
            state,
            loading: (_) => const Text('Loading...'),
            builder: (context, controller) =>
                Text('Count: ${controller.count}'),
          ),
        ),
      );

      expect(find.text('Loading...'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('Count: 99'), findsOneWidget);
    });

    testWidgets('LScopedAsyncView.put works with tags', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LScopedAsyncView<TestController>.put(
            () async {
              await Future.delayed(const Duration(milliseconds: 10));
              return TestController()..count = 42;
            },
            tag: 'async-scoped',
            loading: (_) => const Text('Loading...'),
            builder: (context, controller) =>
                Text('Count: ${controller.count}'),
          ),
        ),
      );

      expect(find.text('Loading...'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('Count: 42'), findsOneWidget);
    });

    testWidgets('LScopedAsyncView handles error state', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LScopedAsyncView<TestController>.put(
            () async {
              await Future.delayed(const Duration(milliseconds: 10));
              throw Exception('Test Error');
            },
            error: (context, error) => Text('Error: $error'),
            builder: (context, controller) => const SizedBox(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.textContaining('Test Error'), findsOneWidget);
    });
  });

  group('LScope Coverage', () {
    testWidgets('LScope.put static factory', (tester) async {
      await tester.pumpWidget(
        LScope.put<TestController>(
          () => TestController()..count = 123,
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                final c = context.levit.find<TestController>();
                return Text('Count: ${c.count}');
              },
            ),
          ),
        ),
      );
      expect(find.text('Count: 123'), findsOneWidget);
    });

    testWidgets('LScope.lazyPut static factory', (tester) async {
      await tester.pumpWidget(
        LScope.lazyPut<TestController>(
          () => TestController()..count = 456,
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                final c = context.levit.find<TestController>();
                return Text('Count: ${c.count}');
              },
            ),
          ),
        ),
      );
      expect(find.text('Count: 456'), findsOneWidget);
    });

    testWidgets('LScope.lazyPutAsync static factory', (tester) async {
      await tester.pumpWidget(
        LScope.lazyPutAsync<TestController>(
          () async {
            await Future.delayed(const Duration(milliseconds: 10));
            return TestController()..count = 789;
          },
          child: MaterialApp(
            home: LAsyncView<TestController>(
              builder: (context, controller) =>
                  Text('Count: ${controller.count}'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Count: 789'), findsOneWidget);
    });
  });

  group('LevitProvider Coverage', () {
    testWidgets('lazyPut with and without scope', (tester) async {
      // Without scope (global)
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              context.levit.lazyPut(() => TestController()..count = 11);
              return Text(
                  'Count: ${context.levit.find<TestController>().count}');
            },
          ),
        ),
      );
      expect(find.text('Count: 11'), findsOneWidget);

      Levit.reset(force: true);

      // With scope
      await tester.pumpWidget(
        LScope(
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                context.levit.lazyPut(() => TestController()..count = 22);
                return Text(
                    'Count: ${context.levit.find<TestController>().count}');
              },
            ),
          ),
        ),
      );
      expect(find.text('Count: 22'), findsOneWidget);
      expect(() => Levit.find<TestController>(), throwsException);
    });
  });
}
