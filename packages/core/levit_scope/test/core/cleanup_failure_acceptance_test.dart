import 'dart:async';
import 'dart:convert';
import 'package:levit_scope/levit_scope.dart';
import 'package:test/test.dart';
import 'package:levit_scope/spi.dart';

class Work extends LevitScopeDisposable
    implements LevitDrainable, LevitExecutionBoundary {
  Work(
    this.events, {
    this.name = 'work',
    this.cancelError,
    this.drainError,
    this.closeError,
    this.onDrain,
    this.boundary,
  });
  final List<String> events;
  final String name;
  final Object? cancelError, drainError, closeError;
  final Future<void> Function()? onDrain;
  final void Function()? boundary;
  @override
  void assertCanDispose() => boundary?.call();
  @override
  void requestCancel() {
    events.add('cancel:$name');
    if (cancelError != null) throw cancelError!;
  }

  @override
  Future<void> drain() async {
    events.add('drain:$name');
    await onDrain?.call();
    if (drainError != null) throw drainError!;
  }

  @override
  void onClose() {
    events.add('close:$name');
    if (closeError != null) throw closeError!;
  }
}

class Progress extends LevitScopeMiddleware
    implements LevitScopeProgressObserver {
  final descriptions = <LevitScopeDescription>[];
  final registrations = <LevitDependency>[];
  bool fail = false;
  @override
  void onScopeProgress(LevitScopeDescription value) {
    descriptions.add(value);
    if (fail) throw StateError('observer failed');
  }

  @override
  void onDependencyRegister(
    int scopeId,
    String scopeName,
    String key,
    LevitDependency info, {
    required String source,
    int? parentScopeId,
  }) => registrations.add(info);
}

class _CloseCallback extends LevitScopeDisposable {
  _CloseCallback(this.close);
  final FutureOr<void> Function() close;
  @override
  FutureOr<void> onClose() => close();
}

class _FailingCleanupMiddleware extends LevitScopeMiddleware {
  final deletionErrors = <Object>[];
  final disposalError = StateError('scope disposal observer');

  @override
  void onDependencyDelete(
    int scopeId,
    String scopeName,
    String key,
    LevitDependency info, {
    required String source,
    int? parentScopeId,
  }) {
    final error = StateError('delete observer: $key');
    deletionErrors.add(error);
    throw error;
  }

  @override
  void onScopeDispose(int scopeId, String scopeName) => throw disposalError;
}

