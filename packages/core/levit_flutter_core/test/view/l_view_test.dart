import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter_core/levit_flutter_core.dart';

class CustomView extends LView<int> {
  const CustomView({super.key});

  @override
  Widget buildView(BuildContext context, int controller) {
    return Text('Computed: $controller');
  }
}

class ThrowingView extends LView<int> {
  const ThrowingView({super.key});
}

void main() {
  group('View builders and scoped dependency resolution', () {
    testWidgets(
      'LView subclasses render the dependency resolved from their scope',
      (tester) async {
        await tester.pumpWidget(
          const Directionality(
            textDirection: TextDirection.ltr,
            child: CustomView(),
          ),
        );
        expect(tester.takeException(), isNotNull);

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: LScope(
              configure: (s) => s.put<int>(() => 42),
              child: const CustomView(),
            ),
          ),
        );

        expect(find.text('Computed: 42'), findsOneWidget);
      },
    );

    testWidgets('LView throws when neither builder nor buildView is supplied', (
      tester,
    ) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: LScope(
            configure: (s) => s.put<int>(() => 0),
            child: const ThrowingView(),
          ),
        ),
      );

      expect(tester.takeException(), isUnimplementedError);
    });

    testWidgets('LScopedView recreates its dependency when arguments change', (
      tester,
    ) async {
      int initCount = 0;

      Widget buildSView(int argsValue) {
        return Directionality(
          textDirection: TextDirection.ltr,
          child: LScopedView<int>(
            key: const ValueKey('scoped_view_root'),
            args: [argsValue],
            configure: (s) {
              initCount++;
              s.put<int>(() => argsValue);
            },
            builder: (context, val) {
              return Text('Val: $val');
            },
          ),
        );
      }

      await tester.pumpWidget(buildSView(1));
      expect(initCount, 1);
      expect(find.text('Val: 1'), findsOneWidget);

      await tester.pumpWidget(buildSView(2));
      await tester.pump();
      expect(initCount, 2);
      expect(find.text('Val: 2'), findsOneWidget);
    });

    testWidgets('LAsyncView replaces loading content with the resolved value', (
      tester,
    ) async {
      final completer = Completer<String>();
      await tester.runAsync(() async {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: LAsyncView<String>(
              resolver: (c) => completer.future,
              loading: (c) => const Text('Loading...'),
              builder: (context, val) => Text(val),
            ),
          ),
        );

        expect(find.text('Loading...'), findsOneWidget);

        completer.complete('Ready');
        await tester.pump();
        await tester.pump();

        expect(find.text('Ready'), findsOneWidget);
      });
    });
  });
}
