import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter_core/levit_flutter_core.dart';

void main() {
  group('levit_flutter_core Final Gaps', () {
    testWidgets('LAsyncView.store coverage', (tester) async {
      final state = LevitAsyncStore((ref) async => 'hello');

      await tester.pumpWidget(
        MaterialApp(
          home: LAsyncView.store(
            state,
            builder: (context, value) => Text(value),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('hello'), findsOneWidget);
    });

    testWidgets('LAsyncView error handling and build helpers', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LAsyncView<String>(
            resolver: (context) async => throw Exception('View Error'),
            builder: (context, value) => Text(value),
            error: (context, err) => Text('Custom Error: $err'),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.textContaining('Custom Error'), findsOneWidget);
    });

    testWidgets('LAsyncView didUpdateWidget', (tester) async {
      final resolver1 = (BuildContext c) async => 'val1';
      final resolver2 = (BuildContext c) async => 'val2';

      await tester.pumpWidget(
        MaterialApp(
          home: LAsyncView<String>(
            resolver: resolver1,
            builder: (context, value) => Text(value),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('val1'), findsOneWidget);

      await tester.pumpWidget(
        MaterialApp(
          home: LAsyncView<String>(
            resolver: resolver2,
            builder: (context, value) => Text(value),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('val2'), findsOneWidget);
    });

    testWidgets('LScopedView.store coverage', (tester) async {
      final state = LevitStore((ref) => 'scoped_val');

      await tester.pumpWidget(
        MaterialApp(
          home: LScopedView.store(
            state,
            builder: (context, value) => Text(value),
          ),
        ),
      );

      expect(find.text('scoped_val'), findsOneWidget);
    });

    testWidgets('LAsyncScope + LView.store coverage', (tester) async {
      final state = LevitStore((ref) => 'async_scoped_val');

      await tester.pumpWidget(
        MaterialApp(
          home: LAsyncScope(
            dependencyFactory: (_) async {},
            child: LView.store(
              state,
              builder: (context, value) => Text(value),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('async_scoped_val'), findsOneWidget);
    });

    testWidgets('LWatchStatus lifecycle and context', (tester) async {
      final rx = LxIdle<String>().lx;

      Levit.enableAutoLinking();

      await tester.pumpWidget(
        MaterialApp(
          home: LStatusBuilder<String>(
            rx,
            onSuccess: (data) => Text('Data: $data'),
            onIdle: () => const Text('Idle'),
          ),
        ),
      );
      expect(find.text('Idle'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('LAsyncView autoWatch: false (view.dart:221)', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: LAsyncView<String>(
          resolver: (context) async => 'no-watch',
          builder: (context, value) => Text(value),
          autoWatch: false,
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('no-watch'), findsOneWidget);
    });

    testWidgets('LevitBuildContextExtensions global fallback (scope.dart)',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              context.levit.findOrNullAsync<String>();
              context.levit.isRegistered<String>();
              context.levit.isInstantiated<String>();
              context.levit.put(() => 'global');
              context.levit.lazyPutAsync(() async => 'global_async');

              final state = LevitStore((ref) => 1);
              context.levit.findOrNullAsync(key: state);
              context.levit.isRegistered(key: state);
              context.levit.isInstantiated(key: state);

              return const SizedBox();
            },
          ),
        ),
      );
    });
  });
}
