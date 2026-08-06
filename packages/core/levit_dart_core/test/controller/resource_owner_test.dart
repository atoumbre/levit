import 'dart:async';

import 'package:levit_dart_core/levit_dart_core.dart';
import 'package:test/test.dart';

final class _Owner extends LevitScopeDisposable with LevitResourceOwnership {
  Iterable<Object> get resources => ownedResources;
}

final class _AsyncResource implements LevitDisposable {
  _AsyncResource(this.label, this.events, {this.fail = false});

  final String label;
  final List<String> events;
  final bool fail;

  @override
  Future<void> dispose() async {
    await Future<void>.delayed(Duration.zero);
    events.add(label);
    if (fail) throw StateError(label);
  }
}

final class _DynamicAsyncResource {
  bool disposed = false;

  Future<void> dispose() async {
    await Future<void>.delayed(Duration.zero);
    disposed = true;
  }
}

void main() {
  setUp(Levit.enableAutoLinking);
  tearDown(() async {
    Levit.disableAutoLinking();
    await Levit.reset(force: true);
  });

  test('any returned resource owner adopts captured reactives', () async {
    late LxVar<int> value;
    final owner = Levit.put<_Owner>(() {
      value = 0.lx;
      return _Owner();
    });

    expect(value.ownerId, isNotNull);
    expect(value.isDisposed, isFalse);

    await Levit.delete<_Owner>();

    expect(owner.isDisposed, isTrue);
    expect(value.isDisposed, isTrue);
    await owner.disposed;
  });

  test('own is identity-based, LIFO, awaited, and terminal', () async {
    final events = <String>[];
    final owner = _Owner();
    final first = _AsyncResource('first', events);
    final second = _AsyncResource('second', events);

    expect(identical(owner.own(first), first), isTrue);
    owner.autoDispose(first);
    owner.own(second);

    await owner.onClose();
    await owner.disposed;

    expect(events, <String>['second', 'first']);
    expect(owner.isDisposed, isTrue);
    expect(() => owner.own(_AsyncResource('late', events)), throwsStateError);
  });

  test('default diagnostics and dynamic async cleanup are exposed', () async {
    final owner = _Owner();
    final reactive = owner.own(0.lx);
    final resource = owner.own(_DynamicAsyncResource());

    expect(reactive.ownerId, '?');
    expect(owner.resources, containsAll(<Object>[reactive, resource]));

    await owner.onClose();

    expect(resource.disposed, isTrue);
    expect(reactive.isDisposed, isTrue);
  });

  test('owner cleanup aggregates failures after attempting every resource',
      () async {
    final events = <String>[];
    final owner = _Owner();
    owner.own(_AsyncResource('first', events, fail: true));
    owner.own(_AsyncResource('second', events, fail: true));

    await expectLater(
      owner.onClose(),
      throwsA(
        isA<LevitDisposalException>().having(
          (error) => error.failures.length,
          'failure count',
          2,
        ),
      ),
    );

    expect(events, <String>['second', 'first']);
    expect(owner.isDisposed, isTrue);
    await owner.disposed;
  });
}
