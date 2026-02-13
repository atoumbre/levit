import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter_core/levit_flutter_core.dart';

// Mocks
class TestController extends LevitController {
  final count = 0.lx;
  @override
  void onInit() {
    super.onInit();
    count.value++; // increment on init to prove new instance
  }
}

// Extension Examples
class ExtendedLView extends LView<TestController> {
  const ExtendedLView({super.key});
  @override
  Widget buildView(BuildContext context, TestController controller) {
    return Text('Extended: ${controller.count.value}');
  }
}

class ExtendedLScopedView extends LScopedView<TestController> {
  const ExtendedLScopedView({super.key});

  @override
  TestController onConfigScope(LevitScope scope) {
    return scope.put(() => TestController());
  }

  @override
  Widget buildView(BuildContext context, TestController controller) {
    return Text('ExtendedScoped: ${controller.count.value}');
  }
}

class ExtendedLAsyncScopeView extends StatelessWidget {
  const ExtendedLAsyncScopeView({super.key});

  @override
  Widget build(BuildContext context) {
    return LAsyncScope(
      dependencyFactory: (scope) async {
        await Future.delayed(const Duration(milliseconds: 10));
        scope.put(() => TestController());
      },
      loading: (_) => const Text('Loading...'),
      child: LView<TestController>(
        builder: (context, controller) =>
            Text('ExtendedAsyncScope: ${controller.count.value}'),
      ),
    );
  }
}

void main() {
  group('View Compatibility Tests', () {
    testWidgets('LView supports Composition', (tester) async {
      final controller = TestController();
      Levit.put(() => controller); // Register globally for LView lookup

      await tester.pumpWidget(MaterialApp(
        home: LView<TestController>(
          builder: (context, c) => Text('Composition: ${c.count.value}'),
        ),
      ));

      expect(find.text('Composition: 1'), findsOneWidget);

      // Verify reactivity
      controller.count.value++;
      await tester.pump();
      expect(find.text('Composition: 2'), findsOneWidget);

      Levit.reset();
    });

    testWidgets('LView supports Extension', (tester) async {
      final controller = TestController();
      Levit.put(() => controller);

      await tester.pumpWidget(const MaterialApp(
        home: ExtendedLView(),
      ));

      expect(find.text('Extended: 1'), findsOneWidget);

      controller.count.value++;
      await tester.pump();
      expect(find.text('Extended: 2'), findsOneWidget);

      Levit.reset();
    });

    testWidgets('LScopedView supports Composition', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: LScopedView<TestController>(
          dependencyFactory: (scope) => scope.put(() => TestController()),
          builder: (context, c) => Text('ScopedComposition: ${c.count.value}'),
        ),
      ));

      expect(find.text('ScopedComposition: 1'), findsOneWidget);
    });

    testWidgets('LScopedView supports Extension', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: ExtendedLScopedView(),
      ));

      expect(find.text('ExtendedScoped: 1'), findsOneWidget);
    });

    testWidgets('LAsyncScope + LView supports Composition', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: LAsyncScope(
          dependencyFactory: (scope) async {
            await Future.delayed(const Duration(milliseconds: 10));
            scope.put(() => TestController());
          },
          loading: (_) => const Text('Loading...'),
          child: LView<TestController>(
            builder: (context, c) =>
                Text('AsyncScopeComposition: ${c.count.value}'),
          ),
        ),
      ));

      expect(find.text('Loading...'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 20));
      expect(find.text('AsyncScopeComposition: 1'), findsOneWidget);
    });

    testWidgets('LAsyncScope + LView supports Extension', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: const ExtendedLAsyncScopeView(),
      ));

      expect(find.text('Loading...'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 20));
      expect(find.text('ExtendedAsyncScope: 1'), findsOneWidget);
    });
  });
}
