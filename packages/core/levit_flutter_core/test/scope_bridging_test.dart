import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter_core/levit_flutter_core.dart';

// A simple service to test injection
class TestService {
  final String value;
  TestService(this.value);
}

void main() {
  testWidgets(
      'Split-Brain: Levit.find fails inside LScope without context.levit',
      (tester) async {
    // 1. Setup: Register a global service to ensure we don't accidentally find it
    Levit.put(() => TestService('Global'), tag: 'test');

    String? foundValue;
    Object? caughtError;

    // 2. Widget Tree with LScope
    await tester.pumpWidget(
      LScope(
        dependencyFactory: (scope) {
          scope.put(() => TestService('Scoped'), tag: 'test');
        },
        child: LWatch(() {
          try {
            // THIS IS THE SPLIT BRAIN TRAP
            // We are using Levit.find() (Global/Zone) inside LScope (Tree)
            // Expectation: It finds 'Global' (or throws if Global wasn't set), NOT 'Scoped'
            final service = Levit.find<TestService>(tag: 'test');
            foundValue = service.value;
          } catch (e) {
            caughtError = e;
          }
          return Container();
        }),
      ),
    );

    // 3. Verify the Fix
    // With the fix, Levit.find should now correctly find 'Scoped' because LWatch bridges the scope via runZoned
    expect(foundValue, 'Scoped');
    expect(caughtError, isNull);

    // Cleanup
    Levit.reset(force: true);
  });

  testWidgets('Split-Brain: Levit.find works inside LBuilder with fix',
      (tester) async {
    Levit.put(() => TestService('Global'), tag: 'test');

    // Use a reactive value to satisfy LBuilder requirements
    final count = LxVar(0);
    String? foundValue;

    await tester.pumpWidget(
      LScope(
        dependencyFactory: (scope) {
          scope.put(() => TestService('Scoped'), tag: 'test');
        },
        child: LBuilder(count, (val) {
          final service = Levit.find<TestService>(tag: 'test');
          foundValue = service.value;
          return Container();
        }),
      ),
    );

    expect(foundValue, 'Scoped');
    Levit.reset(force: true);
  });
}
