import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter_core/levit_flutter_core.dart';

void main() {
  group('LScope Update Behavior', () {
    testWidgets('LScope update coverage', (tester) async {
      await tester.pumpWidget(
        LScope(
          dependencyFactory: null,
          child: Container(),
        ),
      );

      await tester.pumpWidget(
        LScope(
          dependencyFactory: null,
          child: const SizedBox(),
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
            dependencyFactory: (s) => s.put(() => 'A', tag: 'B'),
            child: const Text('A'),
          ),
        ),
      );
    });
  });
}
