import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter_core/levit_flutter_core.dart';

void main() {
  setUp(() {
    Levit.reset(force: true);
  });

  tearDown(() {
    Levit.reset(force: true);
  });

  group('levit_flutter Coverage Gaps', () {
    testWidgets('LAsyncScope nested scope (Line 185)', (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: LScope(
              name: 'Parent',
              dependencyFactory: (s) => s.put(() => 'parent_val'),
              child: LAsyncScope(
                name: 'Child',
                dependencyFactory: (s) async {
                  return 'ok';
                },
                child: Builder(builder: (context) {
                  return Text('Val: ${context.levit.find<String>()}');
                }),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Val: parent_val'), findsOneWidget);
      });
    });

    testWidgets('LAsyncScope error view (Lines 237-243)', (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: LAsyncScope(
              dependencyFactory: (s) async {
                throw Exception('async error');
              },
              child: const Text('Success'),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
            find.textContaining('Scope Initialization Error'), findsOneWidget);
        expect(find.textContaining('async error'), findsOneWidget);
      });
    });

    testWidgets('LevitProvider findOrNull fallbacks (Lines 285-296)',
        (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(builder: (context) {
            final val = context.levit.findOrNull<String>();
            return Text('Val: ${val ?? 'null'}');
          }),
        ),
      );
      expect(find.text('Val: null'), findsOneWidget);

      final state = LevitStore((ref) => 'state_val');
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(builder: (context) {
            final val = context.levit.findOrNull<String>(key: state);
            return Text('Val: ${val ?? 'null'}');
          }),
        ),
      );
      expect(find.text('Val: state_val'), findsOneWidget);
    });

    testWidgets('LAsyncView.store factory (Lines 116-126)', (tester) async {
      final state = LevitStore.async((ref) async => 'async_val');
      await tester.runAsync(() async {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: LAsyncView<String>.store(
              state,
              builder: (context, val) => Text('Val: $val'),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Val: async_val'), findsOneWidget);
      });
    });

    testWidgets('LAsyncScope + LView update path', (tester) async {
      Widget buildView(int arg) {
        return Directionality(
          textDirection: TextDirection.ltr,
          child: LAsyncScope(
            args: [arg],
            dependencyFactory: (_) async {},
            child: LView<String>(
              resolver: (context) => 'val $arg',
              args: [arg],
              builder: (context, val) => Text('Val: $val'),
            ),
          ),
        );
      }

      await tester.runAsync(() async {
        await tester.pumpWidget(buildView(1));
        await tester.pumpAndSettle();
        expect(find.text('Val: val 1'), findsOneWidget);

        // Update args to trigger didUpdateWidget paths
        await tester.pumpWidget(buildView(2));
        await tester.pumpAndSettle();
        expect(find.text('Val: val 2'), findsOneWidget);
      });
    });
    group('LAsyncScope Extra coverage', () {
      testWidgets(
          'LAsyncScope didUpdateWidget with changed dependencies (Line 194+)',
          (tester) async {
        await tester.runAsync(() async {
          Widget build(int arg) => Directionality(
                textDirection: TextDirection.ltr,
                child: LAsyncScope(
                  args: [arg],
                  dependencyFactory: (s) async {
                    s.put(() => 'val $arg');
                    return 'ok';
                  },
                  child: Builder(
                      builder: (context) => Text(context.levit.find<String>())),
                ),
              );

          await tester.pumpWidget(build(1));
          await tester.pumpAndSettle();
          expect(find.text('val 1'), findsOneWidget);

          await tester.pumpWidget(build(2));
          await tester.pumpAndSettle();
          expect(find.text('val 2'), findsOneWidget);
        });
      });
    });
  });
}
