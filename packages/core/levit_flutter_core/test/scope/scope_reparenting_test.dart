import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter_core/levit_flutter_core.dart';

class _TestController extends LevitController {
  final String label;
  final VoidCallback? onClosed;

  _TestController(this.label, {this.onClosed});

  @override
  Future<void> onClose() async {
    onClosed?.call();
    await super.onClose();
  }
}

Widget _buildMovedChildScope({
  required bool moved,
  required GlobalKey key,
  required Widget Function(Key key) buildChild,
}) {
  return MaterialApp(
    home: Row(
      children: [
        Expanded(
          child: LScope(
            name: 'left_parent',
            configure: (scope) =>
                scope.put<_TestController>(() => _TestController('left')),
            child: moved ? const SizedBox.shrink() : buildChild(key),
          ),
        ),
        Expanded(
          child: LScope(
            name: 'right_parent',
            configure: (scope) =>
                scope.put<_TestController>(() => _TestController('right')),
            child: moved ? buildChild(key) : const SizedBox.shrink(),
          ),
        ),
      ],
    ),
  );
}

void main() {
  testWidgets('LScope rebinds to new parent scope on re-parent', (
    tester,
  ) async {
    Widget buildStage(String label) {
      return MaterialApp(
        home: LScope(
          name: 'parent_$label',
          configure: (scope) =>
              scope.put<_TestController>(() => _TestController(label)),
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
    await tester.pumpAndSettle();
    expect(find.text('B'), findsOneWidget);
  });

  testWidgets('LScope disposes scope on dependencyFactory error', (
    tester,
  ) async {
    int closed = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: LScope(
          configure: (scope) {
            scope.put(() => _TestController('x', onClosed: () => closed++));
            throw StateError('boom');
          },
          child: const SizedBox.shrink(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.textContaining('Scope error: Bad state: boom'), findsOneWidget);
    expect(closed, 1);
  });

  testWidgets('LAsyncScope disposes scope on dependencyFactory error', (
    tester,
  ) async {
    int closed = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: LAsyncScope(
          configure: (scope) async {
            scope.put(() => _TestController('x', onClosed: () => closed++));
            await Future<void>.delayed(Duration.zero);
            throw StateError('boom');
          },
          child: const SizedBox.shrink(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.textContaining('Scope error:'), findsOneWidget);
    expect(closed, 1);
  });

  testWidgets(
    'LAsyncScope + LView autoWatch:false bridges scope for Levit.find',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LAsyncScope(
            configure: (scope) async {
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
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('local'), findsOneWidget);
    },
  );

  testWidgets('LAsyncScope rebinds to new parent scope on re-parent', (
    tester,
  ) async {
    Widget buildStage(String label) {
      return MaterialApp(
        home: LScope(
          name: 'parent_$label',
          configure: (scope) =>
              scope.put<_TestController>(() => _TestController(label)),
          child: LAsyncScope(
            configure: (_) async {},
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
    await tester.pumpAndSettle();
    expect(find.text('B'), findsOneWidget);
  });

  testWidgets('LScope rebinds when keyed child scope moves across parents', (
    tester,
  ) async {
    final childKey = GlobalKey();

    Widget buildChild(Key key) {
      return LScope(
        key: key,
        name: 'moved_child',
        child: Builder(
          builder: (context) {
            final controller = context.levit.find<_TestController>();
            return Text(controller.label);
          },
        ),
      );
    }

    await tester.pumpWidget(
      _buildMovedChildScope(
        moved: false,
        key: childKey,
        buildChild: buildChild,
      ),
    );
    expect(find.text('left'), findsOneWidget);

    await tester.pumpWidget(
      _buildMovedChildScope(moved: true, key: childKey, buildChild: buildChild),
    );
    await tester.pump();
    expect(find.text('right'), findsOneWidget);
  });

  testWidgets(
    'LAsyncScope rebinds when keyed child scope moves across parents',
    (tester) async {
      final childKey = GlobalKey();

      Widget buildChild(Key key) {
        return LAsyncScope(
          key: key,
          configure: (_) async {},
          child: Builder(
            builder: (context) {
              final controller = context.levit.find<_TestController>();
              return Text(controller.label);
            },
          ),
        );
      }

      await tester.pumpWidget(
        _buildMovedChildScope(
          moved: false,
          key: childKey,
          buildChild: buildChild,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('left'), findsOneWidget);

      await tester.pumpWidget(
        _buildMovedChildScope(
          moved: true,
          key: childKey,
          buildChild: buildChild,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('right'), findsOneWidget);
    },
  );
}
