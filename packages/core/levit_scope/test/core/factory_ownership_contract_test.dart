import 'dart:async';
import 'package:levit_scope/levit_scope.dart';
import 'package:test/test.dart';

class Resource extends LevitScopeDisposable {
  Resource(this.id, this.closed, {this.fail = false});
  final int id;
  final List<int> closed;
  final bool fail;
  @override
  void onClose() {
    closed.add(id);
    if (fail) throw StateError('close $id');
  }
}

void main() {
  test('registering scope owns factory results in reverse order', () async {
    final closed = <int>[];
    var next = 0;
    final parent = LevitScope.root('parent');
    final child = parent.createScope('child');
    parent.lazyPut(
      () => Resource(++next, closed),
      isFactory: true,
      permanent: true,
    );
    child.find<Resource>();
    await child.findAsync<Resource>();
    await child.dispose();
    expect(closed, isEmpty);
    await parent.reset(); // Explicit permanence survives a non-forced reset.
    expect(closed, isEmpty);
    expect(
      () => parent.lazyPut(() => Resource(3, closed), isFactory: true),
      throwsStateError,
    );
    expect(() => parent.lazyPut(() => Resource(3, closed)), throwsStateError);
    expect(() => parent.put(() => Resource(3, closed)), throwsStateError);
    expect(
      () => parent.lazyPutAsync(() async => Resource(3, closed)),
      throwsStateError,
    );
    await parent.delete<Resource>(force: true);
    expect(closed, [2, 1]);
    await parent.dispose();
    expect(closed, [2, 1]);
  });

  for (final operation in ['delete', 'reset', 'dispose']) {
    test(
      '$operation waits for pending async creation and rejects its result',
      () async {
        final closed = <int>[];
        final scope = LevitScope.root();
        final create = Completer<Resource>();
        scope.lazyPutAsync(() => create.future, isFactory: true);
        final result = scope.findAsync<Resource>();
        final rejected = expectLater(result, throwsStateError);
        var finished = false;
        final Future<dynamic> cleanup = switch (operation) {
          'delete' => scope.delete<Resource>(force: true),
          'reset' => scope.reset(force: true),
          _ => scope.dispose(),
        };
        final completion = cleanup.then((_) => finished = true);
        await Future<void>.value();
        expect(finished, isFalse);
        expect(() => scope.put(() => Resource(2, closed)), throwsStateError);
        create.complete(Resource(1, closed));
        await rejected;
        await completion;
        expect(closed, [1]);
        await scope.dispose();
      },
    );
  }

  test(
    'concurrent late results close once in reverse completion order',
    () async {
      final scope = LevitScope.root();
      final closed = <int>[];
      final creates = List.generate(3, (_) => Completer<Resource>());
      var index = 0;
      scope.lazyPutAsync(() => creates[index++].future, isFactory: true);
      final first = scope.findAsync<Resource>();
      final duplicate = Resource(1, closed);
      creates[0].complete(duplicate);
      await first;
      final second = scope.findAsync<Resource>();
      final third = scope.findAsync<Resource>();
      final rejected = [
        expectLater(second, throwsStateError),
        expectLater(third, throwsStateError),
      ];
      final disposal = scope.dispose();
      creates[1].complete(duplicate);
      await Future<void>.value();
      expect(closed, isEmpty);
      creates[2].complete(Resource(2, closed));
      await disposal;
      await Future.wait(rejected);
      expect(closed, [2, 1]);
    },
  );

  test('async factory replacement requires awaited deletion', () async {
    final scope = LevitScope.root();
    final closed = <int>[];
    scope.put(() => Resource(0, closed));
    expect(
      () =>
          scope.lazyPutAsync(() async => Resource(1, closed), isFactory: true),
      throwsStateError,
    );
    await scope.delete<Resource>();
    final creation = Completer<Resource>();
    scope.lazyPutAsync(() => creation.future, isFactory: true);
    final result = scope.findAsync<Resource>();
    final rejected = expectLater(result, throwsStateError);
    final deleting = scope.delete<Resource>(force: true);
    expect(
      () => scope.lazyPutAsync(() async => Resource(2, closed)),
      throwsStateError,
    );
    creation.complete(Resource(1, closed));
    await deleting;
    await rejected;
    scope.lazyPutAsync(() async => Resource(2, closed), isFactory: true);
    await scope.findAsync<Resource>();
    await scope.dispose();
    expect(closed, [0, 1, 2]);
  });

  test('failed pending creation does not strand removal', () async {
    final scope = LevitScope.root();
    final create = Completer<Resource>();
    scope.lazyPutAsync(() => create.future, isFactory: true);
    final failed = expectLater(
      scope.findAsync<Resource>(),
      throwsArgumentError,
    );
    final disposal = scope.dispose();
    create.completeError(ArgumentError('creation'));
    await failed;
    await disposal;
  });

  test(
    'cleanup failures aggregate and registration ordering remains LIFO',
    () async {
      final closed = <int>[];
      final scope = LevitScope.root();
      scope.put(() => Resource(0, closed), tag: 'singleton');
      var id = 0;
      scope.lazyPut(() => Resource(++id, closed, fail: true), isFactory: true);
      scope.find<Resource>();
      scope.find<Resource>();
      await expectLater(
        scope.dispose(),
        throwsA(
          isA<LevitDisposalException>().having(
            (e) => e.failures.length,
            'failures',
            2,
          ),
        ),
      );
      expect(closed, [2, 1, 0]);
    },
  );

  test(
    'pending failures and concurrent teardown do not lose cleanup failures',
    () async {
      final scope = LevitScope.root();
      final closed = <int>[];
      final create = Completer<Resource>();
      scope.lazyPutAsync(() => create.future, isFactory: true);
      final rejected = expectLater(
        scope.findAsync<Resource>(),
        throwsStateError,
      );
      final deleted = expectLater(
        scope.delete<Resource>(force: true),
        throwsA(isA<LevitDisposalException>()),
      );
      final disposed = expectLater(
        scope.dispose(),
        throwsA(isA<LevitDisposalException>()),
      );
      create.complete(Resource(1, closed, fail: true));
      await Future.wait([rejected, deleted, disposed]);
      expect(closed, [1]);
    },
  );
}
