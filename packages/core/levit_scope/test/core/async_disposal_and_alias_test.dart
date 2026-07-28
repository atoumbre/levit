import 'dart:async';

import 'package:levit_scope/levit_scope.dart';
import 'package:test/test.dart';

abstract interface class _Port {
  String get value;
}

final class _Service implements _Port, LevitDisposable {
  _Service(this.value, {this.onDispose});

  @override
  final String value;
  final FutureOr<void> Function()? onDispose;
  int disposeCount = 0;

  @override
  FutureOr<void> dispose() {
    disposeCount++;
    return onDispose?.call();
  }
}

final class _FailingLifecycle extends LevitScopeDisposable {
  _FailingLifecycle(this.label, this.closed);

  final String label;
  final List<String> closed;

  @override
  Future<void> onClose() async {
    closed.add(label);
    throw StateError(label);
  }
}

void main() {
  group('awaited scope disposal', () {
    test('disposal diagnostics preserve singular and plural failures', () {
      final failure = LevitDisposalFailure(
        resource: _Service('failed'),
        error: StateError('close'),
        stackTrace: StackTrace.current,
      );

      expect(failure.toString(), contains('_Service'));
      expect(
        LevitDisposalException([failure]).toString(),
        'LevitDisposalException(1 cleanup failure)',
      );
      expect(
        LevitDisposalException([failure, failure]).toString(),
        'LevitDisposalException(2 cleanup failures)',
      );
    });

    test('awaits direct LevitDisposable and is idempotent', () async {
      final scope = LevitScope.root('async_disposal');
      final gate = Completer<void>();
      final service = _Service('ready', onDispose: () => gate.future);
      scope.put(() => service);

      final first = scope.dispose();
      final second = scope.dispose();

      expect(identical(first, second), isTrue);
      expect(scope.isClosing, isTrue);
      expect(scope.isDisposed, isFalse);
      expect(service.disposeCount, 1);

      gate.complete();
      await first;
      await scope.disposed;

      expect(scope.isDisposed, isTrue);
      expect(service.disposeCount, 1);
      expect(() => scope.find<_Service>(), throwsStateError);
    });

    test('disposes in reverse order and aggregates every failure', () async {
      final scope = LevitScope.root('aggregate_disposal');
      final closed = <String>[];
      scope.put(() => _FailingLifecycle('first', closed), tag: 'first');
      scope.put(() => _FailingLifecycle('second', closed), tag: 'second');

      await expectLater(
        scope.dispose(),
        throwsA(
          isA<LevitDisposalException>().having(
            (error) => error.failures.length,
            'failure count',
            2,
          ),
        ),
      );

      expect(closed, <String>['second', 'first']);
      expect(scope.isDisposed, isTrue);
    });
  });

  group('bindExisting', () {
    test('resolves one owned instance through multiple ports', () async {
      final scope = LevitScope.root('aliases');
      final service = _Service('same');
      scope.put<_Service>(() => service);
      scope.bindExisting<_Port, _Service>();

      expect(identical(scope.find<_Port>(), scope.find<_Service>()), isTrue);
      expect(scope.registeredCount, 2);

      expect(await scope.delete<_Port>(), isTrue);
      expect(service.disposeCount, 0);
      expect(scope.isRegistered<_Service>(), isTrue);

      scope.bindExisting<_Port, _Service>();
      expect(await scope.delete<_Service>(), isTrue);
      expect(service.disposeCount, 1);
      expect(scope.isRegistered<_Port>(), isFalse);
    });

    test('supports lazy async singleton aliases', () async {
      final scope = LevitScope.root('async_alias');
      var builds = 0;
      scope.lazyPutAsync<_Service>(() async {
        builds++;
        return _Service('async');
      });
      scope.bindExisting<_Port, _Service>();

      expect(
        () => scope.find<_Port>(),
        throwsA(isA<StateError>()),
      );
      final port = await scope.findAsync<_Port>();
      final service = await scope.findAsync<_Service>();

      expect(identical(port, service), isTrue);
      expect(builds, 1);
      await scope.dispose();
      expect(service.disposeCount, 1);
    });

    test('tagged aliases support every resolution path', () async {
      final scope = LevitScope.root('tagged_aliases');
      final service = _Service('tagged');
      scope.put<_Service>(() => service, tag: 'source');
      scope.bindExisting<_Port, _Service>(
        sourceTag: 'source',
        tag: 'port',
      );

      expect(scope.find<_Port>(tag: 'port'), same(service));
      expect(scope.findOrNull<_Port>(tag: 'port'), same(service));
      expect(await scope.findAsync<_Port>(tag: 'port'), same(service));
      expect(await scope.findOrNullAsync<_Port>(tag: 'port'), same(service));
      expect(scope.isInstantiated<_Port>(tag: 'port'), isTrue);

      await scope.dispose();
    });

    test('global accessor binds within the active scope', () async {
      final scope = LevitScope.root('global_alias');
      final service = _Service('global');

      scope.run(() {
        Ls.put<_Service>(() => service);
        Ls.bindExisting<_Port, _Service>();
        expect(Ls.find<_Port>(), same(service));
      });

      await scope.dispose();
    });

    test('rejects factory and missing-source aliases', () {
      final scope = LevitScope.root('invalid_aliases');
      expect(
        () => scope.bindExisting<_Port, _Service>(),
        throwsStateError,
      );

      scope.lazyPut<_Service>(() => _Service('factory'), isFactory: true);
      expect(
        () => scope.bindExisting<_Port, _Service>(),
        throwsStateError,
      );
    });

    test('rejects key collisions and alias registration replacement', () async {
      final scope = LevitScope.root('alias_collisions');
      scope.put<_Service>(() => _Service('source'));
      scope.bindExisting<_Port, _Service>();

      expect(
        () => scope.bindExisting<_Port, _Service>(),
        throwsStateError,
      );
      expect(
        () => scope.lazyPut<_Port>(() => _Service('lazy')),
        throwsStateError,
      );
      expect(
        () => scope.lazyPutAsync<_Port>(() async => _Service('async')),
        throwsStateError,
      );
      expect(
        () => scope.bindExisting<_Service, _Service>(),
        throwsArgumentError,
      );
      expect(
        () => scope.put<_Service>(() => _Service('replacement')),
        throwsStateError,
      );
      scope.put<_Service>(() => _Service('tagged'), tag: 'tagged');
      expect(
        () => scope.put<_Service>(
          () => _Service('tagged replacement'),
          tag: 'tagged',
        ),
        throwsStateError,
      );
      await scope.dispose();
    });
  });
}
