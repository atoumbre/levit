import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter_core/levit_flutter_core.dart';

import '../helpers.dart';

final _openDetailsKey = UniqueKey();
final _popDetailsKey = UniqueKey();
final _replaceRouteKey = UniqueKey();
final _openAsyncDetailsKey = UniqueKey();
final _popAsyncDetailsKey = UniqueKey();
final _replaceAsyncRouteKey = UniqueKey();

void main() {
  setUp(() {
    Levit.reset(force: true);
  });

  group('LRouteScope', () {
    testWidgets('put registers controller and exposes route bindings',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(splashFactory: NoSplash.splashFactory),
          routes: {
            '/': (_) => LRouteScope.put(
                  () => TestController()..count = 7,
                  child: Builder(
                    builder: (context) {
                      final controller = context.levit.find<TestController>();
                      final route = LRouteScope.routeOf(context);
                      final visibility = LRouteScope.visibilityOf(context)!;

                      return Column(
                        children: [
                          Text('count:${controller.count}'),
                          Text('route:${route?.settings.name}'),
                          LBuilder<LRouteVisibility>(
                            visibility,
                            (value) => Text('visibility:${value.name}'),
                          ),
                        ],
                      );
                    },
                  ),
                ),
          },
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('count:7'), findsOneWidget);
      expect(find.text('route:/'), findsOneWidget);
      expect(find.text('visibility:current'), findsOneWidget);
    });

    testWidgets('lazyPut registers controller and exposes snapshot visibility',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(splashFactory: NoSplash.splashFactory),
          home: LRouteScope.lazyPut<TestController>(
            () => TestController()..count = 5,
            child: Builder(
              builder: (context) {
                final controller = context.levit.find<TestController>();
                final route = LRouteScope.routeOf(context, listen: true);
                final visibility =
                    LRouteScope.visibilityValueOf(context, listen: true);

                return Column(
                  children: [
                    Text('count:${controller.count}'),
                    Text('has-route:${route != null}'),
                    Text('snapshot:${visibility.name}'),
                  ],
                );
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('count:5'), findsOneWidget);
      expect(find.text('has-route:true'), findsOneWidget);
      expect(find.text('snapshot:current'), findsOneWidget);
    });

    testWidgets(
        'lazyPutAsync registers async controller and exposes snapshot visibility',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(splashFactory: NoSplash.splashFactory),
          home: LRouteScope.lazyPutAsync<TestController>(
            () async {
              await Future<void>.delayed(Duration.zero);
              return TestController()..count = 11;
            },
            child: LAsyncView<TestController>(
              loading: (context) {
                final route = LRouteScope.routeOf(context, listen: true);
                final visibility =
                    LRouteScope.visibilityValueOf(context, listen: true);
                return Text('loading:${visibility.name}:${route != null}');
              },
              builder: (context, controller) {
                final route = LRouteScope.routeOf(context, listen: true);
                final visibility =
                    LRouteScope.visibilityValueOf(context, listen: true);
                return Text(
                    'count:${controller.count}:${visibility.name}:${route != null}');
              },
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('loading:current:true'), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.text('count:11:current:true'), findsOneWidget);
    });

    testWidgets('updates visibility when a route is covered and uncovered',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(splashFactory: NoSplash.splashFactory),
          routes: {
            '/': (_) => const _HomeRoutePage(),
            '/details': (_) => const _DetailsRoutePage(),
          },
        ),
      );

      expect(find.text('home:current'), findsOneWidget);

      await tester.tap(find.byKey(_openDetailsKey));
      await tester.pumpAndSettle();

      expect(find.text('details:current'), findsOneWidget);
      expect(find.text('home:covered', skipOffstage: false), findsOneWidget);

      await tester.tap(find.byKey(_popDetailsKey));
      await tester.pumpAndSettle();

      expect(find.text('home:current'), findsOneWidget);
      expect(find.text('details:current'), findsNothing);
    });

    testWidgets('disposes local scope when the route is replaced',
        (tester) async {
      var closeCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(splashFactory: NoSplash.splashFactory),
          routes: {
            '/': (_) => LRouteScope(
                  dependencyFactory: (scope) {
                    scope.put<_ClosingRouteController>(
                      () => _ClosingRouteController(
                        onClosed: () => closeCount++,
                      ),
                    );
                  },
                  child: Builder(
                    builder: (context) {
                      return Scaffold(
                        body: const Text('home'),
                        floatingActionButton: FloatingActionButton(
                          key: _replaceRouteKey,
                          onPressed: () {
                            Navigator.of(context).pushReplacementNamed('/next');
                          },
                        ),
                      );
                    },
                  ),
                ),
            '/next': (_) => const Scaffold(body: Text('next')),
          },
        ),
      );

      expect(closeCount, 0);

      await tester.tap(find.byKey(_replaceRouteKey));
      await tester.pumpAndSettle();

      expect(find.text('next'), findsOneWidget);
      expect(closeCount, 1);
    });
  });

  group('LAsyncRouteScope', () {
    testWidgets('initializes async dependencies and exposes route bindings',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(splashFactory: NoSplash.splashFactory),
          routes: {
            '/': (_) => LAsyncRouteScope(
                  dependencyFactory: (scope) async {
                    await Future<void>.delayed(Duration.zero);
                    scope
                        .put<TestController>(() => TestController()..count = 9);
                  },
                  loading: (context) {
                    final visibility = LAsyncRouteScope.visibilityOf(context)!;
                    return LBuilder<LRouteVisibility>(
                      visibility,
                      (value) => Text('loading:${value.name}'),
                    );
                  },
                  child: Builder(
                    builder: (context) {
                      final controller = context.levit.find<TestController>();
                      final route = LAsyncRouteScope.routeOf(context);
                      final visibility =
                          LAsyncRouteScope.visibilityOf(context)!;

                      return Column(
                        children: [
                          Text('count:${controller.count}'),
                          Text('route:${route?.settings.name}'),
                          LBuilder<LRouteVisibility>(
                            visibility,
                            (value) => Text('visibility:${value.name}'),
                          ),
                        ],
                      );
                    },
                  ),
                ),
          },
        ),
      );

      await tester.pump();
      expect(find.text('loading:current'), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.text('count:9'), findsOneWidget);
      expect(find.text('route:/'), findsOneWidget);
      expect(find.text('visibility:current'), findsOneWidget);
    });

    testWidgets('visibilityValueOf returns snapshots inside and outside scope',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(splashFactory: NoSplash.splashFactory),
          home: Scaffold(
            body: Column(
              children: [
                Builder(
                  builder: (context) => Text(
                    'outside:${LAsyncRouteScope.visibilityValueOf(context).name}',
                  ),
                ),
                LAsyncRouteScope(
                  dependencyFactory: (_) async {
                    await Future<void>.delayed(Duration.zero);
                  },
                  loading: (context) => Text(
                    'loading:${LAsyncRouteScope.visibilityValueOf(context, listen: true).name}',
                  ),
                  child: Builder(
                    builder: (context) => Text(
                      'inside:${LAsyncRouteScope.visibilityValueOf(context, listen: true).name}',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('outside:inactive'), findsOneWidget);

      await tester.pump();
      expect(find.text('loading:current'), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.text('inside:current'), findsOneWidget);
    });

    testWidgets(
        'updates visibility when an async route is covered and uncovered',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(splashFactory: NoSplash.splashFactory),
          routes: {
            '/': (_) => const _AsyncHomeRoutePage(),
            '/details': (_) => const _AsyncDetailsRoutePage(),
          },
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('async-home:current'), findsOneWidget);

      await tester.tap(find.byKey(_openAsyncDetailsKey));
      await tester.pumpAndSettle();

      expect(find.text('async-details:current'), findsOneWidget);
      expect(
        find.text('async-home:covered', skipOffstage: false),
        findsOneWidget,
      );

      await tester.tap(find.byKey(_popAsyncDetailsKey));
      await tester.pumpAndSettle();

      expect(find.text('async-home:current'), findsOneWidget);
      expect(find.text('async-details:current'), findsNothing);
    });

    testWidgets('disposes local scope when the async route is replaced',
        (tester) async {
      var closeCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(splashFactory: NoSplash.splashFactory),
          routes: {
            '/': (_) => LAsyncRouteScope(
                  dependencyFactory: (scope) async {
                    scope.put<_ClosingRouteController>(
                      () => _ClosingRouteController(
                        onClosed: () => closeCount++,
                      ),
                    );
                  },
                  child: Builder(
                    builder: (context) {
                      return Scaffold(
                        body: const Text('async-home'),
                        floatingActionButton: FloatingActionButton(
                          key: _replaceAsyncRouteKey,
                          onPressed: () {
                            Navigator.of(context).pushReplacementNamed('/next');
                          },
                        ),
                      );
                    },
                  ),
                ),
            '/next': (_) => const Scaffold(body: Text('next')),
          },
        ),
      );

      await tester.pumpAndSettle();
      expect(closeCount, 0);

      await tester.tap(find.byKey(_replaceAsyncRouteKey));
      await tester.pumpAndSettle();

      expect(find.text('next'), findsOneWidget);
      expect(closeCount, 1);
    });
  });
}

