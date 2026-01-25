import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:levit_flutter_core/levit_flutter_core.dart';

import '../helpers.dart';

void main() {
  setUp(() {
    Levit.reset(force: true);
  });

  group('LView', () {
    testWidgets('provides controller access', (tester) async {
      Levit.put(() => TestController()..count = 42);

      await tester.pumpWidget(
        MaterialApp(
          home: LView<TestController>(
            resolver: (context) => context.levit.find<TestController>(),
            builder: (context, controller) =>
                Text('Count: ${controller.count}'),
            autoWatch: false,
          ),
        ),
      );

      expect(find.text('Count: 42'), findsOneWidget);
    });

    testWidgets('supports tagged controller', (tester) async {
      Levit.put(() => TestController()..count = 100, tag: 'special');

      await tester.pumpWidget(
        MaterialApp(
          home: LView<TestController>(
            resolver: (context) =>
                context.levit.find<TestController>(tag: 'special'),
            builder: (context, controller) =>
                Text('Count: ${controller.count}'),
            autoWatch: false,
          ),
        ),
      );

      expect(find.text('Count: 100'), findsOneWidget);
    });

    testWidgets('autoWatch enables automatic reactivity', (tester) async {
      final controller = TestController();
      Levit.put(() => controller);

      await tester.pumpWidget(
        MaterialApp(
          home: LView<TestController>(
            resolver: (context) => context.levit.find<TestController>(),
            builder: (context, controller) =>
                Text('Reactive: ${controller.reactiveCount.value}'),
          ),
        ),
      );

      expect(find.text('Reactive: 0'), findsOneWidget);

      controller.reactiveCount.value = 42;
      await tester.pump();

      expect(find.text('Reactive: 42'), findsOneWidget);
    });

    testWidgets('throws if controller missing', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LView<TestController>(
            resolver: (context) => context.levit.find<TestController>(),
            builder: (context, controller) => Container(),
          ),
        ),
      );
      expect(tester.takeException(), isException);
    });
  });

  group('LScopedView', () {
    testWidgets('creates and provides controller', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: TestScopedView()),
      );

      expect(find.text('Count: 0'), findsOneWidget);
    });

    testWidgets('disposes controller on widget removal', (tester) async {
      final showWidget = ValueNotifier(true);
      TestController? controller;

      await tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder<bool>(
            valueListenable: showWidget,
            builder: (context, show, __) => show
                ? MapScopedView(onController: (c) => controller = c)
                : const Text('Hidden'),
          ),
        ),
      );

      expect(find.text('Count: 0'), findsOneWidget);
      expect(controller?.closeCalled, isFalse);

      showWidget.value = false;
      await tester.pump();

      expect(find.text('Hidden'), findsOneWidget);
      expect(controller?.closeCalled, isTrue);
    });

    testWidgets('autoWatch enables reactive updates', (tester) async {
      late TestController controller;

      await tester.pumpWidget(
        MaterialApp(
          home: MapScopedView(onController: (c) => controller = c),
        ),
      );

      expect(find.text('Count: 0'), findsOneWidget);

      controller.reactiveCount.value = 42;
      await tester.pump();

      expect(find.text('Reactive Count: 42'), findsOneWidget);
    });

    testWidgets('nests inside another LScopedView', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: OuterScopedView(),
        ),
      );

      expect(find.text('Outer: 1, Inner: 2'), findsOneWidget);
    });
  });
}

// Test helpers for LScopedView

class TestScopedView extends StatelessWidget {
  const TestScopedView({super.key});

  @override
  Widget build(BuildContext context) {
    return LScopedView<TestController>(
      dependencyFactory: (s) => s.put<TestController>(() => TestController()),
      resolver: (context) => context.levit.find<TestController>(),
      builder: (context, controller) => Text('Count: ${controller.count}'),
    );
  }
}

class MapScopedView extends StatelessWidget {
  final void Function(TestController) onController;

  const MapScopedView({super.key, required this.onController});

  @override
  Widget build(BuildContext context) {
    return LScopedView<TestController>(
      dependencyFactory: (s) => s.put<TestController>(() => TestController()),
      resolver: (context) => context.levit.find<TestController>(),
      builder: (context, controller) {
        onController(controller);
        if (controller.reactiveCount.value == 0) {
          return Text('Count: ${controller.count}');
        }
        return Text('Reactive Count: ${controller.reactiveCount.value}');
      },
    );
  }
}

class OuterScopedView extends StatelessWidget {
  const OuterScopedView({super.key});

  @override
  Widget build(BuildContext context) {
    return LScopedView<TestController>(
      scopeName: 'OuterScope',
      dependencyFactory: (s) =>
          s.put<TestController>(() => TestController()..count = 1),
      resolver: (context) => context.levit.find<TestController>(),
      builder: (context, controller) =>
          InnerScopedView(outerCount: controller.count),
    );
  }
}

class InnerScopedView extends StatelessWidget {
  final int outerCount;

  const InnerScopedView({super.key, required this.outerCount});

  @override
  Widget build(BuildContext context) {
    return LScopedView<AnotherController>(
      scopeName: 'InnerScope',
      dependencyFactory: (s) =>
          s.put<AnotherController>(() => AnotherController()..name = '2'),
      resolver: (context) => context.levit.find<AnotherController>(),
      builder: (context, controller) =>
          Text('Outer: $outerCount, Inner: ${controller.name}'),
    );
  }
}
