import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter_core/levit_flutter_core.dart';

class _TestController extends LevitController {
  final String label;
  final VoidCallback? onClosed;

  _TestController(this.label, {this.onClosed});

  @override
  void onClose() {
    onClosed?.call();
    super.onClose();
  }
}

void main() {
  testWidgets('LScope rebinds to new parent scope on re-parent',
      (tester) async {
    Widget buildStage(String label) {
      return MaterialApp(
        home: LScope(
          name: 'parent_$label',
          dependencyFactory: (scope) => scope.put(() => _TestController(label)),
          child: LScope(
            name: 'child',
            child: Builder(
              builder: (context) {
                final controller = context.levit.find<_TestController>();
                return Text(controller.label);
              },
            ),
          ),
        ),
      );
    }

    await tester.pumpWidget(buildStage('A'));
    expect(find.text('A'), findsOneWidget);

    await tester.pumpWidget(buildStage('B'));
    expect(find.text('B'), findsOneWidget);
  });

  testWidgets('LScope disposes scope on dependencyFactory error',
      (tester) async {
    int closed = 0;

    await tester.pumpWidget(MaterialApp(
      home: LScope(
        dependencyFactory: (scope) {
          scope.put(() => _TestController('x', onClosed: () => closed++));
          throw StateError('boom');
        },
        child: const SizedBox.shrink(),
      ),
    ));

    final error = tester.takeException();
    expect(error, isA<StateError>());
    expect(closed, 1);
  });

  testWidgets('LAsyncScope disposes scope on dependencyFactory error',
      (tester) async {
    int closed = 0;

    await tester.pumpWidget(MaterialApp(
      home: LAsyncScope(
        dependencyFactory: (scope) async {
          scope.put(() => _TestController('x', onClosed: () => closed++));
          await Future<void>.delayed(Duration.zero);
          throw StateError('boom');
        },
        child: const SizedBox.shrink(),
      ),
    ));

    await tester.pumpAndSettle();

    expect(find.textContaining('Scope Initialization Error'), findsOneWidget);
    expect(closed, 1);
  });

  testWidgets(
      'LAsyncScope + LView autoWatch:false bridges scope for Levit.find',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: LAsyncScope(
        dependencyFactory: (scope) async {
          scope.put(() => _TestController('local'));
        },
        child: LView<_TestController>(
          resolver: (context) => context.levit.find<_TestController>(),
          autoWatch: false,
          builder: (context, controller) {
            final fromGlobal = Levit.find<_TestController>();
            return Text(fromGlobal.label);
          },
        ),
      ),
    ));

    await tester.pumpAndSettle();
    expect(find.text('local'), findsOneWidget);
  });

  testWidgets('LAsyncScope rebinds to new parent scope on re-parent',
      (tester) async {
    Widget buildStage(String label) {
      return MaterialApp(
        home: LScope(
          name: 'parent_$label',
          dependencyFactory: (scope) => scope.put(() => _TestController(label)),
          child: LAsyncScope(
            dependencyFactory: (_) async {},
            child: Builder(
              builder: (context) {
                final controller = context.levit.find<_TestController>();
                return Text(controller.label);
              },
            ),
          ),
        ),
      );
    }

    await tester.pumpWidget(buildStage('A'));
    await tester.pumpAndSettle();
    expect(find.text('A'), findsOneWidget);

    await tester.pumpWidget(buildStage('B'));
    await tester.pumpAndSettle();
    expect(find.text('B'), findsOneWidget);
  });
}
