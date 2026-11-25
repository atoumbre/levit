import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter_core/levit_flutter_core.dart';

void main() {
  group('LScope Update Behavior', () {
    testWidgets(
      'LScope replaces its child when rebuilt without a dependency factory',
      (tester) async {
        await tester.pumpWidget(LScope(configure: null, child: Container()));

        await tester.pumpWidget(
          LScope(configure: null, child: const SizedBox()),
        );

        expect(find.byType(SizedBox), findsOneWidget);
      },
    );

    testWidgets('LScope update with dependencyFactory change', (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: LScope(
            configure: (s) => s.put<String>(() => 'A', tag: 'A'),
            child: const Text('A'),
          ),
        ),
      );

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: LScope(
            configure: (s) => s.put<String>(() => 'A', tag: 'B'),
            child: const Text('A'),
          ),
        ),
      );
    });
  });
}
