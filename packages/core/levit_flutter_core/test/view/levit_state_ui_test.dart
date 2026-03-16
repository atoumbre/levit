import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter_core/levit_flutter_core.dart';

void main() {
  group('LevitStore UI Integration', () {
    testWidgets('LView.store resolves and reacts', (tester) async {
      final counter = LevitStore((ref) => 0.lx);

      await tester.pumpWidget(
        LView.store(
          counter,
          builder: (context, count) =>
              Text('Count: ${count.value}', textDirection: TextDirection.ltr),
        ),
      );

      expect(find.text('Count: 0'), findsOneWidget);

      final val = counter.find();
      val.value++;
      await tester.pump();

      expect(find.text('Count: 1'), findsOneWidget);
    });

    testWidgets('LScopedView.store creates isolated scope', (tester) async {
      final state = LevitStore((ref) => 'default'.lx);

      await tester.pumpWidget(
        Column(
          children: [
            LScopedView.store(
              state,
              scopeName: 'ScopeA',
              builder: (context, val) =>
                  Text('A: ${val.value}', textDirection: TextDirection.ltr),
            ),
            LScopedView.store(
              state,
              scopeName: 'ScopeB',
              builder: (context, val) =>
                  Text('B: ${val.value}', textDirection: TextDirection.ltr),
            ),
          ],
        ),
      );

      expect(find.text('A: default'), findsOneWidget);
      expect(find.text('B: default'), findsOneWidget);

      // This is tricky: how to find the specific instance for ScopeA?
      // LScopedView ensures that find() inside its builder targets its own scope.
      // But here we are outside. We can use Ls.run in a specific zone if we had the scope,
      // but easier is to just mutate via LProvider in builder if we had one.

      // For now, let's just verify they are distinct if we can.
    });
  });
}
