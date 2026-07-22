import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter_core/levit_flutter_core.dart';

class _ShellController extends LevitController {}

class _PageController extends LevitController {}

class _ShellPage extends LScopedView<_ShellController> {
  const _ShellPage({required this.child});

  final Widget child;

  @override
  void onConfigScope(LevitScope scope) {
    scope.put(() => _ShellController());
  }

  @override
  Widget buildView(BuildContext context, _ShellController controller) => child;
}

class _FeaturePage extends LScopedView<_PageController> {
  const _FeaturePage();

  @override
  void onConfigScope(LevitScope scope) {
    scope.put(() => _PageController());
  }

  @override
  Widget buildView(BuildContext context, _PageController controller) {
    return const Text('feature');
  }
}

void main() {
  testWidgets('nested unnamed LScope does not warn about duplicate names',
      (tester) async {
    final logs = <String>[];

    await runZoned(() async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LScope(
            child: LScope(
              child: Text('nested'),
            ),
          ),
        ),
      );
    },
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) => logs.add(line),
        ));

    expect(
      logs.any((l) => l.contains('has the same name as ancestor')),
      isFalse,
    );
    expect(find.text('nested'), findsOneWidget);
  });

  testWidgets(
      'nested unnamed LScopedView subclasses do not warn about duplicate names',
      (tester) async {
    final logs = <String>[];

    await runZoned(() async {
      await tester.pumpWidget(
        const MaterialApp(
          home: _ShellPage(
            child: _FeaturePage(),
          ),
        ),
      );
    },
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) => logs.add(line),
        ));

    expect(
      logs.any((l) => l.contains('has the same name as ancestor')),
      isFalse,
    );
    expect(find.text('feature'), findsOneWidget);
  });

  testWidgets('explicit duplicate scope names still warn', (tester) async {
    final logs = <String>[];

    await runZoned(() async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LScope(
            name: 'Shared',
            child: LScope(
              name: 'Shared',
              child: Text('dup'),
            ),
          ),
        ),
      );
    },
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) => logs.add(line),
        ));

    expect(
      logs.any((l) => l.contains('Child scope "Shared" has the same name')),
      isTrue,
    );
    expect(find.text('dup'), findsOneWidget);
  });
}