class _ClosingRouteController extends LevitController {
  final VoidCallback onClosed;

  _ClosingRouteController({required this.onClosed});

  @override
  void onClose() {
    onClosed();
    super.onClose();
  }
}

class _HomeRoutePage extends StatelessWidget {
  const _HomeRoutePage();

  @override
  Widget build(BuildContext context) {
    return LRouteScope.put(
      () => TestController(),
      child: Scaffold(
        body: Builder(
          builder: (context) {
            final visibility = LRouteScope.visibilityOf(context)!;
            return Center(
              child: LBuilder<LRouteVisibility>(
                visibility,
                (value) => Text('home:${value.name}'),
              ),
            );
          },
        ),
        floatingActionButton: FloatingActionButton(
          key: _openDetailsKey,
          onPressed: () {
            Navigator.of(context).pushNamed('/details');
          },
        ),
      ),
    );
  }
}

class _DetailsRoutePage extends StatelessWidget {
  const _DetailsRoutePage();

  @override
  Widget build(BuildContext context) {
    return LRouteScope(
      child: Scaffold(
        body: Builder(
          builder: (context) {
            final visibility = LRouteScope.visibilityOf(context)!;
            return Center(
              child: LBuilder<LRouteVisibility>(
                visibility,
                (value) => Text('details:${value.name}'),
              ),
            );
          },
        ),
        floatingActionButton: FloatingActionButton(
          key: _popDetailsKey,
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }
}

class _AsyncHomeRoutePage extends StatelessWidget {
  const _AsyncHomeRoutePage();

  @override
  Widget build(BuildContext context) {
    return LAsyncRouteScope(
      dependencyFactory: (_) async {},
      child: Scaffold(
        body: Builder(
          builder: (context) {
            final visibility = LAsyncRouteScope.visibilityOf(context)!;
            return Center(
              child: LBuilder<LRouteVisibility>(
                visibility,
                (value) => Text('async-home:${value.name}'),
              ),
            );
          },
        ),
        floatingActionButton: FloatingActionButton(
          key: _openAsyncDetailsKey,
          onPressed: () {
            Navigator.of(context).pushNamed('/details');
          },
        ),
      ),
    );
  }
}

class _AsyncDetailsRoutePage extends StatelessWidget {
  const _AsyncDetailsRoutePage();

  @override
  Widget build(BuildContext context) {
    return LAsyncRouteScope(
      dependencyFactory: (_) async {},
      child: Scaffold(
        body: Builder(
          builder: (context) {
            final visibility = LAsyncRouteScope.visibilityOf(context)!;
            return Center(
              child: LBuilder<LRouteVisibility>(
                visibility,
                (value) => Text('async-details:${value.name}'),
              ),
            );
          },
        ),
        floatingActionButton: FloatingActionButton(
          key: _popAsyncDetailsKey,
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }
}
