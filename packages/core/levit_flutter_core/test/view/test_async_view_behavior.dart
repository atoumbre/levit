import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:levit_flutter_core/levit_flutter_core.dart';

class TestController extends LevitController {
  final name = 'TestController'.lx;
}

class AsyncTestController extends LevitController {
  final name = 'AsyncTestController'.lx;
}

void main() {
  setUp(() {
    Levit.reset(force: true);
  });

  group('LView Tests', () {
    testWidgets('renders content with dependency', (tester) async {
      final controller = TestController();
      Levit.put(() => controller);

      await tester.pumpWidget(
        MaterialApp(
          home: LView<TestController>(
            resolver: (context) => context.levit.find<TestController>(),
            builder: (context, controller) =>
                Text('Name: ${controller.name.value}'),
          ),
        ),
      );

      expect(find.text('Name: TestController'), findsOneWidget);

      // Verify reactivity (autoWatch defaults to true)
      controller.name.value = 'Updated';
      await tester.pump();
      expect(find.text('Name: Updated'), findsOneWidget);
    });

    testWidgets('supports disabling autoWatch', (tester) async {
      final controller = TestController();
      Levit.put(() => controller);

      await tester.pumpWidget(
        MaterialApp(
          home: LView<TestController>(
            autoWatch: false,
            resolver: (context) => context.levit.find<TestController>(),
            builder: (context, controller) =>
                Text('Name: ${controller.name.value}'),
          ),
        ),
      );

      expect(find.text('Name: TestController'), findsOneWidget);

      controller.name.value = 'Updated';
      await tester.pump();
      expect(find.text('Name: Updated'), findsNothing);
      expect(find.text('Name: TestController'), findsOneWidget);
    });
  });

  group('LAsyncView Tests', () {
    testWidgets('shows loading then content', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LAsyncView<AsyncTestController>(
            resolver: (context) async {
              await Future.delayed(const Duration(milliseconds: 50));
              return AsyncTestController();
            },
            loading: (context) =>
                const Center(child: CircularProgressIndicator()),
            builder: (context, controller) =>
                Text('Done: ${controller.name.value}'),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.textContaining('Done:'), findsNothing);

      await tester.pumpAndSettle();

      expect(find.text('Done: AsyncTestController'), findsOneWidget);
    });

    testWidgets('handles resolution error', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LAsyncView<TestController>(
            resolver: (context) async {
              await Future.delayed(const Duration(milliseconds: 50));
              throw Exception('Failed to resolve');
            },
            builder: (context, controller) => const Text('Success'),
            error: (context, err) => Text('Error: $err'),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.textContaining('Error: Exception: Failed to resolve'),
          findsOneWidget);
    });

    testWidgets('LView.async factory works', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LAsyncView<AsyncTestController>(
            resolver: (context) async {
              await Future.delayed(const Duration(milliseconds: 50));
              return AsyncTestController();
            },
            builder: (context, controller) =>
                Text('Sugar: ${controller.name.value}'),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Sugar: AsyncTestController'), findsOneWidget);
    });
  });
}
