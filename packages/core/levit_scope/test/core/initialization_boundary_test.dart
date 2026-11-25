import 'dart:async';
import 'package:levit_scope/levit_scope.dart';
import 'package:test/test.dart';
import 'cleanup_failure_acceptance_test.dart' show Progress;

class FactoryWork implements LevitDisposable, LevitDrainable {
  FactoryWork({this.failure});
  final Object? failure;
  final gate = Completer<void>();
  bool cancelled = false;
  bool closed = false;
  @override
  void requestCancel() {
    cancelled = true;
  }

  @override
  Future<void> drain() => gate.future;
  @override
  void dispose() {
    closed = true;
    if (failure case final error?) throw error;
  }
}

void main() {
  test('scope closure reports an admitted early-release failure', () async {
    final failure = StateError('release');
    final scope = LevitScope.root();
    scope.lazyPut(() => FactoryWork(failure: failure), isFactory: true);
    final work = scope.find<FactoryWork>();
    final releasing = scope.releaseFactoryInstance(work);
    final matchesFailure = throwsA(
      isA<LevitDisposalException>().having(
        (error) => error.failures.map((item) => item.error),
        'errors',
        contains(same(failure)),
      ),
    );
    final released = expectLater(releasing, matchesFailure);
    final closed = expectLater(scope.dispose(), matchesFailure);
    work.gate.complete();
    await released;
    await closed;
    expect(work.closed, isTrue);
  });

  test(
    'scope closure drains factory release awaited by external initialization',
    () async {
      final scope = LevitScope.root();
      scope.lazyPut(FactoryWork.new, isFactory: true);
      final work = scope.find<FactoryWork>();
      final init = scope.runInitialization<void>(() async {
        expect(await scope.releaseFactoryInstance(work), isTrue);
      });
      final closing = scope.dispose();
      await Future<void>.delayed(Duration.zero);
      expect(work.cancelled, isTrue);
      expect(work.closed, isFalse);
      work.gate.complete();
      await init;
      await closing;
      expect(work.closed, isTrue);
    },
  );
  test(
    'concurrent factory releases wait for initialization and drain their own work',
    () async {
      final middleware = Progress();
      LevitScope.addMiddleware(middleware);
      addTearDown(() => LevitScope.removeMiddleware(middleware));
      final scope = LevitScope.root();
      scope.lazyPut(FactoryWork.new, isFactory: true);
      final first = scope.find<FactoryWork>();
      final second = scope.find<FactoryWork>();
      final init = Completer<void>();
      middleware.registrations.single.trackInitialization(init.future);
      final a = scope.releaseFactoryInstance(first);
      final b = scope.releaseFactoryInstance(second);
      expect(first.cancelled, isFalse);
      init.complete();
      await Future<void>.delayed(Duration.zero);
      expect(first.cancelled, isTrue);
      expect(second.cancelled, isTrue);
      expect(first.closed, isFalse);
      first.gate.complete();
      expect(await a, isTrue);
      expect(second.closed, isFalse);
      second.gate.complete();
      expect(await b, isTrue);
      expect(scope.isRegistered<FactoryWork>(), isTrue);
      await scope.dispose();
    },
  );

  test(
    'external initialization blocks ancestor closure, preserves results and expires its context',
    () async {
      final parent = LevitScope.root();
      final child = parent.createScope('feature');
      final unrelated = LevitScope.root();
      late Zone initializedZone;
      final result = await child.runInitialization<int?>(() async {
        initializedZone = Zone.current;
        await Future<void>.value();
        expect(() => parent.dispose(), throwsStateError);
        await unrelated.dispose();
        return null;
      });
      expect(result, isNull);
      await initializedZone.run(parent.dispose);
      expect(child.isDisposed, isTrue);
    },
  );

  test(
    'synchronous and failed initialization release their admission',
    () async {
      final scope = LevitScope.root();
      expect(
        scope.runInitialization(() => scope.runInitialization(() => 7)),
        7,
      );
      expect(
        () => scope.runInitialization<void>(() => throw StateError('sync')),
        throwsStateError,
      );
      await expectLater(
        scope.runInitialization<void>(() async {
          throw StateError('async');
        }),
        throwsStateError,
      );
      await scope.dispose();
      expect(() => scope.runInitialization(() => 1), throwsStateError);
    },
  );

  test(
    'synchronous async-builder failure expires its execution guard',
    () async {
      final scope = LevitScope.root();
      scope.lazyPutAsync<int>(() => throw StateError('build'));
      await expectLater(scope.findAsync<int>(), throwsStateError);
      await scope.dispose();
    },
  );

  for (final factory in [false, true]) {
    test(
      'async builder rejects closing its owning scope, factory=$factory',
      () async {
        final scope = LevitScope.root();
        var rejected = false;
        scope.lazyPutAsync(() async {
          await Future<void>.value();
          await expectLater(scope.delete<int>(), throwsStateError);
          await expectLater(scope.reset(), throwsStateError);
          expect(scope.isRegistered<int>(), isTrue);
          try {
            scope.dispose().ignore();
          } on StateError {
            rejected = true;
          }
          return 42;
        }, isFactory: factory);
        final value = await scope.findAsync<int>().then<int?>(
          (value) => value,
          onError: (Object _) => null,
        );
        await scope.dispose();
        expect(rejected, isTrue);
        expect(value, 42);
      },
    );
  }
}
