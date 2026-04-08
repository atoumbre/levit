import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter_core/levit_flutter_core.dart';

class TestController {
  final int value;
  TestController(this.value);
}

void main() {
  group('LScope Lifecycle & Behavior', () {
    testWidgets('LScope creates and disposes scope correctly', (tester) async {
      bool initialized = false;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: LScope(
            dependencyFactory: (s) =>
                s.put<TestController>(() => TestController(42)),
            child: Builder(
              builder: (context) {
                initialized = true;
                final controller = context.levit.find<TestController>();
                return Text('Value: ${controller.value}');
              },
            ),
          ),
        ),
      );

      expect(initialized, true);
      expect(find.text('Value: 42'), findsOneWidget);

      final element = tester.element(find.text('Value: 42'));
      expect(element.levit.isRegistered<TestController>(), true);

      await tester.pumpWidget(Container());

      initialized = false;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: LScope(
            dependencyFactory: (s) =>
                s.put<TestController>(() => TestController(100)),
            child: Builder(
              builder: (context) {
                initialized = true;
                final controller = context.levit.find<TestController>();
                return Text('Value: ${controller.value}');
              },
            ),
          ),
        ),
      );

      expect(initialized, true);
      expect(find.text('Value: 100'), findsOneWidget);
    });

    testWidgets('Nested LScope inheritance', (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: LScope(
            dependencyFactory: (s) => s.put<int>(() => 1),
            child: LScope(
              dependencyFactory: (s) => s.put<String>(() => 'nested'),
              child: Builder(
                builder: (context) {
                  final i = context.levit.find<int>();
                  final s = context.levit.find<String>();
                  return Text('$i - $s');
                },
              ),
            ),
          ),
        ),
      );

      expect(find.text('1 - nested'), findsOneWidget);
    });

    testWidgets('LScope registers multiple bindings', (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: LScope(
            dependencyFactory: (s) {
              s.put<int>(() => 10);
              s.put<String>(() => 'multi');
            },
            child: Builder(
              builder: (context) {
                final i = context.levit.find<int>();
                final s = context.levit.find<String>();
                return Text('$i $s');
              },
            ),
          ),
        ),
      );

      expect(find.text('10 multi'), findsOneWidget);
    });

    testWidgets('LevitProvider fallback to global', (tester) async {
      Levit.put<double>(() => 3.14);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(
            builder: (context) {
              final d = context.levit.find<double>();
              final exists = context.levit.isRegistered<double>();
              return Text('Pi: $d, Exists: $exists');
            },
          ),
        ),
      );

      expect(find.text('Pi: 3.14, Exists: true'), findsOneWidget);
      Levit.reset();
    });

    testWidgets('LevitProvider put works in scope', (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: LScope(
            dependencyFactory: (s) => s.put<int>(() => 0),
            child: Builder(
              builder: (context) {
                context.levit.put<String>(() => 'dynamic');
                final s = context.levit.find<String>();
                return Text(s);
              },
            ),
          ),
        ),
      );

      expect(find.text('dynamic'), findsOneWidget);
    });
  });
}
