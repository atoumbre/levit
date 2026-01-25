import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter_core/levit_flutter_core.dart';

void main() {
  group('Levit Flutter Coverage', () {
    testWidgets('LScope update coverage', (tester) async {
      await tester.pumpWidget(
        LScope(
          dependencyFactory: null,
          child: Container(),
        ),
      );

      // Trigger update
      await tester.pumpWidget(
        LScope(
          dependencyFactory: null,
          child: const SizedBox(), // Changed child
        ),
      );

      expect(find.byType(SizedBox), findsOneWidget);
    });

    testWidgets('LScope update with dependencyFactory change', (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: LScope(
            dependencyFactory: (s) => s.put(() => 'A', tag: 'A'),
            child: const Text('A'),
          ),
        ),
      );

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: LScope(
            dependencyFactory: (s) => s.put(() => 'A', tag: 'B'), // CHANGED
            child: const Text('A'),
          ),
        ),
      );
    });

    testWidgets('LWatchVar update coverage', (tester) async {
      final v1 = 0.lx;
      final v2 = 1.lx;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: LWatchVar(
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
          child: LWatchVar(
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