void main() {
  for (final asynchronous in [false, true]) {
    test(
      'middleware failures preserve all cleanup and errors (async: $asynchronous)',
      () async {
        final observers = List.generate(2, (_) => _FailingCleanupMiddleware());
        for (final observer in observers) {
          LevitScope.addMiddleware(observer);
          addTearDown(() => LevitScope.removeMiddleware(observer));
        }
        final scope = LevitScope.root();
        final events = <String>[];
        final gate = Completer<void>();
        final closeError = StateError('resource cleanup');
        scope.put(
          () => _CloseCallback(() {
            events.add('older');
            throw closeError;
          }),
        );
        scope.put(
          () => _CloseCallback(() {
            events.add('newer');
            if (asynchronous) return gate.future;
          }),
          tag: 'newer',
        );
        final closing = scope.dispose();
        final checked = expectLater(
          closing,
          throwsA(
            isA<LevitDisposalException>().having(
              (error) => error.failures.map((failure) => failure.error),
              'all middleware and resource failures',
              unorderedEquals([
                for (final observer in observers) ...observer.deletionErrors,
                closeError,
                for (final observer in observers) observer.disposalError,
              ]),
            ),
          ),
        );
        for (final observer in observers) {
          expect(observer.deletionErrors, hasLength(2));
        }
        if (asynchronous) {
          expect(events, ['newer']);
          expect(scope.isDisposed, isFalse);
          gate.complete();
        }
        await checked;
        await scope.disposed;
        expect(events, ['newer', 'older']);
        expect(scope.isDisposed, isTrue);
        expect(scope.describe().registrations, isEmpty);
        expect(scope.dispose(), same(closing));
      },
    );
  }

  for (final reset in [false, true]) {
    test(
      'deletion middleware cannot skip resource release (reset: $reset)',
      () async {
        final observer = _FailingCleanupMiddleware();
        LevitScope.addMiddleware(observer);
        addTearDown(() => LevitScope.removeMiddleware(observer));
        final scope = LevitScope.root();
        final gate = Completer<void>();
        var closed = false;
        scope.put(
          () => _CloseCallback(() async {
            await gate.future;
            closed = true;
          }),
        );
        final operation = reset
            ? scope.reset()
            : scope.delete<_CloseCallback>();
        final checked = expectLater(
          operation,
          throwsA(
            isA<LevitDisposalException>().having(
              (error) => error.failures.map((failure) => failure.error),
              'deletion failure',
              observer.deletionErrors,
            ),
          ),
        );
        await Future<void>.delayed(Duration.zero);
        expect(closed, isFalse);
        expect(scope.isRegistered<_CloseCallback>(), isFalse);
        gate.complete();
        await checked;
        expect(closed, isTrue);
        expect(scope.describe().registrations, isEmpty);
        LevitScope.removeMiddleware(observer);
        await scope.dispose();
      },
    );
  }

  test(
    'alias deletion reports middleware failure without owning the instance',
    () async {
      final observer = _FailingCleanupMiddleware();
      LevitScope.addMiddleware(observer);
      addTearDown(() => LevitScope.removeMiddleware(observer));
      final scope = LevitScope.root();
      var closes = 0;
      scope.put(
        () => _CloseCallback(() {
          closes++;
        }),
      );
      scope.bindExisting<Object, _CloseCallback>();
      await expectLater(
        scope.delete<Object>(),
        throwsA(isA<LevitDisposalException>()),
      );
      expect(scope.isRegistered<Object>(), isFalse);
      expect(scope.isRegistered<_CloseCallback>(), isTrue);
      expect(closes, 0);
      LevitScope.removeMiddleware(observer);
      await scope.dispose();
      expect(closes, 1);
    },
  );

  test(
    'scope aggregates cancellation, drain and close failures after dependencies release',
    () async {
      final events = <String>[];
      final scope = LevitScope.root();
      final dependency = scope.put(() => Work(events, name: 'dependency'));
      final cancelled = StateError('cancel');
      final drained = StateError('drain');
      final closed = StateError('close');
      final gate = Completer<void>();
      scope.put(
        () => Work(
          events,
          name: 'producer',
          cancelError: cancelled,
          drainError: drained,
          closeError: closed,
          onDrain: () => gate.future,
        ),
        tag: 'producer',
      );
      final closing = scope.dispose();
      final observed = expectLater(
        closing,
        throwsA(
          isA<LevitDisposalException>().having(
            (error) => error.failures.map((f) => f.error),
            'all failures once',
            unorderedEquals([cancelled, drained, closed]),
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(events.where((e) => e.startsWith('close:')), isEmpty);
      gate.complete();
      await observed;
      await scope.disposed;
      expect(events.where((e) => e.startsWith('close:')), [
        'close:producer',
        'close:dependency',
      ]);
      expect(dependency.events, same(events));
    },
  );

  test('failing child cleanup is flattened and parent still closes', () async {
    final events = <String>[];
    final scope = LevitScope.root();
    final child = scope.createScope('child');
    scope.put(() => Work(events, name: 'parent'));
    final problem = StateError('child');
    child.put(() => Work(events, closeError: problem));
    await expectLater(
      scope.dispose(),
      throwsA(
        isA<LevitDisposalException>().having(
          (e) => e.failures.single.error,
          'child failure',
          same(problem),
        ),
      ),
    );
    expect(events.last, 'close:parent');
    expect(child.isDisposed, isTrue);
  });

  test('a child boundary failure does not skip parent cleanup', () async {
    final events = <String>[];
    final scope = LevitScope.root();
    final child = scope.createScope('child');
    var checks = 0;
    child.put(
      () => Work(
        events,
        boundary: () {
          if (++checks == 2) throw StateError('boundary');
        },
      ),
    );
    scope.put(() => Work(events, name: 'parent'));
    await expectLater(scope.dispose(), throwsA(isA<LevitDisposalException>()));
    expect(events.last, 'close:parent');
    await child.dispose();
  });

  test(
    'registration-tracked initialization drains and reports failure',
    () async {
      final observer = Progress();
      LevitScope.addMiddleware(observer);
      addTearDown(() => LevitScope.removeMiddleware(observer));
      final scope = LevitScope.root();
      final events = <String>[];
      scope.put(() => Work(events));
      final gate = Completer<void>();
      observer.registrations.single.trackInitialization(gate.future);
      expect(
        scope.describe().pendingInitializations,
        0,
      ); // registration owns it
      expect(scope.describe().registrations.single.pendingInitializations, 1);
      final problem = StateError('initialization');
      final closing = expectLater(
        scope.dispose(),
        throwsA(
          isA<LevitDisposalException>().having(
            (e) => e.failures.single.error,
            'failure',
            same(problem),
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(events, ['cancel:work']);
      gate.completeError(problem);
      await closing;
      expect(events.last, 'close:work');
    },
  );

  test(
    'initialization adopted during drain reports failure before release',
    () async {
      final observer = Progress();
      LevitScope.addMiddleware(observer);
      addTearDown(() => LevitScope.removeMiddleware(observer));
      final scope = LevitScope.root();
      final events = <String>[];
      final gate = Completer<void>();
      final adopted = Completer<void>();
      scope.put(
        () => Work(
          events,
          onDrain: () async {
            observer.registrations.single.trackInitialization(gate.future);
            adopted.complete();
          },
        ),
      );
      final problem = StateError('late adopted initialization');
      final closing = expectLater(
        scope.dispose(),
        throwsA(
          isA<LevitDisposalException>().having(
            (e) => e.failures.single.error,
            'late failure',
            same(problem),
          ),
        ),
      );
      await adopted.future;
      await Future<void>.delayed(Duration.zero);
      expect(events, isNot(contains('close:work')));
      gate.completeError(problem);
      await closing;
      expect(events.last, 'close:work');
    },
  );

  test(
    'descriptions preserve aliases and ancestry without exposing values',
    () async {
      final observer = Progress()..fail = true;
      LevitScope.addMiddleware(observer);
      addTearDown(() => LevitScope.removeMiddleware(observer));
      final scope = LevitScope.root('root');
      final child = scope.createScope('feature');
      scope.put<String>(() => 'secret', tag: 'private-tag');
      scope.bindExisting<Object, String>(sourceTag: 'private-tag');
      final snapshot = scope.describe();
      expect(snapshot.registrations.first.ownsInstance, isTrue);
      expect(snapshot.registrations.last.ownsInstance, isFalse);
      expect(
        snapshot.registrations.last.aliasOf,
        snapshot.registrations.first.key,
      );
      final json = snapshot.toJson();
      expect(json['parentScopeId'], isNull);
      expect(json['ownedChildren'], [containsPair('name', 'feature')]);
      expect(child.describe().toJson()['ancestry'], [
        containsPair('name', 'root'),
      ]);
      expect(jsonEncode(json), isNot(contains('secret')));
      expect(jsonEncode(json), isNot(contains('private-tag')));
      await scope.dispose();
      expect(observer.descriptions.last.isDisposed, isTrue);
      expect(snapshot.isDisposed, isFalse);
    },
  );

  test(
    'child releases parent-owned factories and invalidates async lookup cache',
    () async {
      final parent = LevitScope.root();
      final child = parent.createScope('child');
      final events = <String>[];
      parent.lazyPut(() => Work(events), isFactory: true);
      final value = child.find<Work>();
      expect(await child.releaseFactoryInstance(value), isTrue);
      expect(events.last, 'close:work');
      parent.put<String>(() => 'value', tag: 'async');
      expect(await child.findAsync<String>(tag: 'async'), 'value');
      await parent.delete<String>(tag: 'async');
      await expectLater(child.findAsync<String>(tag: 'async'), throwsException);
      await parent.dispose();
    },
  );

  test('nested disposal failures deduplicate by both resource and error', () {
    final first = Object();
    final second = Object();
    final error = StateError('failure');
    LevitDisposalFailure failure(Object resource) => LevitDisposalFailure(
      resource: resource,
      error: error,
      stackTrace: StackTrace.current,
    );
    final aggregate = LevitDisposalException.aggregate([
      failure(first),
      LevitDisposalFailure(
        resource: first,
        error: LevitDisposalException([failure(first), failure(second)]),
        stackTrace: StackTrace.current,
      ),
    ]);
    expect(aggregate.failures.map((f) => f.resource), [first, second]);
  });
}
