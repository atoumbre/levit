import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter_core/levit_flutter_core.dart';

class DisposeController extends LevitController {
  final void Function() onDisposed;
  DisposeController(this.onDisposed);

  @override
  void onClose() {
    onDisposed();
    super.onClose();
  }
}

void main() {
  group('LAsyncScope Coverage', () {
    testWidgets('LAsyncScope error state (Line 114)', (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: LAsyncScope(
              dependencyFactory: (s) async =>
                  throw Exception('async create fail'),
              loading: (context) => const Text('Loading'),
              error: (context, error) => Text('Error: ${error.toString()}'),
              child: const Text('Inner'),
            ),
          ),
        );

        await tester.pump();
        expect(find.textContaining('async create fail'), findsOneWidget);
      });
    });

    testWidgets('LAsyncScope updateWidget with different args (Line 151, 159)',
        (tester) async {
      int createCount = 0;

      Widget buildScope(int argsValue) {
        return Directionality(
          textDirection: TextDirection.ltr,
          child: LAsyncScope(
            key: const ValueKey('async_scope'),
            args: [argsValue],
            dependencyFactory: (s) async {
              createCount++;
              s.put<String>(() => 'Result $argsValue');
              return 'ok';
            },
            child: Builder(builder: (context) {
              final val = context.levit.findOrNull<String>() ?? 'none';
              return Text('Val: $val');
            }),
          ),
        );
      }

      await tester.runAsync(() async {
        await tester.pumpWidget(buildScope(1));
        await tester.pumpAndSettle();
        expect(find.text('Val: Result 1'), findsOneWidget);
        expect(createCount, 1);

        // Change args to trigger re-creation (Line 151)
        await tester.pumpWidget(buildScope(2));
        await tester.pumpAndSettle();
        expect(createCount, 2);
        expect(find.text('Val: Result 2'), findsOneWidget);
      });
    });

    testWidgets('LAsyncScope factory disposal (Lines 222-225)', (tester) async {
      bool disposed = false;

      await tester.runAsync(() async {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: LAsyncScope(
              dependencyFactory: (s) async {
                s.put<DisposeController>(
                    () => DisposeController(() => disposed = true));
                return 'ok';
              },
              child: const Text('ok'),
            ),
          ),
        );

        await tester.pumpAndSettle();
        await tester.pumpWidget(Container()); // Dispose

        expect(disposed, true);
      });
    });
  });

  group('LevitProvider and Context Extensions Coverage', () {
    testWidgets('findOrNull and findAsync (Lines 305+)', (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: LScope(
              dependencyFactory: (s) {
                s.lazyPutAsync(() async => 'async_val');
              },
              child: Builder(builder: (context) {
                final val = context.levit.findOrNull<String>();
                return Text('Loaded: ${val != null}');
              }),
            ),
          ),
        );

        await tester.pump();

        final element = tester.element(find.byType(Builder));

        // findOrNull
        expect(element.levit.findOrNull<int>(), isNull);

        // findAsync
        final val = await element.levit.findAsync<String>();
        expect(val, 'async_val');

        // findOrNullAsync
        expect(await element.levit.findOrNullAsync<String>(), 'async_val');
        expect(await element.levit.findOrNullAsync<int>(), isNull);

        // isInstantiated
        expect(element.levit.isInstantiated<String>(), true);
      });
    });
  });
}
