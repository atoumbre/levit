import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:levit_flutter/levit_flutter.dart';

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
          home: TestLView(),
        ),
      );

      expect(find.text('Count: 42'), findsOneWidget);
    });

    testWidgets('supports tagged controller', (tester) async {
      Levit.put(() => TestController()..count = 100, tag: 'special');

      await tester.pumpWidget(
        MaterialApp(
          home: TaggedLView(),
        ),
      );

      expect(find.text('Count: 100'), findsOneWidget);
    });

    testWidgets('creates controller if not registered', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: TestLWidget(),
        ),
      );

      expect(find.text('Count: 0'), findsOneWidget);
    });

    testWidgets('autoWatch enables automatic reactivity', (tester) async {
      final controller = TestController();
      Levit.put(() => controller);

      await tester.pumpWidget(
        MaterialApp(
          home: AutoWatchLView(),
        ),
      );

      expect(find.text('Reactive: 0'), findsOneWidget);

      controller.reactiveCount.value = 42;
      await tester.pump();

      expect(find.text('Reactive: 42'), findsOneWidget);
    });

    testWidgets('throws if controller missing and no create', (tester) async {
      await tester.pumpWidget(const Directionality(
        textDirection: TextDirection.ltr,
        child: MissingView(),
      ));
      expect(tester.takeException(), anything);
    });

    testWidgets('permanent flag works', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PermanentLView(),
        ),
      );

      expect(find.text('Permanent: 0'), findsOneWidget);
    });
  });

  group('LStatefulView', () {
    testWidgets('provides controller access in state', (tester) async {
      Levit.put(() => TestController()..count = 77);

      await tester.pumpWidget(
        MaterialApp(
          home: TestLStatefulWidget(),
        ),
      );

      expect(find.text('Stateful: 77'), findsOneWidget);
    });

    testWidgets('creates controller if not registered via createController',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulWidgetWithCreate(),
        ),
      );

      expect(find.text('Created: 0'), findsOneWidget);
    });

    testWidgets('throws if controller missing and no create', (tester) async {
      await tester.pumpWidget(const Directionality(
        textDirection: TextDirection.ltr,
        child: MissingStatefulView(),
      ));
      expect(tester.takeException(), anything);
    });
  });

  group('LState lifecycle', () {
    testWidgets('onInit and onClose are called', (tester) async {
      final showWidget = ValueNotifier(true);
      bool initCalled = false;
      bool closeCalled = false;

      Levit.put(() => TestController());

      await tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder<bool>(
            valueListenable: showWidget,
            builder: (_, show, __) => show
                ? LifecycleStatefulWidget(
                    onInitCallback: () => initCalled = true,
                    onCloseCallback: () => closeCalled = true,
                  )
                : const Text('Gone'),
          ),
        ),
      );

      expect(initCalled, isTrue);
      expect(closeCalled, isFalse);

      showWidget.value = false;
      await tester.pump();

      expect(closeCalled, isTrue);
    });

    testWidgets('autoWatch true wraps build in LWatch', (tester) async {
      final controller = TestController();
      Levit.put(() => controller);

      await tester.pumpWidget(
        MaterialApp(
          home: AutoWatchStatefulWidget(),
        ),
      );

      expect(find.text('Stateful Reactive: 0'), findsOneWidget);

      controller.reactiveCount.value = 99;
      await tester.pump();

      expect(find.text('Stateful Reactive: 99'), findsOneWidget);
    });
  });
}

/// View that will throw because controller is missing.
class MissingView extends LView<TestController> {
  const MissingView({super.key});
  @override
  Widget buildContent(BuildContext context, TestController controller) {
    return Container();
  }
}

/// Stateful view that will throw because controller is missing.
class MissingStatefulView extends LStatefulView<TestController> {
  const MissingStatefulView({super.key});
  @override
  State<MissingStatefulView> createState() => _MissingStatefulViewState();
}

class _MissingStatefulViewState
    extends LState<MissingStatefulView, TestController> {
  @override
  Widget buildContent(BuildContext context) {
    controller;
    return Container();
  }
}
