import 'dart:async';
import 'package:levit_scope/levit_scope.dart';
import 'package:test/test.dart';

class _Resource extends LevitScopeDisposable {
  _Resource(this.name, this.events, {this.release});
  final String name;
  final List<String> events;
  final Future<void>? release;

  @override
  Future<void> onClose() async {
    events.add('closing $name');
    await release;
    events.add('closed $name');
  }
}

void main() {
  test('singleton creation and cleanup both belong to disposal', () async {
    final scope = LevitScope.root();
    final events = <String>[];
    final create = Completer<_Resource>();
    final release = Completer<void>();
    scope.put(() => _Resource('dependency', events), tag: 'dependency');
    scope.lazyPutAsync(() => create.future);
    final resolving = scope.findAsync<_Resource>();
    final rejected = expectLater(resolving, throwsStateError);
    var disposed = false;
    final cleanup = scope.dispose().then((_) => disposed = true);
    await Future<void>.value();
    expect(events, isEmpty);
    expect(disposed, isFalse);
    create.complete(_Resource('late', events, release: release.future));
    await rejected;
    await Future<void>.delayed(Duration.zero);
    expect(disposed, isFalse);
    release.complete();
    await cleanup;
    expect(events, [
      'closing late',
      'closed late',
      'closing dependency',
      'closed dependency',
    ]);
  });

  test(
    'owned children close before parent dependencies; borrowed children survive',
    () async {
      final events = <String>[];
      final parent = LevitScope.root();
      parent.put(() => _Resource('parent', events));
      final child = parent.createScope('owned');
      child.put(() => _Resource('child', events));
      final borrowed = parent.createScope('borrowed', ownedByParent: false);
      await parent.dispose();
      expect(child.isDisposed, isTrue);
      expect(borrowed.isDisposed, isFalse);
      expect(events, [
        'closing child',
        'closed child',
        'closing parent',
        'closed parent',
      ]);
      await borrowed.dispose();
    },
  );

  test(
    'disposed waits while active and through asynchronous cleanup',
    () async {
      final scope = LevitScope.root();
      final release = Completer<void>();
      scope.put(() => _Resource('one', [], release: release.future));
      var done = false;
      final observed = scope.disposed.then((_) => done = true);
      await Future<void>.value();
      expect(done, isFalse);
      final closing = scope.dispose();
      expect(scope.dispose(), same(closing));
      await Future<void>.value();
      expect(done, isFalse);
      release.complete();
      await closing;
      await observed;
      expect(done, isTrue);
    },
  );

  test(
    'factory permanence is explicit and early release happens once',
    () async {
      final scope = LevitScope.root();
      final events = <String>[];
      var index = 0;
      scope.lazyPut(() => _Resource('${++index}', events), isFactory: true);
      final first = scope.find<_Resource>();
      scope.find<_Resource>();
      expect(await scope.releaseFactoryInstance(first), isTrue);
      expect(await scope.releaseFactoryInstance(first), isFalse);
      await scope.reset();
      expect(events, ['closing 1', 'closed 1', 'closing 2', 'closed 2']);
      expect(scope.isRegistered<_Resource>(), isFalse);
      await scope.dispose();
    },
  );

  test(
    'external initialization awaiting a late singleton cannot deadlock disposal',
    () async {
      final scope = LevitScope.root();
      final create = Completer<_Resource>();
      final events = <String>[];
      scope.lazyPutAsync(() => create.future);
      final setup = scope.trackInitialization(scope.findAsync<_Resource>());
      final rejected = expectLater(setup, throwsStateError);
      final closing = scope.dispose();
      create.complete(_Resource('late', events));
      await rejected;
      await closing;
      expect(events, ['closing late', 'closed late']);
    },
  );
}
