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

  testWidgets(
      'unnamed LRouteScope without route settings name uses unique fallback',
      (tester) async {
    final logs = <String>[];
    late String capturedScopeName;

    await runZoned(() async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(splashFactory: NoSplash.splashFactory),
          home: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => LRouteScope(
                        dependencyFactory: (scope) {
                          capturedScopeName = scope.name;
                        },
                        child: const Text('route-fallback'),
                      ),
                    ),
                  );
                },
                child: const Text('open'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    },
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) => logs.add(line),
        ));

    expect(find.text('route-fallback'), findsOneWidget);
    expect(capturedScopeName.startsWith('LRouteScope@'), isTrue);
    expect(
      logs.any((l) => l.contains('has the same name as ancestor')),
      isFalse,
    );
  });

  testWidgets(
      'unnamed LAsyncRouteScope without route settings name uses unique fallback',
      (tester) async {
    final logs = <String>[];
    late String capturedScopeName;

    await runZoned(() async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(splashFactory: NoSplash.splashFactory),
          home: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => LAsyncRouteScope(
                        dependencyFactory: (scope) async {
                          capturedScopeName = scope.name;
                        },
                        child: const Text('async-route-fallback'),
                      ),
                    ),
                  );
                },
                child: const Text('open'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    },
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) => logs.add(line),
        ));

    expect(find.text('async-route-fallback'), findsOneWidget);
    expect(capturedScopeName.startsWith('LAsyncRouteScope@'), isTrue);
    expect(
      logs.any((l) => l.contains('has the same name as ancestor')),
      isFalse,
    );
  });
}
