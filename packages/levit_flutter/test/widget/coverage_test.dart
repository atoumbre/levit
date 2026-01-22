import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter/levit_flutter.dart';

void main() {
  group('Levit Flutter Coverage', () {
    testWidgets('LMultiScope update coverage', (tester) async {
      await tester.pumpWidget(
        LMultiScope(
          scopes: [],
          child: Container(),
        ),
      );

      // Trigger update
      await tester.pumpWidget(
        LMultiScope(
          scopes: [],
          child: SizedBox(), // Changed child
        ),
      );

      expect(find.byType(SizedBox), findsOneWidget);
    });

    testWidgets('LScope update assertion warnings (Debug)', (tester) async {
      // Need to capture debug output or just ensure it doesn't crash
      // Since assert usually prints to console, we just run the path.

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: LScope(
            init: () => 'A',
            tag: 'A',
            child: Text('A'),
          ),
        ),
      );

      // Update with DIFFERENT tag - triggers assertion warning path
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: LScope(
            init: () => 'A',
            tag: 'B', // CHANGED
            child: Text('A'),
          ),
        ),
      );
    });

    testWidgets('LConsumer update coverage', (tester) async {
      final v1 = 0.lx;
      final v2 = 1.lx;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: LConsumer(
            v1,
            (v) => Text('V: ${v.value}'),
          ),
        ),
      );
      expect(find.text('V: 0'), findsOneWidget);

      // Update to new reactive instance
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: LConsumer(
            v2,
            (v) => Text('V: ${v.value}'),
          ),
        ),
      );
      expect(find.text('V: 1'), findsOneWidget);
    });

    testWidgets('LWatch cleanup paths (switching strategies)', (tester) async {
      final s1 = 0.lx;
      final s2 = 0.lx;

      // 1. Start with 1 notifier (Fast path)
      await tester.pumpWidget(LWatch(() {
        s1.value;
        return Container();
      }));

      // 2. Switch to Multi (Fast -> Slow)
      await tester.pumpWidget(LWatch(() {
        s1.value;
        s2.value;
        return Container();
      }));

      // 3. Switch to Zero (Slow -> Empty)
      await tester.pumpWidget(LWatch(() {
        return Container();
      }));

      // 4. Switch back to Single (Empty -> Fast) - via new widget
      await tester.pumpWidget(LWatch(() {
        s1.value;
        return Container();
      }));

      // 5. Verify cleanup (Fast -> Empty)
      await tester.pumpWidget(LWatch(() {
        return Container();
      }));
    });
  });
}
