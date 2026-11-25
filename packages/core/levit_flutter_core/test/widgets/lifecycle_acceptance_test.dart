import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_flutter_core/levit_flutter_core.dart';

class Resource extends LevitScopeDisposable {
  Resource(this.close);
  final FutureOr<void> Function() close;
  @override
  FutureOr<void> onClose() => close();
}

class FailingListen extends LxVar<int> {
  FailingListen() : super(0);
  bool fail = true;
  @override
  void addListener(void Function() listener) {
    if (fail) throw StateError('subscription');
    super.addListener(listener);
  }
}

void main() {
  test(
    'widget scope initialization cannot close itself or its owning parent',
    () async {
      final parent = LevitScope.root();
      final lifecycle = LevitScopeLifecycleController();
      await lifecycle.replace(
        parent: parent,
        name: 'session',
        initialize: (scope) async {
          await Future<void>.value();
          expect(() => scope.dispose(), throwsStateError);
          expect(() => parent.dispose(), throwsStateError);
          await expectLater(lifecycle.close(), throwsStateError);
        },
      );
      expect(lifecycle.isReady, isTrue);
      await lifecycle.close();
      await parent.dispose();
    },
  );
  test(
    'close requested by the idle notification still waits for resource cleanup',
    () async {
      final parent = LevitScope.root();
      final lifecycle = LevitScopeLifecycleController();
      final gate = Completer<void>();
      var requested = false;
      var closed = false;
      lifecycle.addListener(() {
        if (!requested && lifecycle.isReady && !lifecycle.isLoading) {
          requested = true;
          unawaited(lifecycle.close().then((_) => closed = true));
        }
      });
      await lifecycle.replace(
        parent: parent,
        name: 'session',
        initialize: (scope) {
          scope.put(() => Resource(() => gate.future));
        },
      );
      await Future<void>.delayed(Duration.zero);
      final premature = closed;
      gate.complete();
      await lifecycle.close();
      await parent.dispose();
      expect(premature, isFalse);
      expect(closed, isTrue);
    },
  );

  test(
    'reentrant replacement keeps the old initializer tracked by its scope',
    () async {
      final parent = LevitScope.root();
      final lifecycle = LevitScopeLifecycleController();
      final gate = Completer<void>();
      var dependencyClosed = false;
      var nextStarted = false;
      late LevitScope original;
      final first = lifecycle.replace(
        parent: parent,
        name: 'first',
        initialize: (scope) {
          original = scope;
          scope.put(
            () => Resource(() {
              dependencyClosed = true;
            }),
          );
          unawaited(
            lifecycle.replace(
              parent: parent,
              name: 'next',
              initialize: (_) {
                nextStarted = true;
              },
            ),
          );
          return gate.future;
        },
      );
      await Future<void>.delayed(Duration.zero);
      final before = (
        dependencyClosed,
        nextStarted,
        original.describe().pendingInitializations,
      );
      gate.complete();
      await first;
      await lifecycle.close();
      await parent.dispose();
      expect(before, (false, false, 1));
      expect(nextStarted, isTrue);
    },
  );

  test(
    'completion listener replacement is serialized and cleanup failure is retained',
    () async {
      final parent = LevitScope.root();
      final lifecycle = LevitScopeLifecycleController();
      expect(() => lifecycle.retry(), throwsStateError);
      var requested = false;
      var initialized = 0;
      void changed() {
        if (!requested && lifecycle.isReady) {
          requested = true;
          unawaited(
            lifecycle.replace(
              parent: parent,
              name: 'second',
              initialize: (_) {
                initialized++;
              },
            ),
          );
        }
      }

      lifecycle.addListener(changed);
      await lifecycle.replace(
        parent: parent,
        name: 'first',
        initialize: (scope) {
          initialized++;
          scope.put(() => Resource(() => throw StateError('cleanup')));
        },
      );
      expect(initialized, 1);
      expect(lifecycle.error, isA<LevitDisposalException>());
      expect(lifecycle.stackTrace, isNotNull);
      expect(lifecycle.isLoading, isFalse);
      await lifecycle.retry();
      expect(initialized, 2);
      lifecycle.removeListener(changed);
      await lifecycle.close();
      await parent.dispose();
    },
  );

  testWidgets('unmount reports failed cleanup and awaited close preserves it', (
    tester,
  ) async {
    final lifecycle = LevitScopeLifecycleController();
    final reported = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = reported.add;
    try {
      await tester.pumpWidget(
        LScope(
          lifecycle: lifecycle,
          configure: (scope) {
            scope.put(() => Resource(() => throw StateError('closing')));
          },
          child: const SizedBox(),
        ),
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await expectLater(
        lifecycle.close(),
        throwsA(isA<LevitDisposalException>()),
      );
      await lifecycle.closed;
      expect(reported.single.library, 'levit_flutter_core');
      expect(lifecycle.isLoading, isFalse);
    } finally {
      FlutterError.onError = previous;
    }
  });

  for (final asynchronous in [false, true]) {
    testWidgets(
      'lifecycle handle cannot change while mounted ($asynchronous)',
      (tester) async {
        final first = LevitScopeLifecycleController();
        final next = LevitScopeLifecycleController();
        Widget view(LevitScopeLifecycleController lifecycle) => asynchronous
            ? LAsyncScope(
                lifecycle: lifecycle,
                configure: (_) async {},
                child: const SizedBox(),
              )
            : LScope(lifecycle: lifecycle, child: const SizedBox());
        await tester.pumpWidget(view(first));
        await tester.pumpAndSettle();
        await tester.pumpWidget(view(next));
        expect(tester.takeException(), isStateError);
        await tester.pumpWidget(const SizedBox());
        await first.close();
        await next.close();
      },
    );

    testWidgets(
      'reparented consuming view resolves its new scope ($asynchronous)',
      (tester) async {
        final key = GlobalKey();
        final left = LevitScopeLifecycleController();
        final right = LevitScopeLifecycleController();
        var reads = 0;
        final Widget view = asynchronous
            ? LAsyncView<int>(
                key: key,
                builder: (context, value) {
                  reads++;
                  return Text('$value');
                },
              )
            : LView<int>(
                key: key,
                builder: (context, value) {
                  reads++;
                  return Text('$value');
                },
              );
        Widget tree(bool onLeft) => Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            children: [
              LScope(
                lifecycle: left,
                configure: (scope) => scope.put<int>(() => 1),
                child: onLeft ? view : const SizedBox(),
              ),
              LScope(
                lifecycle: right,
                configure: (scope) => scope.put<int>(() => 2),
                child: onLeft ? const SizedBox() : view,
              ),
            ],
          ),
        );
        await tester.pumpWidget(tree(true));
        await tester.pumpAndSettle();
        expect(find.text('1'), findsOneWidget);
        await tester.pumpWidget(tree(false));
        await tester.pumpAndSettle();
        expect(find.text('2'), findsOneWidget);
        expect(reads, greaterThanOrEqualTo(2));
        final description = tester.element(find.text('2')).levit.describe();
        expect(description.registrations.single.type, 'int');
        await tester.pumpWidget(const SizedBox());
        await left.close();
        await right.close();
      },
    );
  }

  test(
    'failed adapter subscription rolls back listeners and can retry',
    () async {
      final source = FailingListen();
      final adapter = source.asValueListenable();
      var updates = 0;
      void changed() {
        updates++;
      }

      expect(() => adapter.addListener(changed), throwsStateError);
      source.fail = false;
      adapter.addListener(changed);
      source.value = 1;
      expect(updates, 1);
      adapter.dispose();
      expect(source.hasListener, isFalse);
      await source.close();
    },
  );
}
